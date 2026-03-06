import Foundation
import SwiftData

actor PersistenceWriteCoordinator {
    static let shared = PersistenceWriteCoordinator()

    @MainActor
    func perform(
        context: ModelContext,
        reason: String,
        userMessage: String = "Your latest changes could not be saved. Please try again.",
        operation: @MainActor () throws -> Void = { }
    ) async -> SaveResult {
        let token = await PerformanceMonitor.shared.beginInterval(.saveOperation, metadata: reason)

        do {
            try operation()
            let result = SaveCoordinator.saveResult(
                context: context,
                reason: reason,
                userMessage: userMessage
            )
            await PerformanceMonitor.shared.endInterval(token, success: result.didSave)
            return result
        } catch {
            let result = SaveCoordinator.reportFailure(
                reason: reason,
                userMessage: userMessage,
                error: error
            )
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return result
        }
    }
}
