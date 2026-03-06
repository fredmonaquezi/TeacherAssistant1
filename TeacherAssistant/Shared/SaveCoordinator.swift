import Foundation
import SwiftData

extension Notification.Name {
    static let persistenceSaveFailed = Notification.Name("PersistenceSaveFailed")
}

enum SaveFailureNotificationKeys {
    static let message = "message"
    static let errorDescription = "errorDescription"
    static let reason = "reason"
}

@MainActor
enum SaveCoordinator {
    static let defaultUserMessage = "Your latest changes could not be saved. Please try again."

    static func perform(
        context: ModelContext,
        reason: String,
        userMessage: String = "Your latest changes could not be saved. Please try again.",
        operation: @MainActor () throws -> Void = { }
    ) async -> SaveResult {
        await PersistenceWriteCoordinator.shared.perform(
            context: context,
            reason: reason,
            userMessage: userMessage,
            operation: operation
        )
    }

    static func save(
        context: ModelContext,
        reason: String,
        userMessage: String = "Your latest changes could not be saved. Please try again."
    ) -> Bool {
        saveResult(
            context: context,
            reason: reason,
            userMessage: userMessage
        ).didSave
    }

    static func saveResult(
        context: ModelContext,
        reason: String,
        userMessage: String = "Your latest changes could not be saved. Please try again."
    ) -> SaveResult {
        guard context.hasChanges else { return SaveResult.success(reason: reason) }

        do {
            try context.save()
            SnapshotManager.shared.scheduleDebouncedSnapshot(
                context: context,
                reason: reason
            )
            Task {
                await PerformanceMonitor.shared.incrementCounter(.saveOperation)
            }
            return SaveResult.success(reason: reason)
        } catch {
            return reportFailure(
                reason: reason,
                userMessage: userMessage,
                error: error
            )
        }
    }

    static func reportFailure(
        reason: String,
        userMessage: String,
        error: Error
    ) -> SaveResult {
        SecureLogger.operationFailed("Save (\(reason))", error: error)

        NotificationCenter.default.post(
            name: .persistenceSaveFailed,
            object: nil,
            userInfo: [
                SaveFailureNotificationKeys.message: userMessage,
                SaveFailureNotificationKeys.errorDescription: error.localizedDescription,
                SaveFailureNotificationKeys.reason: reason,
            ]
        )

        return SaveResult.failure(
            reason: reason,
            errorDescription: error.localizedDescription
        )
    }
}
