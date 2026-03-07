import Combine
import Foundation
import SwiftData

@MainActor
final class AppBootstrapCoordinator: ObservableObject {
    private static let primaryStoreName = "TeacherAssistant-V5-WithGroups"
    private static let recoveryStorePrefix = "TeacherAssistant-V7-RecoveryStore"
    private static let testModeEnvironmentKey = "TA_TEST_MODE"
    private static let activeStoreNameDefaultsKey = "bootstrap.activeStoreName"

    @Published private(set) var activeContainer: ModelContainer?
    @Published private(set) var startupFailureDescription: String?
    @Published private(set) var latestLocalSnapshotURL: URL?
    @Published private(set) var isRecoveryActionInProgress = false
    @Published var recoveryMessage: String?

    init() {
        if activateTestContainerIfNeeded() {
            return
        }
        openInitialStore()
    }

    func retryOpeningPrimaryStore() {
        do {
            let container = try createContainer(storeName: Self.primaryStoreName)
            activateContainer(container, storeName: Self.primaryStoreName)
            SnapshotManager.shared.captureUpgradeSnapshotIfNeeded(context: container.mainContext)
            SecureLogger.info("Opened primary model container")
        } catch {
            let appError = AppError.recovery(
                action: .openPrimaryStore,
                underlyingError: error
            )
            presentRecoveryMode(
                BootstrapRecoveryState.from(
                    startupError: appError,
                    latestLocalSnapshotURL: BackupManager.latestLocalSnapshotURL()
                )
            )
            SecureLogger.error("Failed to open primary model container", error: appError)
        }
    }

    func restoreFromLatestLocalSnapshot() {
        guard let latestLocalSnapshotURL else {
            recoveryMessage = "No local snapshot was found."
            return
        }

        performRecoveryAction(action: .restoreFromSnapshot) {
            try activateRecoveryContainer(from: latestLocalSnapshotURL)
        }
    }

    func importBackup(from url: URL) {
        performRecoveryAction(action: .importBackup) {
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
        performRecoveryAction(action: .createFreshStore) {
            let storeName = recoveryStoreName()
            let container = try createContainer(storeName: storeName)
            activateContainer(container, storeName: storeName)
            SecureLogger.warning("Opened a fresh recovery store by user request")
        }
    }

    private func performRecoveryAction(
        action recoveryAction: AppError.RecoveryAction,
        _ action: () throws -> Void
    ) {
        guard !isRecoveryActionInProgress else { return }

        isRecoveryActionInProgress = true
        defer { isRecoveryActionInProgress = false }

        do {
            try action()
        } catch {
            let appError = AppError.recovery(
                action: recoveryAction,
                underlyingError: error
            )
            recoveryMessage = appError.messageForAlert
            SecureLogger.error("Recovery action failed [\(appError.code)]", error: error)
        }
    }

    private func activateRecoveryContainer(from backupURL: URL) throws {
        let storeName = recoveryStoreName()
        let container = try createContainer(storeName: storeName)
        try BackupManager.importBackup(from: backupURL, context: container.mainContext)
        activateContainer(container, storeName: storeName)
        SecureLogger.info("Recovery store activated from backup")
    }

    private func activateContainer(_ container: ModelContainer, storeName: String, persistStoreName: Bool = true) {
        activeContainer = container
        if persistStoreName {
            UserDefaults.standard.set(storeName, forKey: Self.activeStoreNameDefaultsKey)
        }
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

    private func openInitialStore() {
        let resolution: BootstrapStoreStartupResolution<ModelContainer> =
            BootstrapStoreStartupService.resolve(
                candidateStoreNames: startupStoreCandidates(),
                openStore: { storeName in
                    try createContainer(storeName: storeName)
                },
                latestLocalSnapshotURL: {
                    BackupManager.latestLocalSnapshotURL()
                },
                didOpenStore: { container in
                    SnapshotManager.shared.captureUpgradeSnapshotIfNeeded(context: container.mainContext)
                }
            )

        switch resolution {
        case .opened(let openedStore):
            activateContainer(openedStore.store, storeName: openedStore.storeName)
        case .recovery(let state):
            presentRecoveryMode(state)
        }
    }

    private func startupStoreCandidates() -> [String] {
        var candidates: [String] = []
        let defaults = UserDefaults.standard

        if let persistedStoreName = defaults.string(forKey: Self.activeStoreNameDefaultsKey),
           !persistedStoreName.isEmpty {
            candidates.append(persistedStoreName)
        }

        if !candidates.contains(Self.primaryStoreName) {
            candidates.append(Self.primaryStoreName)
        }

        return candidates
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
            activateContainer(container, storeName: "TeacherAssistant-TestHost", persistStoreName: false)
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
