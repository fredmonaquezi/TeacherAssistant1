import Foundation

struct SaveResult {
    let didSave: Bool
    let errorDescription: String?
    let reason: String

    static func success(reason: String) -> SaveResult {
        SaveResult(didSave: true, errorDescription: nil, reason: reason)
    }

    static func failure(reason: String, errorDescription: String?) -> SaveResult {
        SaveResult(didSave: false, errorDescription: errorDescription, reason: reason)
    }
}
