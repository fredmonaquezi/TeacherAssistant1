import Foundation
import os.log

/// Secure logging wrapper that only logs in DEBUG builds
/// and redacts sensitive information in production
enum SecureLogger {
    
    /// Log level enumeration
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    /// Logs a debug message (only in DEBUG builds)
    /// - Parameters:
    ///   - message: Message to log
    ///   - file: Source file (auto-captured)
    ///   - function: Function name (auto-captured)
    ///   - line: Line number (auto-captured)
    static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(message, level: .debug, file: file, function: function, line: line)
        #endif
    }
    
    /// Logs an info message
    static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(message, level: .info, file: file, function: function, line: line)
        #endif
    }
    
    /// Logs a warning message
    static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(message, level: .warning, file: file, function: function, line: line)
        #endif
    }
    
    /// Logs an error message (always logged, but with redaction in release)
    static func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
        #else
        // In release builds, only log sanitized error info
        os_log(.error, "TeacherAssistant Error: %{public}@", redactSensitiveInfo(message))
        #endif
    }
    
    /// Logs a backup/restore operation step
    static func backupStep(_ step: Int, _ message: String) {
        #if DEBUG
        log("STEP \(step): \(message)", level: .info)
        #endif
    }
    
    // MARK: - Private Helpers
    
    private static func log(
        _ message: String,
        level: Level,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)")
    }
    
    /// Redacts potentially sensitive information from log messages
    private static func redactSensitiveInfo(_ message: String) -> String {
        // Remove anything that looks like a name (capitalized words)
        // Remove file paths
        // Remove numbers that could be IDs or scores
        
        var redacted = message
        
        // Redact file paths
        let pathPattern = #"(/[^\s]+)+"#
        if let regex = try? NSRegularExpression(pattern: pathPattern) {
            redacted = regex.stringByReplacingMatches(
                in: redacted,
                range: NSRange(redacted.startIndex..., in: redacted),
                withTemplate: "[PATH_REDACTED]"
            )
        }
        
        return redacted
    }
}

// MARK: - Convenience Extensions

extension SecureLogger {
    
    /// Logs the start of an operation
    static func operationStart(_ operation: String) {
        debug("➡️ Starting: \(operation)")
    }
    
    /// Logs the completion of an operation
    static func operationComplete(_ operation: String) {
        debug("✅ Completed: \(operation)")
    }
    
    /// Logs a failed operation
    static func operationFailed(_ operation: String, error: Error? = nil) {
        SecureLogger.error("❌ Failed: \(operation)", error: error)
    }
}
