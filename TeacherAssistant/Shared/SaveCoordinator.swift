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
    static func save(
        context: ModelContext,
        reason: String,
        userMessage: String = "Your latest changes could not be saved. Please try again."
    ) -> Bool {
        guard context.hasChanges else { return true }

        do {
            try context.save()
            SnapshotManager.shared.scheduleDebouncedSnapshot(
                context: context,
                reason: reason
            )
            return true
        } catch {
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

            return false
        }
    }
}
