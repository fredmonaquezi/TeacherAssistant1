import SwiftData
import Foundation

/// Current backup schema version for compatibility checking
private let currentBackupSchemaVersion = 1

/// Extended backup file structure with versioning
struct VersionedBackupFile: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var classes: [BackupClass]
    
    init(classes: [BackupClass]) {
        self.schemaVersion = currentBackupSchemaVersion
        self.createdAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.classes = classes
    }
}

@MainActor
final class BackupManager {
    
    /// Tracks if an operation is in progress to prevent concurrent operations
    private static var isOperationInProgress = false
    
    /// Minimum interval between operations (5 seconds)
    private static let minimumOperationInterval: TimeInterval = 5.0
    
    /// Last operation timestamp
    private static var lastOperationTime: Date?
    
    // MARK: - Export
    
    @MainActor
    static func exportBackup(context: ModelContext) throws -> URL {
        // Rate limiting check
        try checkOperationAllowed()
        
        defer {
            isOperationInProgress = false
            lastOperationTime = Date()
        }
        
        isOperationInProgress = true
        
        SecureLogger.operationStart("Backup Export")
        
        let descriptor = FetchDescriptor<SchoolClass>()
        let classes = try context.fetch(descriptor)
        
        SecureLogger.backupStep(1, "Fetched \(classes.count) classes")
        
        var backupClasses: [BackupClass] = []
        
        for schoolClass in classes {
            SecureLogger.backupStep(2, "Processing class")
            
            var backupStudents: [BackupStudent] = []
            for s in schoolClass.students {
                backupStudents.append(
                    BackupStudent(
                        name: s.name,
                        sortOrder: SecurityHelpers.validateCount(s.sortOrder, min: 0, max: 10000),
                        isParticipatingWell: s.isParticipatingWell,
                        needsHelp: s.needsHelp,
                        missingHomework: s.missingHomework
                    )
                )
            }
            
            var backupSubjects: [BackupSubject] = []
            
            for subject in schoolClass.subjects {
                var backupUnits: [BackupUnit] = []
                
                for unit in subject.units {
                    var backupAssessments: [BackupAssessment] = []
                    
                    for assessment in unit.assessments {
                        var backupResults: [BackupResult] = []
                        
                        for result in assessment.results {
                            backupResults.append(
                                BackupResult(
                                    studentName: result.student?.name ?? "",
                                    score: SecurityHelpers.validateScore(result.score),
                                    notes: SecurityHelpers.sanitizeNotes(result.notes)
                                )
                            )
                        }
                        
                        backupAssessments.append(
                            BackupAssessment(
                                title: assessment.title,
                                details: SecurityHelpers.sanitizeNotes(assessment.details),
                                sortOrder: SecurityHelpers.validateCount(assessment.sortOrder, min: 0, max: 10000),
                                results: backupResults
                            )
                        )
                    }
                    
                    backupUnits.append(
                        BackupUnit(
                            name: unit.name,
                            sortOrder: SecurityHelpers.validateCount(unit.sortOrder, min: 0, max: 10000),
                            assessments: backupAssessments
                        )
                    )
                }
                
                backupSubjects.append(
                    BackupSubject(
                        name: subject.name,
                        sortOrder: SecurityHelpers.validateCount(subject.sortOrder, min: 0, max: 10000),
                        units: backupUnits
                    )
                )
            }
            
            backupClasses.append(
                BackupClass(
                    name: schoolClass.name,
                    grade: schoolClass.grade,
                    students: backupStudents,
                    subjects: backupSubjects
                )
            )
        }
        
        SecureLogger.backupStep(3, "Built backup models")
        
        // Create versioned backup
        let versionedBackup = VersionedBackupFile(classes: backupClasses)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(versionedBackup)
        
        // Use secure filename generation
        let filename = SecurityHelpers.generateSecureFilename(baseName: "TeacherAssistant", extension: "backup")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        
        SecureLogger.operationComplete("Backup Export")
        
        // Schedule cleanup of temp file after 5 minutes
        scheduleTemporaryFileCleanup(url: url, delay: 300)
        
        return url
    }
    
    // MARK: - Import
    
    static func importBackup(from url: URL, context: ModelContext) throws {
        // Rate limiting check
        try checkOperationAllowed()
        
        defer {
            isOperationInProgress = false
            lastOperationTime = Date()
        }
        
        isOperationInProgress = true
        
        SecureLogger.operationStart("Backup Import")
        
        // Validate file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BackupError.fileNotFound
        }
        
        // Validate file size
        guard SecurityHelpers.validateFileSize(at: url, maxSize: 500 * 1024 * 1024) else {
            throw BackupError.fileTooLarge
        }
        
        let data = try Data(contentsOf: url)
        
        // Validate data before processing
        let validationResult = SecurityHelpers.validateBackupData(data)
        guard validationResult.isValid else {
            throw BackupError.invalidData(validationResult.errorMessage ?? "Unknown validation error")
        }
        
        // Try to decode as versioned backup first
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var backupClasses: [BackupClass]
        
        if let versionedBackup = try? decoder.decode(VersionedBackupFile.self, from: data) {
            // Validate schema version
            guard versionedBackup.schemaVersion <= currentBackupSchemaVersion else {
                throw BackupError.incompatibleVersion(versionedBackup.schemaVersion)
            }
            backupClasses = versionedBackup.classes
            SecureLogger.info("Importing versioned backup (v\(versionedBackup.schemaVersion))")
        } else {
            // Fallback to legacy format (BackupFile without versioning)
            let legacyBackup = try decoder.decode(BackupFile.self, from: data)
            backupClasses = legacyBackup.classes
            SecureLogger.info("Importing legacy backup format")
        }
        
