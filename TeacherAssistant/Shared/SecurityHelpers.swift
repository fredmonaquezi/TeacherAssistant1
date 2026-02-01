import Foundation

/// Security helper functions for input validation and sanitization
enum SecurityHelpers {
    
    // MARK: - Input Validation
    
    /// Maximum allowed length for names (student, class, subject, etc.)
    static let maxNameLength = 100
    
    /// Maximum allowed length for notes and descriptions
    static let maxNotesLength = 5000
    
    /// Maximum file size for PDF imports (100 MB)
    static let maxPDFFileSize: Int64 = 100 * 1024 * 1024
    
    /// Validates and sanitizes a name input (student, class, subject names)
    /// - Parameter input: Raw input string
    /// - Returns: Sanitized string or nil if invalid
    static func sanitizeName(_ input: String) -> String? {
        // Trim whitespace
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty string
        guard !trimmed.isEmpty else {
            return nil
        }
        
        // Check length
        guard trimmed.count <= maxNameLength else {
            return nil
        }
        
        // Remove control characters and null bytes
        let sanitized = trimmed.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) &&
            scalar.value != 0
        }
        
        let result = String(String.UnicodeScalarView(sanitized))
        
        // Final empty check after sanitization
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        return result
    }
    
    /// Validates and sanitizes notes/description text
    /// - Parameter input: Raw input string
    /// - Returns: Sanitized string (never nil, returns empty string if input is nil)
    static func sanitizeNotes(_ input: String?) -> String {
        guard let input = input else { return "" }
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enforce length limit
        let truncated = String(trimmed.prefix(maxNotesLength))
        
        // Remove null bytes and control characters except newlines and tabs
        let allowedControlChars = CharacterSet(charactersIn: "\n\t")
        let sanitized = truncated.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) ||
            allowedControlChars.contains(scalar)
        }
        
        return String(String.UnicodeScalarView(sanitized))
    }
    
    /// Generates a secure filename that's safe for the filesystem
    /// - Parameters:
    ///   - baseName: Optional base name to include (will be sanitized)
    ///   - extension: File extension without the dot
    /// - Returns: Safe filename with UUID prefix
    static func generateSecureFilename(baseName: String? = nil, extension ext: String) -> String {
        let uuid = UUID().uuidString.prefix(8)
        let timestamp = Int(Date().timeIntervalSince1970)
        
        if let baseName = baseName {
            let sanitized = sanitizeFilename(baseName)
            return "\(uuid)-\(timestamp)-\(sanitized).\(ext)"
        } else {
            return "\(uuid)-\(timestamp).\(ext)"
        }
    }
    
    /// Sanitizes a string to be safe for use in filenames
    /// - Parameter filename: Raw filename
    /// - Returns: Sanitized filename safe for filesystem
    static func sanitizeFilename(_ filename: String) -> String {
        // Characters not allowed in filenames across platforms
        let illegalCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        
        let sanitized = filename.unicodeScalars.filter { scalar in
            !illegalCharacters.contains(scalar) &&
            !CharacterSet.controlCharacters.contains(scalar)
        }
        
        var result = String(String.UnicodeScalarView(sanitized))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit length
        if result.count > 50 {
            result = String(result.prefix(50))
        }
        
        // Ensure not empty
        if result.isEmpty {
            result = "unnamed"
        }
        
        return result
    }
    
    /// Validates file size is within acceptable limits
    /// - Parameters:
    ///   - url: File URL to check
    ///   - maxSize: Maximum allowed size in bytes
    /// - Returns: true if file is within size limit
    static func validateFileSize(at url: URL, maxSize: Int64 = maxPDFFileSize) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return fileSize <= maxSize
            }
        } catch {
            SecureLogger.warning("Could not determine file size for validation")
        }
        return false
    }
    
    /// Validates a numeric score is within expected bounds
    /// - Parameters:
    ///   - score: The score to validate
    ///   - min: Minimum allowed value (default 0)
    ///   - max: Maximum allowed value (default 100)
    /// - Returns: Clamped value within bounds
    static func validateScore(_ score: Double, min: Double = 0, max: Double = 100) -> Double {
        return Swift.min(Swift.max(score, min), max)
    }
    
    /// Validates an integer count is within expected bounds
    /// - Parameters:
    ///   - count: The count to validate
    ///   - min: Minimum allowed value (default 0)
    ///   - max: Maximum allowed value (default Int.max)
    /// - Returns: Clamped value within bounds
    static func validateCount(_ count: Int, min: Int = 0, max: Int = Int.max) -> Int {
        return Swift.min(Swift.max(count, min), max)
    }
}

// MARK: - Validation Results

extension SecurityHelpers {
    
    /// Result of a validation operation
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var errorMessage: String? {
            if case .invalid(let reason) = self { return reason }
            return nil
        }
    }
    
    /// Validates backup data before import
    /// - Parameter data: Raw backup data
    /// - Returns: Validation result
    static func validateBackupData(_ data: Data) -> ValidationResult {
        // Check for empty data
        guard !data.isEmpty else {
            return .invalid(reason: "Backup file is empty")
        }
        
        // Check for reasonable size (max 500MB)
        let maxBackupSize = 500 * 1024 * 1024
        guard data.count <= maxBackupSize else {
            return .invalid(reason: "Backup file exceeds maximum size limit")
        }
        
        // Try to parse as JSON to ensure valid format
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return .invalid(reason: "Backup file is not valid JSON")
        }
        
        return .valid
    }
}
