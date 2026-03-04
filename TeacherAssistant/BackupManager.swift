import SwiftData
import Foundation

/// Current backup schema version for compatibility checking
private let currentBackupSchemaVersion = 6

extension Notification.Name {
    static let backupRestoreDidComplete = Notification.Name("BackupRestoreDidComplete")
}

private let randomPickerSettingsKeys: [String] = [
    "helperRotation",
    "guardianRotation",
    "lineLeaderRotation",
    "messengerRotation",
    "customCategoriesData",
    "customRotationData"
]

private enum TimerPreferenceKeys {
    static let customMinutes = "ta_timer_custom_minutes"
    static let customSeconds = "ta_timer_custom_seconds"
    static let customChecklistText = "ta_timer_custom_checklist_text"
}

/// Extended backup file structure with versioning
struct VersionedBackupFile: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var classes: [BackupClass]
    var runningRecords: [BackupRunningRecord]
    var rubricTemplates: [BackupRubricTemplate]
    var developmentScores: [BackupDevelopmentScore]
    var calendarEvents: [BackupCalendarEvent]
    var classDiaryEntries: [BackupClassDiaryEntry]
    var libraryFolders: [BackupLibraryFolder]
    var libraryFiles: [BackupLibraryFile]
    var usefulLinks: [BackupUsefulLink]
    var appSettings: BackupAppSettings?

    init(
        classes: [BackupClass],
        runningRecords: [BackupRunningRecord],
        rubricTemplates: [BackupRubricTemplate],
        developmentScores: [BackupDevelopmentScore],
        calendarEvents: [BackupCalendarEvent],
        classDiaryEntries: [BackupClassDiaryEntry],
        libraryFolders: [BackupLibraryFolder],
        libraryFiles: [BackupLibraryFile],
        usefulLinks: [BackupUsefulLink],
        appSettings: BackupAppSettings?
    ) {
        self.schemaVersion = currentBackupSchemaVersion
        self.createdAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.classes = classes
        self.runningRecords = runningRecords
        self.rubricTemplates = rubricTemplates
        self.developmentScores = developmentScores
        self.calendarEvents = calendarEvents
        self.classDiaryEntries = classDiaryEntries
        self.libraryFolders = libraryFolders
        self.libraryFiles = libraryFiles
        self.usefulLinks = usefulLinks
        self.appSettings = appSettings
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case createdAt
        case appVersion
        case classes
        case runningRecords
        case rubricTemplates
        case developmentScores
        case calendarEvents
        case classDiaryEntries
        case libraryFolders
        case libraryFiles
        case usefulLinks
        case appSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        classes = try container.decode([BackupClass].self, forKey: .classes)
        runningRecords = try container.decodeIfPresent([BackupRunningRecord].self, forKey: .runningRecords) ?? []
        rubricTemplates = try container.decodeIfPresent([BackupRubricTemplate].self, forKey: .rubricTemplates) ?? []
        developmentScores = try container.decodeIfPresent([BackupDevelopmentScore].self, forKey: .developmentScores) ?? []
        calendarEvents = try container.decodeIfPresent([BackupCalendarEvent].self, forKey: .calendarEvents) ?? []
        classDiaryEntries = try container.decodeIfPresent([BackupClassDiaryEntry].self, forKey: .classDiaryEntries) ?? []
        libraryFolders = try container.decodeIfPresent([BackupLibraryFolder].self, forKey: .libraryFolders) ?? []
        libraryFiles = try container.decodeIfPresent([BackupLibraryFile].self, forKey: .libraryFiles) ?? []
        usefulLinks = try container.decodeIfPresent([BackupUsefulLink].self, forKey: .usefulLinks) ?? []
        appSettings = try container.decodeIfPresent(BackupAppSettings.self, forKey: .appSettings)
    }
}

private struct DecodedBackupPayload {
    var classes: [BackupClass]
    var runningRecords: [BackupRunningRecord]
    var rubricTemplates: [BackupRubricTemplate]
    var developmentScores: [BackupDevelopmentScore]
    var calendarEvents: [BackupCalendarEvent]
    var classDiaryEntries: [BackupClassDiaryEntry]
    var libraryFolders: [BackupLibraryFolder]
    var libraryFiles: [BackupLibraryFile]
    var usefulLinks: [BackupUsefulLink]
    var appSettings: BackupAppSettings?
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

        let data = try encodedBackupData(from: context)
        let url = try writeBackupData(
            data,
            baseName: "TeacherAssistant",
            directory: FileManager.default.temporaryDirectory,
            scheduleCleanup: true
        )
        
        SecureLogger.operationComplete("Backup Export")
        
