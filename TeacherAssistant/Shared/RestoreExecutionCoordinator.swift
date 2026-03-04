import Foundation

struct RestoreExecutionResult<Payload> {
    let payload: Payload
    let preRestoreSnapshotURL: URL
}

enum RestoreExecutionError: Error {
    case applyFailed(preRestoreSnapshotURL: URL, underlyingError: Error)
}

enum RestoreExecutionCoordinator {
    static func prepareAndApply<Payload>(
        loadPayload: () throws -> Payload,
        validatePayload: (Payload) throws -> Void,
        createSafetySnapshot: () throws -> URL,
        applyPayload: (Payload) throws -> Void
    ) throws -> RestoreExecutionResult<Payload> {
        let payload = try loadPayload()
        try validatePayload(payload)
        let preRestoreSnapshotURL = try createSafetySnapshot()
        do {
            try applyPayload(payload)
        } catch {
            throw RestoreExecutionError.applyFailed(
                preRestoreSnapshotURL: preRestoreSnapshotURL,
                underlyingError: error
            )
        }
        return RestoreExecutionResult(
            payload: payload,
            preRestoreSnapshotURL: preRestoreSnapshotURL
        )
    }
}
