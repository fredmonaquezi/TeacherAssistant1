import Foundation

#if BACKUP_VERIFY

@main
struct BootstrapRecoveryVerifier {
    static func main() {
        do {
            let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/latest-local-snapshot.backup")
            let startupError = NSError(
                domain: "BootstrapRecoveryVerifier",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Primary store is corrupted"]
            )

            let recoveryState = BootstrapRecoveryState.from(
                startupError: startupError,
                latestLocalSnapshotURL: expectedSnapshotURL
            )

            try require(
                recoveryState.startupFailureDescription == "Primary store is corrupted",
                "Recovery state did not preserve the startup error"
            )
            try require(
                recoveryState.latestLocalSnapshotURL == expectedSnapshotURL,
                "Recovery state did not preserve the latest snapshot"
            )

            let noSnapshotState = BootstrapRecoveryState.from(
                startupError: startupError,
                latestLocalSnapshotURL: nil
            )
            try require(
                noSnapshotState.latestLocalSnapshotURL == nil,
                "Recovery state should allow a missing local snapshot"
            )

            print("RESULT: PASS")
            print("  - Startup failures map to explicit recovery state")
            print("  - Recovery state preserves the latest local snapshot when available")
        } catch {
            print("RESULT: FAIL")
            print("  - \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(
                domain: "BootstrapRecoveryVerifier",
                code: 99,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

#endif
