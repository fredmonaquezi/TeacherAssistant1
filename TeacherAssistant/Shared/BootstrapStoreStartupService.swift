import Foundation

struct BootstrapStartupOpenedStore<StoreHandle> {
    let storeName: String
    let store: StoreHandle
}

enum BootstrapStoreStartupResolution<StoreHandle> {
    case opened(BootstrapStartupOpenedStore<StoreHandle>)
    case recovery(BootstrapRecoveryState)
}

enum BootstrapStoreStartupService {
    static func resolve<StoreHandle>(
        candidateStoreNames: [String],
        openStore: (String) throws -> StoreHandle,
        latestLocalSnapshotURL: () -> URL?,
        didOpenStore: (StoreHandle) -> Void = { _ in }
    ) -> BootstrapStoreStartupResolution<StoreHandle> {
        var startupError: Error?

        for storeName in candidateStoreNames {
            do {
                let store = try openStore(storeName)
                didOpenStore(store)
                SecureLogger.info("Opened model container: \(storeName)")
                return .opened(
                    BootstrapStartupOpenedStore(
                        storeName: storeName,
                        store: store
                    )
                )
            } catch {
                let appError = AppError.recovery(
                    action: .openInitialStore,
                    underlyingError: error
                )
                startupError = appError
                SecureLogger.error("Failed to open model container: \(storeName)", error: error)
            }
        }

        let fallbackError = startupError ?? AppError.recovery(
            action: .openInitialStore,
            underlyingError: NSError(
                domain: "BootstrapStoreStartupService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No startup store candidates were available."]
            )
        )

        return .recovery(
            BootstrapRecoveryState.from(
                startupError: fallbackError,
                latestLocalSnapshotURL: latestLocalSnapshotURL()
            )
        )
    }
}