        SecureLogger.backupStep(1, "Decoded backup with \(backupClasses.count) classes")
        
        // Validate backup contents before wiping database
        try validateBackupContents(backupClasses)
        
        // Now safe to wipe existing database
        try context.delete(model: SchoolClass.self)
        
        for backupClass in backupClasses {
            // Sanitize inputs
            guard let sanitizedClassName = SecurityHelpers.sanitizeName(backupClass.name) else {
                SecureLogger.warning("Skipping class with invalid name")
                continue
            }
            
            let newClass = SchoolClass(
                name: sanitizedClassName,
                grade: SecurityHelpers.sanitizeName(backupClass.grade) ?? "Unknown"
            )
            context.insert(newClass)
            
            // Students
            for s in backupClass.students {
                guard let sanitizedName = SecurityHelpers.sanitizeName(s.name) else {
                    SecureLogger.warning("Skipping student with invalid name")
                    continue
                }
                
                let student = Student(name: sanitizedName)
                student.isParticipatingWell = s.isParticipatingWell
                student.sortOrder = SecurityHelpers.validateCount(s.sortOrder, min: 0, max: 10000)
                student.needsHelp = s.needsHelp
                student.missingHomework = s.missingHomework
                newClass.students.append(student)
            }
            
            // Subjects
            for sub in backupClass.subjects {
                guard let sanitizedSubjectName = SecurityHelpers.sanitizeName(sub.name) else {
                    SecureLogger.warning("Skipping subject with invalid name")
                    continue
                }
                
                let subject = Subject(name: sanitizedSubjectName)
                subject.sortOrder = SecurityHelpers.validateCount(sub.sortOrder, min: 0, max: 10000)
                subject.schoolClass = newClass
                newClass.subjects.append(subject)
                
                for u in sub.units {
                    guard let sanitizedUnitName = SecurityHelpers.sanitizeName(u.name) else {
                        SecureLogger.warning("Skipping unit with invalid name")
                        continue
                    }
                    
                    let unit = Unit(name: sanitizedUnitName)
                    unit.subject = subject
                    unit.sortOrder = SecurityHelpers.validateCount(u.sortOrder, min: 0, max: 10000)
                    subject.units.append(unit)
                    
                    for a in u.assessments {
                        guard let sanitizedTitle = SecurityHelpers.sanitizeName(a.title) else {
                            SecureLogger.warning("Skipping assessment with invalid title")
                            continue
                        }
                        
                        let assessment = Assessment(title: sanitizedTitle)
                        assessment.sortOrder = SecurityHelpers.validateCount(a.sortOrder, min: 0, max: 10000)
                        assessment.details = SecurityHelpers.sanitizeNotes(a.details)
                        assessment.unit = unit
                        unit.assessments.append(assessment)
                        
                        for r in a.results {
                            if let student = newClass.students.first(where: { $0.name == r.studentName }) {
                                let result = StudentResult(
                                    student: student,
                                    score: SecurityHelpers.validateScore(r.score),
                                    notes: SecurityHelpers.sanitizeNotes(r.notes)
                                )
                                result.assessment = assessment
                                context.insert(result)
                            }
                        }
                    }
                }
            }
        }
        
        try context.save()
        
        // Record successful backup
        UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
        
        SecureLogger.operationComplete("Backup Import")
    }
    
    // MARK: - Private Helpers
    
    /// Validates that an operation can proceed (rate limiting)
    private static func checkOperationAllowed() throws {
        guard !isOperationInProgress else {
            throw BackupError.operationInProgress
        }
        
        if let lastTime = lastOperationTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumOperationInterval {
                throw BackupError.rateLimited(remainingSeconds: Int(minimumOperationInterval - elapsed))
            }
        }
    }
    
    /// Validates backup contents before import
    private static func validateBackupContents(_ classes: [BackupClass]) throws {
        // Check for reasonable limits
        guard classes.count <= 1000 else {
            throw BackupError.invalidData("Too many classes in backup")
        }
        
        for backupClass in classes {
            guard backupClass.students.count <= 10000 else {
                throw BackupError.invalidData("Too many students in a class")
            }
            
            guard backupClass.subjects.count <= 1000 else {
                throw BackupError.invalidData("Too many subjects in a class")
            }
        }
    }
    
    /// Schedules cleanup of temporary files
    private static func scheduleTemporaryFileCleanup(url: URL, delay: TimeInterval) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    SecureLogger.debug("Cleaned up temporary backup file")
                }
            } catch {
                SecureLogger.warning("Failed to cleanup temporary file")
            }
        }
    }
}

// MARK: - Backup Errors

enum BackupError: LocalizedError {
    case fileNotFound
    case fileTooLarge
    case invalidData(String)
    case incompatibleVersion(Int)
    case operationInProgress
    case rateLimited(remainingSeconds: Int)
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The backup file could not be found."
        case .fileTooLarge:
            return "The backup file is too large to process."
        case .invalidData(let reason):
            return "The backup file contains invalid data: \(reason)"
        case .incompatibleVersion(let version):
            return "This backup was created with a newer version of the app (v\(version)). Please update the app to restore this backup."
        case .operationInProgress:
            return "A backup operation is already in progress. Please wait."
        case .rateLimited(let seconds):
            return "Please wait \(seconds) seconds before trying again."
        case .saveFailed:
            return "Failed to save the restored data."
        }
    }
}