        return url
    }

    private static func encodedBackupData(from context: ModelContext) throws -> Data {

        if context.hasChanges {
            try context.save()
        }

        let exportContext = ModelContext(context.container)
        
        let descriptor = FetchDescriptor<SchoolClass>()
        let classes = try exportContext.fetch(descriptor)
        let allStudents = try exportContext.fetch(FetchDescriptor<Student>())
        let allRunningRecords = try exportContext.fetch(FetchDescriptor<RunningRecord>())
        let allRubricTemplates = try exportContext.fetch(FetchDescriptor<RubricTemplate>())
        let allDevelopmentScores = try exportContext.fetch(FetchDescriptor<DevelopmentScore>())
        let allCalendarEvents = try exportContext.fetch(FetchDescriptor<CalendarEvent>())
        let allDiaryEntries = try exportContext.fetch(FetchDescriptor<ClassDiaryEntry>())
        let allLibraryFolders = try exportContext.fetch(FetchDescriptor<LibraryFolder>())
        let allLibraryFiles = try exportContext.fetch(FetchDescriptor<LibraryFile>())
        let allUsefulLinks = try exportContext.fetch(FetchDescriptor<UsefulLink>())

        var studentsByClassID: [PersistentIdentifier: [Student]] = [:]
        for student in allStudents {
            guard let classID = student.schoolClass?.persistentModelID else { continue }
            studentsByClassID[classID, default: []].append(student)
        }
        
        SecureLogger.backupStep(1, "Fetched \(classes.count) classes")
        
        var backupClasses: [BackupClass] = []
        
        for schoolClass in classes {
            SecureLogger.backupStep(2, "Processing class")
            
            var backupStudents: [BackupStudent] = []
            let classStudents = (studentsByClassID[schoolClass.persistentModelID] ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }

            for s in classStudents {
                backupStudents.append(
                    BackupStudent(
                        uuid: s.uuid,
                        name: s.name,
                        firstName: s.firstName,
                        lastName: s.lastName,
                        notes: SecurityHelpers.sanitizeNotes(s.notes),
                        gender: s.gender,
                        sortOrder: SecurityHelpers.validateCount(s.sortOrder, min: 0, max: 10000),
                        isParticipatingWell: s.isParticipatingWell,
                        needsHelp: s.needsHelp,
                        missingHomework: s.missingHomework,
                        separationList: s.separationList,
                        assessmentScores: s.scores.map { score in
                            BackupAssessmentScore(
                                value: SecurityHelpers.validateCount(score.value, min: 0, max: 10)
                            )
                        }
                    )
                )
            }

            let backupCategories = schoolClass.categories.map {
                BackupAssessmentCategory(title: $0.title)
            }

            let backupAttendanceSessions = schoolClass.attendanceSessions.map { session in
                BackupAttendanceSession(
                    date: session.date,
                    records: session.records.compactMap { record in
                        guard let student = record.student else {
                            return nil
                        }

                        return BackupAttendanceRecord(
                            studentUUID: student.uuid,
                            studentName: student.name,
                            statusRaw: record.statusRaw,
                            notes: SecurityHelpers.sanitizeNotes(record.notes)
                        )
                    }
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
                                    studentUUID: result.student?.uuid,
                                    studentName: result.student?.name ?? "",
                                    score: SecurityHelpers.validateScore(
                                        result.score,
                                        min: 0,
                                        max: assessment.safeMaxScore
                                    ),
                                    hasScore: result.isScored,
                                    notes: SecurityHelpers.sanitizeNotes(result.notes)
                                )
                            )
                        }
                        
                        backupAssessments.append(
                            BackupAssessment(
                                title: assessment.title,
                                details: SecurityHelpers.sanitizeNotes(assessment.details),
                                date: assessment.date,
                                maxScore: assessment.maxScore.isFinite
                                    ? Swift.min(Swift.max(assessment.maxScore, 1), 1000)
                                    : 10,
                                sortOrder: SecurityHelpers.validateCount(assessment.sortOrder, min: 0, max: 10000),
                                results: backupResults
                            )
                        )
                    }
                    
                    backupUnits.append(
                        BackupUnit(
                            id: unit.id,
                            name: unit.name,
                            sortOrder: SecurityHelpers.validateCount(unit.sortOrder, min: 0, max: 10000),
                            assessments: backupAssessments
                        )
                    )
                }
                
                backupSubjects.append(
                    BackupSubject(
                        id: subject.id,
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
                    schoolYear: schoolClass.schoolYear,
                    sortOrder: SecurityHelpers.validateCount(schoolClass.sortOrder, min: 0, max: 10000),
                    students: backupStudents,
                    categories: backupCategories,
                    attendanceSessions: backupAttendanceSessions,
                    subjects: backupSubjects
                )
            )
        }

        let backupRunningRecords = allRunningRecords.compactMap { record -> BackupRunningRecord? in
            guard let student = record.student else { return nil }
            return BackupRunningRecord(
                studentUUID: student.uuid,
                date: record.date,
                textTitle: record.textTitle,
                bookLevel: SecurityHelpers.sanitizeBookLevel(record.bookLevel),
                totalWords: SecurityHelpers.validateCount(record.totalWords, min: 0, max: 1_000_000),
                errors: SecurityHelpers.validateCount(record.errors, min: 0, max: 1_000_000),
                selfCorrections: SecurityHelpers.validateCount(record.selfCorrections, min: 0, max: 1_000_000),
                notes: SecurityHelpers.sanitizeNotes(record.notes)
            )
        }

        let backupRubricTemplates = allRubricTemplates.map { template in
            BackupRubricTemplate(
                id: template.id,
                name: template.name,
                gradeLevel: template.gradeLevel,
                subject: template.subject,
                sortOrder: SecurityHelpers.validateCount(template.sortOrder, min: 0, max: 10000),
                categories: template.categories.map { category in
                    BackupRubricCategory(
                        id: category.id,
                        name: category.name,
                        sortOrder: SecurityHelpers.validateCount(category.sortOrder, min: 0, max: 10000),
                        criteria: category.criteria.map { criterion in
                            BackupRubricCriterion(
                                id: criterion.id,
                                name: criterion.name,
                                details: SecurityHelpers.sanitizeNotes(criterion.details),
                                sortOrder: SecurityHelpers.validateCount(criterion.sortOrder, min: 0, max: 10000)
                            )
                        }
                    )
                }
            )
        }

        let backupDevelopmentScores = allDevelopmentScores.compactMap { score -> BackupDevelopmentScore? in
            guard let studentUUID = score.storedStudentUUID,
                  let criterionID = score.storedCriterionID else {
                return nil
            }

            return BackupDevelopmentScore(
                id: score.id,
                studentUUID: studentUUID,
                criterionID: criterionID,
                rating: SecurityHelpers.validateCount(score.rating, min: 1, max: 5),
                date: score.date,
                notes: SecurityHelpers.sanitizeNotes(score.notes)
            )
        }

        let skippedDevelopmentScores = allDevelopmentScores.count - backupDevelopmentScores.count
        if skippedDevelopmentScores > 0 {
            SecureLogger.warning(
                "Skipped \(skippedDevelopmentScores) development scores that still need reference recovery before backup"
            )
        }

        let backupCalendarEvents = allCalendarEvents.map { event in
            BackupCalendarEvent(
                title: event.title,
                date: event.date,
                startTime: event.startTime,
                endTime: event.endTime,
                details: SecurityHelpers.sanitizeNotes(event.details),
                isAllDay: event.isAllDay,
                className: event.schoolClass?.name,
                classGrade: event.schoolClass?.grade
            )
        }

        let backupClassDiaryEntries = allDiaryEntries.map { entry in
            BackupClassDiaryEntry(
                date: entry.date,
                startTime: entry.startTime,
                endTime: entry.endTime,
                plan: SecurityHelpers.sanitizeNotes(entry.plan),
                objectives: SecurityHelpers.sanitizeNotes(entry.objectives),
                materials: SecurityHelpers.sanitizeNotes(entry.materials),
                notes: SecurityHelpers.sanitizeNotes(entry.notes),
                className: entry.schoolClass?.name,
                classGrade: entry.schoolClass?.grade,
                subjectID: entry.subject?.id,
                unitID: entry.unit?.id
            )
        }

        let backupLibraryFolders = allLibraryFolders
            .sorted { lhs, rhs in
                if lhs.parentID == nil && rhs.parentID != nil {
                    return true
                }
                if lhs.parentID != nil && rhs.parentID == nil {
                    return false
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { folder in
                BackupLibraryFolder(
                    id: folder.id,
                    name: folder.name,
                    parentID: folder.parentID,
                    colorHex: folder.colorHex
                )
            }

        let backupLibraryFiles = allLibraryFiles
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { file in
                BackupLibraryFile(
                    id: file.id,
                    name: file.name,
                    pdfData: file.pdfData,
                    parentFolderID: file.parentFolderID,
                    drawingData: file.drawingData,
                    linkedSubjectID: file.linkedSubject?.id,
                    linkedUnitID: file.linkedUnit?.id
                )
            }

        let backupUsefulLinks = allUsefulLinks
            .sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.createdAt < $1.createdAt
            }
            .map { link in
                BackupUsefulLink(
                    id: link.id,
                    title: link.title,
                    url: link.url,
                    description: SecurityHelpers.sanitizeNotes(link.linkDescription),
                    sortOrder: SecurityHelpers.validateCount(link.sortOrder, min: 0, max: 10000),
                    createdAt: link.createdAt,
                    updatedAt: link.updatedAt
                )
            }
        
        SecureLogger.backupStep(3, "Built backup models")
        
        let defaults = UserDefaults.standard
        let backupAppSettings = BackupAppSettings(
            appLanguage: defaults.string(forKey: "appLanguage"),
            helperRotation: defaults.string(forKey: "helperRotation") ?? "",
            guardianRotation: defaults.string(forKey: "guardianRotation") ?? "",
            lineLeaderRotation: defaults.string(forKey: "lineLeaderRotation") ?? "",
            messengerRotation: defaults.string(forKey: "messengerRotation") ?? "",
            customCategoriesData: defaults.string(forKey: "customCategoriesData") ?? "",
            customRotationData: defaults.string(forKey: "customRotationData") ?? "",
            dateFormat: defaults.string(forKey: AppPreferencesKeys.dateFormat) ?? AppDateFormatPreference.system.rawValue,
            timeFormat: defaults.string(forKey: AppPreferencesKeys.timeFormat) ?? AppTimeFormatPreference.system.rawValue,
            defaultLandingSection: defaults.string(forKey: AppPreferencesKeys.defaultLandingSection) ?? AppSection.dashboard.rawValue,
            timerCustomMinutes: defaults.object(forKey: TimerPreferenceKeys.customMinutes) as? Int ?? 5,
            timerCustomSeconds: defaults.object(forKey: TimerPreferenceKeys.customSeconds) as? Int ?? 0,
            timerCustomChecklistText: defaults.string(forKey: TimerPreferenceKeys.customChecklistText) ?? ""
        )

        // Create versioned backup
        let versionedBackup = VersionedBackupFile(
            classes: backupClasses,
            runningRecords: backupRunningRecords,
            rubricTemplates: backupRubricTemplates,
            developmentScores: backupDevelopmentScores,
            calendarEvents: backupCalendarEvents,
            classDiaryEntries: backupClassDiaryEntries,
            libraryFolders: backupLibraryFolders,
            libraryFiles: backupLibraryFiles,
            usefulLinks: backupUsefulLinks,
            appSettings: backupAppSettings
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(versionedBackup)
    }

    private static func writeBackupData(
        _ data: Data,
        baseName: String,
        directory: URL,
        scheduleCleanup: Bool
    ) throws -> URL {
        let filename = SecurityHelpers.generateSecureFilename(baseName: baseName, extension: "backup")
        let url = directory.appendingPathComponent(filename)

        try data.write(to: url, options: [.atomic, .completeFileProtection])

        if scheduleCleanup {
            self.scheduleTemporaryFileCleanup(url: url, delay: 300)
        }

        return url
    }

    static func createPersistentSnapshot(
        context: ModelContext,
        baseName: String,
        directory: URL
    ) throws -> URL {
        let data = try encodedBackupData(from: context)
        return try writeBackupData(
            data,
            baseName: baseName,
            directory: directory,
            scheduleCleanup: false
        )
    }

    static func latestLocalSnapshotURL() -> URL? {
        let directories = [
            try? applicationSupportSubdirectory(named: "AutomaticSnapshots", createIfMissing: false),
            try? applicationSupportSubdirectory(named: "PreRestoreSnapshots", createIfMissing: false),
        ]
        .compactMap { $0 }

        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey]
        var latestMatch: (url: URL, date: Date)?

        for directory in directories {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in urls where url.pathExtension == "backup" {
                guard let values = try? url.resourceValues(forKeys: resourceKeys),
                      let snapshotDate = values.contentModificationDate ?? values.creationDate else {
                    continue
                }

                if latestMatch == nil || snapshotDate > latestMatch!.date {
                    latestMatch = (url, snapshotDate)
                }
            }
        }

        return latestMatch?.url
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

        let restoreOutcome: RestoreExecutionResult<DecodedBackupPayload>
        do {
            restoreOutcome = try RestoreExecutionCoordinator.prepareAndApply(
                loadPayload: {
                    let payload = try decodeBackupPayload(from: data)
                    SecureLogger.backupStep(1, "Decoded backup with \(payload.classes.count) classes")
                    try validateBackupContents(payload.classes)
                    return payload
                },
                validatePayload: { payload in
                    try validateRestorePayload(payload)
                    SecureLogger.backupStep(2, "Validated restore in temporary container")
                },
                createSafetySnapshot: {
                    let snapshotURL = try createPreRestoreSafetySnapshot(from: context)
                    SecureLogger.info(
                        "Created pre-restore safety snapshot: \(snapshotURL.lastPathComponent)"
                    )
                    return snapshotURL
                },
                applyPayload: { payload in
                    let restoreContext = ModelContext(context.container)
                    try applyBackupPayload(payload, to: restoreContext, clearExistingData: true)
                }
            )
        } catch {
            if case let RestoreExecutionError.applyFailed(preRestoreSnapshotURL, underlyingError) = error {
                SecureLogger.error(
                    "Restore failed after creating a safety snapshot at \(preRestoreSnapshotURL.path)",
                    error: underlyingError
                )
                throw underlyingError
            }
            throw error
        }

        let backupPayload = restoreOutcome.payload
        let preRestoreSnapshotURL = restoreOutcome.preRestoreSnapshotURL
        SecureLogger.info("Restore applied using safety snapshot: \(preRestoreSnapshotURL.lastPathComponent)")

        if let settings = backupPayload.appSettings {
            restoreAppSettings(settings)
        }
        
        // Record successful backup
        UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
        NotificationCenter.default.post(name: .backupRestoreDidComplete, object: nil)
        
        SecureLogger.operationComplete("Backup Import")
    }

    private static func decodeBackupPayload(from data: Data) throws -> DecodedBackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let versionedBackup = try? decoder.decode(VersionedBackupFile.self, from: data) {
            guard versionedBackup.schemaVersion <= currentBackupSchemaVersion else {
                throw BackupError.incompatibleVersion(versionedBackup.schemaVersion)
            }

            SecureLogger.info("Importing versioned backup (v\(versionedBackup.schemaVersion))")

            return DecodedBackupPayload(
                classes: versionedBackup.classes,
                runningRecords: versionedBackup.runningRecords,
                rubricTemplates: versionedBackup.rubricTemplates,
                developmentScores: versionedBackup.developmentScores,
                calendarEvents: versionedBackup.calendarEvents,
                classDiaryEntries: versionedBackup.classDiaryEntries,
                libraryFolders: versionedBackup.libraryFolders,
                libraryFiles: versionedBackup.libraryFiles,
                usefulLinks: versionedBackup.usefulLinks,
                appSettings: versionedBackup.appSettings
            )
        }

        let legacyBackup = try decoder.decode(BackupFile.self, from: data)
        SecureLogger.info("Importing legacy backup format")

        return DecodedBackupPayload(
            classes: legacyBackup.classes,
            runningRecords: [],
            rubricTemplates: [],
            developmentScores: [],
            calendarEvents: [],
            classDiaryEntries: [],
            libraryFolders: [],
            libraryFiles: [],
            usefulLinks: [],
            appSettings: nil
        )
    }

    private static func validateRestorePayload(_ payload: DecodedBackupPayload) throws {
        let configuration = ModelConfiguration(
            "BackupValidation",
            schema: PersistenceSchema.schema,
            isStoredInMemoryOnly: true
        )
        let validationContainer = try ModelContainer(
            for: PersistenceSchema.schema,
            configurations: [configuration]
        )
        let validationContext = ModelContext(validationContainer)

        try applyBackupPayload(payload, to: validationContext, clearExistingData: false)
    }

    private static func createPreRestoreSafetySnapshot(from context: ModelContext) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        return try createPersistentSnapshot(
            context: context,
            baseName: "TeacherAssistant-PreRestore-\(formatter.string(from: Date()))",
            directory: try preRestoreSnapshotDirectory()
        )
    }

    private static func preRestoreSnapshotDirectory() throws -> URL {
        try applicationSupportSubdirectory(
            named: "PreRestoreSnapshots",
            createIfMissing: true
        )
    }

    private static func applicationSupportSubdirectory(
        named name: String,
        createIfMissing: Bool
    ) throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleDirectory = applicationSupportDirectory.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "TeacherAssistant",
            isDirectory: true
        )
        let directory = bundleDirectory.appendingPathComponent(
            name,
            isDirectory: true
        )

        if createIfMissing && !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return directory
    }

    private static func applyBackupPayload(
        _ payload: DecodedBackupPayload,
        to context: ModelContext,
        clearExistingData: Bool
    ) throws {
        if clearExistingData {
            // Use object-level deletes (instead of batch delete(model:)) to avoid
            // relationship-constraint violations during restore on some stores.
            try deleteAll(CalendarEvent.self, in: context)
            try deleteAll(ClassDiaryEntry.self, in: context)
            try deleteAll(DevelopmentScore.self, in: context)
            try deleteAll(LibraryFile.self, in: context)
            try deleteAll(LibraryFolder.self, in: context)
            try deleteAll(RubricTemplate.self, in: context)
            try deleteAll(RunningRecord.self, in: context)
            try deleteAll(UsefulLink.self, in: context)
            try deleteAll(SchoolClass.self, in: context)
        }

        var studentByUUID: [UUID: Student] = [:]
        var subjectByID: [UUID: Subject] = [:]
        var unitByID: [UUID: Unit] = [:]
        var classByKey: [String: SchoolClass] = [:]

        for backupClass in payload.classes {
            guard let sanitizedClassName = SecurityHelpers.sanitizeName(backupClass.name) else {
                SecureLogger.warning("Skipping class with invalid name")
                continue
            }

            let newClass = SchoolClass(
                name: sanitizedClassName,
                grade: SecurityHelpers.sanitizeName(backupClass.grade) ?? "Unknown",
                schoolYear: SecurityHelpers.sanitizeName(backupClass.schoolYear ?? "")
            )
            newClass.sortOrder = SecurityHelpers.validateCount(backupClass.sortOrder, min: 0, max: 10000)
            context.insert(newClass)
            classByKey[classKey(name: newClass.name, grade: newClass.grade)] = newClass

            var seenStudentUUIDs: Set<UUID> = []

            for studentBackup in backupClass.students {
                guard seenStudentUUIDs.insert(studentBackup.uuid).inserted else {
                    SecureLogger.warning("Skipping duplicate student UUID in class backup payload")
                    continue
                }

                guard let sanitizedName = SecurityHelpers.sanitizeName(studentBackup.name) else {
                    SecureLogger.warning("Skipping student with invalid name")
                    continue
                }

                let student = Student(name: sanitizedName)
                student.uuid = studentBackup.uuid
                student.firstName = SecurityHelpers.sanitizeName(studentBackup.firstName ?? "")
                student.lastName = SecurityHelpers.sanitizeName(studentBackup.lastName ?? "")
                student.notes = SecurityHelpers.sanitizeNotes(studentBackup.notes)
                student.gender = studentBackup.gender
                student.isParticipatingWell = studentBackup.isParticipatingWell
                student.sortOrder = SecurityHelpers.validateCount(studentBackup.sortOrder, min: 0, max: 10000)
                student.needsHelp = studentBackup.needsHelp
                student.missingHomework = studentBackup.missingHomework
                student.separationList = studentBackup.separationList
                student.scores = studentBackup.assessmentScores.map { backupScore in
                    AssessmentScore(
                        value: SecurityHelpers.validateCount(backupScore.value, min: 0, max: 10)
                    )
                }
                newClass.students.append(student)
                studentByUUID[student.uuid] = student
            }

            newClass.categories = backupClass.categories.map { backupCategory in
                AssessmentCategory(title: backupCategory.title)
            }

            let expectedScoreCount = newClass.categories.count
            for student in newClass.students {
                if student.scores.count > expectedScoreCount {
                    student.scores = Array(student.scores.prefix(expectedScoreCount))
                } else if student.scores.count < expectedScoreCount {
                    for _ in student.scores.count..<expectedScoreCount {
                        student.scores.append(AssessmentScore(value: 0))
                    }
                }
            }

            for subjectBackup in backupClass.subjects {
                guard let sanitizedSubjectName = SecurityHelpers.sanitizeName(subjectBackup.name) else {
                    SecureLogger.warning("Skipping subject with invalid name")
                    continue
                }

                let subject = Subject(name: sanitizedSubjectName)
                subject.id = subjectBackup.id
                subject.sortOrder = SecurityHelpers.validateCount(subjectBackup.sortOrder, min: 0, max: 10000)
                subject.schoolClass = newClass
                newClass.subjects.append(subject)
                subjectByID[subject.id] = subject

                for unitBackup in subjectBackup.units {
                    guard let sanitizedUnitName = SecurityHelpers.sanitizeName(unitBackup.name) else {
                        SecureLogger.warning("Skipping unit with invalid name")
                        continue
                    }

                    let unit = Unit(name: sanitizedUnitName)
                    unit.id = unitBackup.id
                    unit.subject = subject
                    unit.sortOrder = SecurityHelpers.validateCount(unitBackup.sortOrder, min: 0, max: 10000)
                    subject.units.append(unit)
                    unitByID[unit.id] = unit

                    for assessmentBackup in unitBackup.assessments {
                        guard let sanitizedTitle = SecurityHelpers.sanitizeName(assessmentBackup.title) else {
                            SecureLogger.warning("Skipping assessment with invalid title")
                            continue
                        }

                        let assessment = Assessment(title: sanitizedTitle)
                        assessment.sortOrder = SecurityHelpers.validateCount(
                            assessmentBackup.sortOrder,
                            min: 0,
                            max: 10000
                        )
                        assessment.details = SecurityHelpers.sanitizeNotes(assessmentBackup.details)
                        assessment.date = assessmentBackup.date
                        assessment.maxScore = assessmentBackup.maxScore.isFinite
                            ? Swift.min(Swift.max(assessmentBackup.maxScore, 1), 1000)
                            : 10
                        assessment.unit = unit
                        unit.assessments.append(assessment)

                        for resultBackup in assessmentBackup.results {
                            if let student = resolveStudent(
                                studentUUID: resultBackup.studentUUID,
                                studentName: resultBackup.studentName,
                                classStudents: newClass.students,
                                studentByUUID: studentByUUID
                            ) {
                                let result = StudentResult(
                                    student: student,
                                    score: SecurityHelpers.validateScore(
                                        resultBackup.score,
                                        min: 0,
                                        max: assessment.safeMaxScore
                                    ),
                                    notes: SecurityHelpers.sanitizeNotes(resultBackup.notes),
                                    hasScore: resultBackup.hasScore ?? (resultBackup.score > 0)
                                )
                                result.assessment = assessment
                                context.insert(result)
                            }
                        }
                    }
                }
            }

            newClass.attendanceSessions = backupClass.attendanceSessions.map { backupSession in
                let session = AttendanceSession(date: backupSession.date)
                session.records = backupSession.records.compactMap { backupRecord in
                    guard let student = resolveStudent(
                        studentUUID: backupRecord.studentUUID,
                        studentName: backupRecord.studentName,
                        classStudents: newClass.students,
                        studentByUUID: studentByUUID
                    ) else {
                        return nil
                    }

                    return AttendanceRecord(
                        student: student,
                        status: AttendanceStatus(rawValue: backupRecord.statusRaw) ?? .present,
                        notes: SecurityHelpers.sanitizeNotes(backupRecord.notes)
                    )
                }
                return session
            }
        }

        for backupRecord in payload.runningRecords {
            guard let student = studentByUUID[backupRecord.studentUUID] else { continue }

            let runningRecord = RunningRecord(
                date: backupRecord.date,
                textTitle: backupRecord.textTitle,
                bookLevel: SecurityHelpers.sanitizeBookLevel(backupRecord.bookLevel),
                totalWords: SecurityHelpers.validateCount(backupRecord.totalWords, min: 0, max: 1_000_000),
                errors: SecurityHelpers.validateCount(backupRecord.errors, min: 0, max: 1_000_000),
                selfCorrections: SecurityHelpers.validateCount(
                    backupRecord.selfCorrections,
                    min: 0,
                    max: 1_000_000
                ),
                notes: SecurityHelpers.sanitizeNotes(backupRecord.notes)
            )
            runningRecord.student = student
            context.insert(runningRecord)
        }

        var criterionByID: [UUID: RubricCriterion] = [:]
        for backupTemplate in payload.rubricTemplates {
            let template = RubricTemplate(
                name: backupTemplate.name,
                gradeLevel: backupTemplate.gradeLevel,
                subject: backupTemplate.subject
            )
            template.id = backupTemplate.id
            template.sortOrder = SecurityHelpers.validateCount(backupTemplate.sortOrder, min: 0, max: 10000)
            context.insert(template)

            template.categories = backupTemplate.categories.map { backupCategory in
                let category = RubricCategory(name: backupCategory.name)
                category.id = backupCategory.id
                category.sortOrder = SecurityHelpers.validateCount(backupCategory.sortOrder, min: 0, max: 10000)
                category.template = template
                category.criteria = backupCategory.criteria.map { backupCriterion in
                    let criterion = RubricCriterion(
                        name: backupCriterion.name,
                        details: SecurityHelpers.sanitizeNotes(backupCriterion.details)
                    )
                    criterion.id = backupCriterion.id
                    criterion.sortOrder = SecurityHelpers.validateCount(backupCriterion.sortOrder, min: 0, max: 10000)
                    criterion.category = category
                    criterionByID[criterion.id] = criterion
                    return criterion
                }
                return category
            }
        }

        for backupScore in payload.developmentScores {
            guard let student = studentByUUID[backupScore.studentUUID],
                  let criterion = criterionByID[backupScore.criterionID] else {
                continue
            }

            let score = DevelopmentScore(
                student: student,
                criterion: criterion,
                rating: SecurityHelpers.validateCount(backupScore.rating, min: 1, max: 5),
                notes: SecurityHelpers.sanitizeNotes(backupScore.notes),
                date: backupScore.date
            )
            score.id = backupScore.id
            context.insert(score)
        }

        var libraryFolderByID: [UUID: LibraryFolder] = [:]
        for backupFolder in payload.libraryFolders {
            guard let sanitizedName = SecurityHelpers.sanitizeName(backupFolder.name) else {
                continue
            }

            let folder = LibraryFolder(
                name: sanitizedName,
                parentID: backupFolder.parentID,
                colorHex: sanitizedColorHex(backupFolder.colorHex)
            )
            folder.id = backupFolder.id
            context.insert(folder)
            libraryFolderByID[folder.id] = folder
        }

        let rootFolder = LibraryFolder(name: "Library", parentID: nil)
        context.insert(rootFolder)
        let knownFolderIDs = Set(libraryFolderByID.keys).union([rootFolder.id])

        for folder in libraryFolderByID.values {
            guard folder.id != rootFolder.id else { continue }
            if let parentID = folder.parentID, !knownFolderIDs.contains(parentID) {
                folder.parentID = rootFolder.id
            }
        }

        for backupFile in payload.libraryFiles {
            let parentFolderID = knownFolderIDs.contains(backupFile.parentFolderID)
                ? backupFile.parentFolderID
                : rootFolder.id

            let libraryFile = LibraryFile(
                name: SecurityHelpers.sanitizeFilename(backupFile.name),
                pdfData: backupFile.pdfData,
                parentFolderID: parentFolderID
            )
            libraryFile.id = backupFile.id
            libraryFile.drawingData = backupFile.drawingData
            libraryFile.linkedSubject = backupFile.linkedSubjectID.flatMap { subjectByID[$0] }
            libraryFile.linkedUnit = backupFile.linkedUnitID.flatMap { unitByID[$0] }
            context.insert(libraryFile)
        }

        for backupEvent in payload.calendarEvents {
            let linkedClass = findClassByNameGrade(
                name: backupEvent.className,
                grade: backupEvent.classGrade,
                classByKey: classByKey
            )
            let event = CalendarEvent(
                title: backupEvent.title,
                date: backupEvent.date,
                startTime: backupEvent.startTime,
                endTime: backupEvent.endTime,
                details: SecurityHelpers.sanitizeNotes(backupEvent.details),
                isAllDay: backupEvent.isAllDay,
                schoolClass: linkedClass
            )
            context.insert(event)
        }

        for backupEntry in payload.classDiaryEntries {
            let linkedClass = findClassByNameGrade(
                name: backupEntry.className,
                grade: backupEntry.classGrade,
                classByKey: classByKey
            )
            let diaryEntry = ClassDiaryEntry(
                date: backupEntry.date,
                startTime: backupEntry.startTime,
                endTime: backupEntry.endTime,
                plan: SecurityHelpers.sanitizeNotes(backupEntry.plan),
                objectives: SecurityHelpers.sanitizeNotes(backupEntry.objectives),
                materials: SecurityHelpers.sanitizeNotes(backupEntry.materials),
                notes: SecurityHelpers.sanitizeNotes(backupEntry.notes),
                schoolClass: linkedClass,
                subject: backupEntry.subjectID.flatMap { subjectByID[$0] },
                unit: backupEntry.unitID.flatMap { unitByID[$0] }
            )
            context.insert(diaryEntry)
        }

        for backupLink in payload.usefulLinks {
            guard let sanitizedTitle = SecurityHelpers.sanitizeName(backupLink.title),
                  let sanitizedURL = sanitizeBackupURL(backupLink.url) else {
                continue
            }

            let usefulLink = UsefulLink(
                id: backupLink.id,
                title: sanitizedTitle,
                url: sanitizedURL,
                linkDescription: SecurityHelpers.sanitizeNotes(backupLink.description),
                sortOrder: SecurityHelpers.validateCount(backupLink.sortOrder, min: 0, max: 10000),
                createdAt: backupLink.createdAt,
                updatedAt: backupLink.updatedAt
            )
            context.insert(usefulLink)
        }

        try context.save()
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

    private static func resolveStudent(
        studentUUID: UUID?,
        studentName: String,
        classStudents: [Student],
        studentByUUID: [UUID: Student]
    ) -> Student? {
        if let uuid = studentUUID, let student = studentByUUID[uuid] {
            return student
        }

        if let sanitizedName = SecurityHelpers.sanitizeName(studentName) {
            return classStudents.first { $0.name == sanitizedName }
        }

        return nil
    }

    private static func deleteAll<T: PersistentModel>(_ model: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }

    private static func classKey(name: String, grade: String) -> String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(grade.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func findClassByNameGrade(
        name: String?,
        grade: String?,
        classByKey: [String: SchoolClass]
    ) -> SchoolClass? {
        guard let name, let grade else { return nil }
        return classByKey[classKey(name: name, grade: grade)]
    }

    private static func restoreAppSettings(_ settings: BackupAppSettings) {
        let defaults = UserDefaults.standard

        if let language = settings.appLanguage {
            defaults.set(language, forKey: "appLanguage")
        }

        let valuesByKey: [String: String] = [
            "helperRotation": settings.helperRotation,
            "guardianRotation": settings.guardianRotation,
            "lineLeaderRotation": settings.lineLeaderRotation,
            "messengerRotation": settings.messengerRotation,
            "customCategoriesData": settings.customCategoriesData,
            "customRotationData": settings.customRotationData
        ]

        for key in randomPickerSettingsKeys {
            defaults.set(valuesByKey[key] ?? "", forKey: key)
        }

        defaults.set(settings.dateFormat, forKey: AppPreferencesKeys.dateFormat)
        defaults.set(settings.timeFormat, forKey: AppPreferencesKeys.timeFormat)
        defaults.set(settings.defaultLandingSection, forKey: AppPreferencesKeys.defaultLandingSection)
        defaults.set(settings.timerCustomMinutes, forKey: TimerPreferenceKeys.customMinutes)
        defaults.set(settings.timerCustomSeconds, forKey: TimerPreferenceKeys.customSeconds)
        defaults.set(settings.timerCustomChecklistText, forKey: TimerPreferenceKeys.customChecklistText)
    }

    private static func sanitizeBackupURL(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("https://"),
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }

        return url.absoluteString
    }

    private static func sanitizedColorHex(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7,
              trimmed.first == "#",
              trimmed.dropFirst().allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return trimmed.uppercased()
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
