import Foundation
import SwiftData

extension Notification.Name {
    static let persistenceSaveFailed = Notification.Name("PersistenceSaveFailed")
    static let persistenceDidSave = Notification.Name("PersistenceDidSave")
}

enum SaveFailureNotificationKeys {
    static let message = "message"
    static let errorDescription = "errorDescription"
    static let reason = "reason"
    static let appErrorCategory = "appErrorCategory"
    static let appErrorCode = "appErrorCode"
    static let appErrorSeverity = "appErrorSeverity"
    static let appErrorTechnicalDetails = "appErrorTechnicalDetails"
}

enum SaveSuccessNotificationKeys {
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
            NotificationCenter.default.post(
                name: .persistenceDidSave,
                object: nil,
                userInfo: [
                    SaveSuccessNotificationKeys.reason: reason
                ]
            )
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
        let appError = AppError.persistenceSave(
            reason: reason,
            userMessage: userMessage,
            underlyingError: error
        )

        SecureLogger.operationFailed(
            "Save (\(reason)) [\(appError.code)]",
            error: error
        )

        NotificationCenter.default.post(
            name: .persistenceSaveFailed,
            object: nil,
            userInfo: [
                SaveFailureNotificationKeys.message: appError.userMessage,
                SaveFailureNotificationKeys.errorDescription: appError.technicalDetails ?? "",
                SaveFailureNotificationKeys.reason: reason,
                SaveFailureNotificationKeys.appErrorCategory: appError.category.rawValue,
                SaveFailureNotificationKeys.appErrorCode: appError.code,
                SaveFailureNotificationKeys.appErrorSeverity: appError.severity.rawValue,
                SaveFailureNotificationKeys.appErrorTechnicalDetails: appError.technicalDetails ?? "",
            ]
        )

        return SaveResult.failure(
            reason: reason,
            errorDescription: appError.technicalDetails
        )
    }
}
