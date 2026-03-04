import Foundation

struct BootstrapRecoveryState {
    let startupFailureDescription: String
    let latestLocalSnapshotURL: URL?

    static func from(startupError: Error, latestLocalSnapshotURL: URL?) -> BootstrapRecoveryState {
        BootstrapRecoveryState(
            startupFailureDescription: startupError.localizedDescription,
            latestLocalSnapshotURL: latestLocalSnapshotURL
        )
    }
}
