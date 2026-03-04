import Foundation

#if BACKUP_VERIFY

@main
struct RestoreSafetyVerifier {
    static func main() {
        do {
            try verifyValidationFailureStopsBeforeSnapshot()
            try verifyApplyFailurePreservesLiveState()
            try verifySuccessfulRestoreReturnsSnapshot()

            print("RESULT: PASS")
            print("  - Validation failures stop before snapshot and apply")
            print("  - Apply failures expose the safety snapshot and preserve live state")
            print("  - Successful restore returns payload and snapshot metadata")
        } catch {
            print("RESULT: FAIL")
            print("  - \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func verifyValidationFailureStopsBeforeSnapshot() throws {
        var didCreateSnapshot = false
        var didApply = false

        do {
            _ = try RestoreExecutionCoordinator.prepareAndApply(
                loadPayload: { ["new"] },
                validatePayload: { _ in
                    throw NSError(
                        domain: "RestoreSafetyVerifier",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Validation failed"]
                    )
                },
                createSafetySnapshot: {
                    didCreateSnapshot = true
                    return URL(fileURLWithPath: "/tmp/never-created.backup")
                },
                applyPayload: { _ in
                    didApply = true
                }
            )
            throw failure("Validation failure should have thrown")
        } catch let validationError as NSError {
            try require(validationError.localizedDescription == "Validation failed", "Wrong validation error surfaced")
            try require(!didCreateSnapshot, "Snapshot should not be created before validation succeeds")
            try require(!didApply, "Apply should not run when validation fails")
        } catch {
            throw error
        }
    }

    private static func verifyApplyFailurePreservesLiveState() throws {
        let liveState = ["current"]
        let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/pre-restore.backup")

        do {
            _ = try RestoreExecutionCoordinator.prepareAndApply(
                loadPayload: { ["replacement"] },
                validatePayload: { _ in },
                createSafetySnapshot: { expectedSnapshotURL },
                applyPayload: { payload in
                    var stagedState = liveState
                    stagedState.removeAll()
                    stagedState.append(contentsOf: payload)
                    throw NSError(
                        domain: "RestoreSafetyVerifier",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Apply failed"]
                    )
                }
            )
            throw failure("Apply failure should have thrown")
        } catch let RestoreExecutionError.applyFailed(preRestoreSnapshotURL, underlyingError) {
            try require(
                preRestoreSnapshotURL == expectedSnapshotURL,
                "Apply failure did not retain the pre-restore snapshot location"
            )
            try require(
                underlyingError.localizedDescription == "Apply failed",
                "Underlying apply failure was not preserved"
            )
            try require(liveState == ["current"], "Live state changed before the restore succeeded")
        } catch {
            throw error
        }
    }

    private static func verifySuccessfulRestoreReturnsSnapshot() throws {
        var liveState = ["current"]
        let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/success.backup")
        let result = try RestoreExecutionCoordinator.prepareAndApply(
            loadPayload: { ["replacement"] },
            validatePayload: { payload in
                try require(payload.count == 1, "Unexpected payload count during success path")
            },
            createSafetySnapshot: { expectedSnapshotURL },
            applyPayload: { payload in
                var stagedState = liveState
                stagedState.removeAll()
                stagedState.append(contentsOf: payload)
                liveState = stagedState
            }
        )

        try require(result.preRestoreSnapshotURL == expectedSnapshotURL, "Success path returned wrong snapshot URL")
        try require(result.payload == ["replacement"], "Success path returned wrong payload")
        try require(liveState == ["replacement"], "Live state was not updated on successful restore")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw failure(message)
        }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(
            domain: "RestoreSafetyVerifier",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

#endif
