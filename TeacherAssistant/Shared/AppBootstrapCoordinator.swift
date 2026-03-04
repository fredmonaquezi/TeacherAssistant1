import Combine
import Foundation
import SwiftData

@MainActor
final class AppBootstrapCoordinator: ObservableObject {
    private static let primaryStoreName = "TeacherAssistant-V5-WithGroups"
    private static let recoveryStorePrefix = "TeacherAssistant-V7-RecoveryStore"
    private static let testModeEnvironmentKey = "TA_TEST_MODE"

    @Published private(set) var activeContainer: ModelContainer?
    @Published private(set) var startupFailureDescription: String?
    @Published private(set) var latestLocalSnapshotURL: URL?
    @Published private(set) var isRecoveryActionInProgress = false
    @Published var recoveryMessage: String?

    init() {
        if activateTestContainerIfNeeded() {
            return
        }
        retryOpeningPrimaryStore()
    }

    func retryOpeningPrimaryStore() {
        do {
            let container = try createContainer(storeName: Self.primaryStoreName)
            activateContainer(container)
            SnapshotManager.shared.captureUpgradeSnapshotIfNeeded(context: container.mainContext)
            SecureLogger.info("Opened primary model container")
        } catch {
            presentRecoveryMode(
                BootstrapRecoveryState.from(
                    startupError: error,
                    latestLocalSnapshotURL: BackupManager.latestLocalSnapshotURL()
                )
            )
            SecureLogger.error("Failed to open primary model container", error: error)
        }
    }

    func restoreFromLatestLocalSnapshot() {
        guard let latestLocalSnapshotURL else {
            recoveryMessage = "No local snapshot was found."
            return
        }

        performRecoveryAction {
            try activateRecoveryContainer(from: latestLocalSnapshotURL)
        }
    }

    func importBackup(from url: URL) {
        performRecoveryAction {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try activateRecoveryContainer(from: url)
        }
    }

    func createFreshStore() {
        performRecoveryAction {
            let container = try createContainer(storeName: recoveryStoreName())
            activateContainer(container)
            SecureLogger.warning("Opened a fresh recovery store by user request")
        }
    }

    private func performRecoveryAction(_ action: () throws -> Void) {
        guard !isRecoveryActionInProgress else { return }

        isRecoveryActionInProgress = true
        defer { isRecoveryActionInProgress = false }

        do {
            try action()
        } catch {
            recoveryMessage = error.localizedDescription
            SecureLogger.error("Recovery action failed", error: error)
        }
    }

    private func activateRecoveryContainer(from backupURL: URL) throws {
        let container = try createContainer(storeName: recoveryStoreName())
        try BackupManager.importBackup(from: backupURL, context: container.mainContext)
        activateContainer(container)
        SecureLogger.info("Recovery store activated from backup")
    }

    private func activateContainer(_ container: ModelContainer) {
        activeContainer = container
        startupFailureDescription = nil
        latestLocalSnapshotURL = nil
        recoveryMessage = nil
    }

    private func presentRecoveryMode(_ state: BootstrapRecoveryState) {
        activeContainer = nil
        startupFailureDescription = state.startupFailureDescription
        latestLocalSnapshotURL = state.latestLocalSnapshotURL
    }

    private func createContainer(storeName: String) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeName,
            schema: PersistenceSchema.schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: PersistenceSchema.schema,
            migrationPlan: PersistenceSchema.MigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func recoveryStoreName() -> String {
        "\(Self.recoveryStorePrefix)-\(UUID().uuidString)"
    }

    private func activateTestContainerIfNeeded() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        let isTestRun =
            environment[Self.testModeEnvironmentKey] == "1" ||
            environment["XCTestConfigurationFilePath"] != nil

        guard isTestRun else {
            return false
        }

        do {
            let configuration = ModelConfiguration(
                "TeacherAssistant-TestHost",
                schema: PersistenceSchema.schema,
                isStoredInMemoryOnly: true
            )
            let container = try ModelContainer(
                for: PersistenceSchema.schema,
                migrationPlan: PersistenceSchema.MigrationPlan.self,
                configurations: [configuration]
            )
            activateContainer(container)
            SecureLogger.info("Opened in-memory model container for tests")
            return true
        } catch {
            presentRecoveryMode(
                BootstrapRecoveryState.from(
                    startupError: error,
                    latestLocalSnapshotURL: nil
                )
            )
            SecureLogger.error("Failed to open in-memory test model container", error: error)
            return true
        }
    }
}
