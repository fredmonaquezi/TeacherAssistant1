import Foundation

enum AppErrorCategory: String, Sendable {
    case persistence
    case backup
    case recovery
}

enum AppErrorSeverity: String, Sendable {
    case userFixable
    case retryable
    case fatal
}

struct AppError: LocalizedError, Sendable {
    enum BackupStage: String, Sendable {
        case export
        case `import`
        case snapshot
    }

    enum RecoveryAction: String, Sendable {
        case openPrimaryStore
        case openInitialStore
        case restoreFromSnapshot
        case importBackup
        case createFreshStore
        case selectBackupFile
    }

    let category: AppErrorCategory
    let code: String
    let severity: AppErrorSeverity
    let userMessage: String
    let technicalDetails: String?

    var errorDescription: String? {
        userMessage
    }

    var messageForAlert: String {
        guard let technicalDetails,
              !technicalDetails.isEmpty,
              technicalDetails != userMessage else {
            return userMessage
        }
        return "\(userMessage)\n\n\(technicalDetails)"
    }

    static func persistenceSave(
        reason: String,
        userMessage: String,
        underlyingError: Error
    ) -> AppError {
        AppError(
            category: .persistence,
            code: "persistence.save_failed",
            severity: .retryable,
            userMessage: userMessage,
            technicalDetails: "Reason: \(reason)\n\(underlyingError.localizedDescription)"
        )
    }

    static func backup(
        stage: BackupStage,
        underlyingError: Error
    ) -> AppError {
        if let appError = underlyingError as? AppError {
            return appError
        }

        if let backupError = underlyingError as? BackupError {
            return mapBackupError(stage: stage, backupError: backupError)
        }

        return AppError(
            category: .backup,
            code: "backup.\(stage.rawValue).unexpected",
            severity: .retryable,
            userMessage: "The backup operation could not be completed.",
            technicalDetails: underlyingError.localizedDescription
        )
    }

    static func recovery(
        action: RecoveryAction,
        underlyingError: Error
    ) -> AppError {
        if let appError = underlyingError as? AppError {
            return appError
        }

        let message: String
        let severity: AppErrorSeverity

        switch action {
        case .openPrimaryStore, .openInitialStore:
            message = "The app could not open your data store."
            severity = .fatal
        case .restoreFromSnapshot:
            message = "The app could not restore from the latest local snapshot."
            severity = .retryable
        case .importBackup:
            message = "The app could not restore from the selected backup."
            severity = .retryable
        case .createFreshStore:
            message = "The app could not create a fresh recovery store."
            severity = .retryable
        case .selectBackupFile:
            message = "The selected backup file could not be opened."
            severity = .userFixable
        }

        return AppError(
            category: .recovery,
            code: "recovery.\(action.rawValue)",
            severity: severity,
            userMessage: message,
            technicalDetails: underlyingError.localizedDescription
        )
    }

    private static func mapBackupError(
        stage: BackupStage,
        backupError: BackupError
    ) -> AppError {
        let codeSuffix: String
        let severity: AppErrorSeverity

        switch backupError {
        case .fileNotFound:
            codeSuffix = "file_not_found"
            severity = .userFixable
        case .fileTooLarge:
            codeSuffix = "file_too_large"
            severity = .userFixable
        case .invalidData:
            codeSuffix = "invalid_data"
            severity = .userFixable
        case .incompatibleVersion:
            codeSuffix = "incompatible_version"
            severity = .userFixable
        case .operationInProgress:
            codeSuffix = "operation_in_progress"
            severity = .retryable
        case .rateLimited:
            codeSuffix = "rate_limited"
            severity = .retryable
        case .saveFailed:
            codeSuffix = "save_failed"
            severity = .retryable
        }

        return AppError(
            category: .backup,
            code: "backup.\(stage.rawValue).\(codeSuffix)",
            severity: severity,
            userMessage: backupError.errorDescription ?? "The backup operation failed.",
            technicalDetails: backupError.localizedDescription
        )
    }
}
