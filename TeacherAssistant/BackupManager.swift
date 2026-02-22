import SwiftData
import Foundation

/// Current backup schema version for compatibility checking
private let currentBackupSchemaVersion = 3

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
    var appSettings: BackupAppSettings?

    init(
        classes: [BackupClass],
        runningRecords: [BackupRunningRecord],
        rubricTemplates: [BackupRubricTemplate],
        developmentScores: [BackupDevelopmentScore],
        calendarEvents: [BackupCalendarEvent],
        classDiaryEntries: [BackupClassDiaryEntry],
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
        appSettings = try container.decodeIfPresent(BackupAppSettings.self, forKey: .appSettings)
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

        if context.hasChanges {
            try context.save()
        }

        let exportContext = ModelContext(context.container)
        
        let descriptor = FetchDescriptor<SchoolClass>()
        let classes = try exportContext.fetch(descriptor)
        let allStudents = try exportContext.fetch(FetchDescriptor<Student>())
        let allRunningRecords = try exportContext.fetch(FetchDescriptor<RunningRecord>())
        let allRubricTemplates = try exportContext.fetch(FetchDescriptor<RubricTemplate>())
        let allCalendarEvents = try exportContext.fetch(FetchDescriptor<CalendarEvent>())
        let allDiaryEntries = try exportContext.fetch(FetchDescriptor<ClassDiaryEntry>())

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
                        separationList: s.separationList
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

        // Some migrated databases contain stale DevelopmentScore->Student references.
        // Accessing those can hard-fatal SwiftData, so we skip exporting development
        // scores for now rather than crashing the entire backup flow.
        let backupDevelopmentScores: [BackupDevelopmentScore] = []

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
        
        SecureLogger.backupStep(3, "Built backup models")
        
        let defaults = UserDefaults.standard
        let backupAppSettings = BackupAppSettings(
            appLanguage: defaults.string(forKey: "appLanguage"),
            helperRotation: defaults.string(forKey: "helperRotation") ?? "",
            guardianRotation: defaults.string(forKey: "guardianRotation") ?? "",
            lineLeaderRotation: defaults.string(forKey: "lineLeaderRotation") ?? "",
            messengerRotation: defaults.string(forKey: "messengerRotation") ?? "",
            customCategoriesData: defaults.string(forKey: "customCategoriesData") ?? "",
            customRotationData: defaults.string(forKey: "customRotationData") ?? ""
        )

        // Create versioned backup
        let versionedBackup = VersionedBackupFile(
            classes: backupClasses,
            runningRecords: backupRunningRecords,
            rubricTemplates: backupRubricTemplates,
            developmentScores: backupDevelopmentScores,
            calendarEvents: backupCalendarEvents,
            classDiaryEntries: backupClassDiaryEntries,
            appSettings: backupAppSettings
        )
        
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
        var backupRunningRecords: [BackupRunningRecord] = []
        var backupRubricTemplates: [BackupRubricTemplate] = []
        var backupDevelopmentScores: [BackupDevelopmentScore] = []
        var backupCalendarEvents: [BackupCalendarEvent] = []
        var backupClassDiaryEntries: [BackupClassDiaryEntry] = []
        var backupAppSettings: BackupAppSettings?
        
        if let versionedBackup = try? decoder.decode(VersionedBackupFile.self, from: data) {
            // Validate schema version
            guard versionedBackup.schemaVersion <= currentBackupSchemaVersion else {
                throw BackupError.incompatibleVersion(versionedBackup.schemaVersion)
            }
            backupClasses = versionedBackup.classes
            backupRunningRecords = versionedBackup.runningRecords
            backupRubricTemplates = versionedBackup.rubricTemplates
            backupDevelopmentScores = versionedBackup.developmentScores
            backupCalendarEvents = versionedBackup.calendarEvents
            backupClassDiaryEntries = versionedBackup.classDiaryEntries
            backupAppSettings = versionedBackup.appSettings
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
        
        // Now safe to wipe existing database.
        // Use object-level deletes (instead of batch delete(model:)) to avoid
        // relationship-constraint violations during restore on some stores.
        try deleteAll(CalendarEvent.self, in: context)
        try deleteAll(ClassDiaryEntry.self, in: context)
        try deleteAll(DevelopmentScore.self, in: context)
        try deleteAll(RubricTemplate.self, in: context)
        try deleteAll(RunningRecord.self, in: context)
        try deleteAll(SchoolClass.self, in: context)
        try context.save()

        var studentByUUID: [UUID: Student] = [:]
        var subjectByID: [UUID: Subject] = [:]
        var unitByID: [UUID: Unit] = [:]
        var classByKey: [String: SchoolClass] = [:]

        for backupClass in backupClasses {
            // Sanitize inputs
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
            
            // Students
            for s in backupClass.students {
                guard seenStudentUUIDs.insert(s.uuid).inserted else {
                    SecureLogger.warning("Skipping duplicate student UUID in class backup payload")
                    continue
                }

                guard let sanitizedName = SecurityHelpers.sanitizeName(s.name) else {
                    SecureLogger.warning("Skipping student with invalid name")
                    continue
                }
                
                let student = Student(name: sanitizedName)
                student.uuid = s.uuid
                student.firstName = SecurityHelpers.sanitizeName(s.firstName ?? "")
                student.lastName = SecurityHelpers.sanitizeName(s.lastName ?? "")
                student.notes = SecurityHelpers.sanitizeNotes(s.notes)
                student.gender = s.gender
                student.isParticipatingWell = s.isParticipatingWell
                student.sortOrder = SecurityHelpers.validateCount(s.sortOrder, min: 0, max: 10000)
                student.needsHelp = s.needsHelp
                student.missingHomework = s.missingHomework
                student.separationList = s.separationList
                newClass.students.append(student)
                studentByUUID[student.uuid] = student
            }

            newClass.categories = backupClass.categories.map { BackupCategory in
                AssessmentCategory(title: BackupCategory.title)
            }
            
            // Subjects
            for sub in backupClass.subjects {
                guard let sanitizedSubjectName = SecurityHelpers.sanitizeName(sub.name) else {
                    SecureLogger.warning("Skipping subject with invalid name")
                    continue
                }
                
                let subject = Subject(name: sanitizedSubjectName)
                subject.id = sub.id
                subject.sortOrder = SecurityHelpers.validateCount(sub.sortOrder, min: 0, max: 10000)
                subject.schoolClass = newClass
                newClass.subjects.append(subject)
                subjectByID[subject.id] = subject
                
                for u in sub.units {
                    guard let sanitizedUnitName = SecurityHelpers.sanitizeName(u.name) else {
                        SecureLogger.warning("Skipping unit with invalid name")
                        continue
                    }
                    
                    let unit = Unit(name: sanitizedUnitName)
                    unit.id = u.id
                    unit.subject = subject
                    unit.sortOrder = SecurityHelpers.validateCount(u.sortOrder, min: 0, max: 10000)
                    subject.units.append(unit)
                    unitByID[unit.id] = unit
                    
                    for a in u.assessments {
                        guard let sanitizedTitle = SecurityHelpers.sanitizeName(a.title) else {
                            SecureLogger.warning("Skipping assessment with invalid title")
                            continue
                        }
                        
                        let assessment = Assessment(title: sanitizedTitle)
                        assessment.sortOrder = SecurityHelpers.validateCount(a.sortOrder, min: 0, max: 10000)
                        assessment.details = SecurityHelpers.sanitizeNotes(a.details)
                        assessment.date = a.date
                        assessment.maxScore = a.maxScore.isFinite
                            ? Swift.min(Swift.max(a.maxScore, 1), 1000)
                            : 10
                        assessment.unit = unit
                        unit.assessments.append(assessment)
                        
                        for r in a.results {
                            if let student = resolveStudent(
                                studentUUID: r.studentUUID,
                                studentName: r.studentName,
                                classStudents: newClass.students,
                                studentByUUID: studentByUUID
                            ) {
                                let result = StudentResult(
                                    student: student,
                                    score: SecurityHelpers.validateScore(
                                        r.score,
                                        min: 0,
                                        max: assessment.safeMaxScore
                                    ),
                                    notes: SecurityHelpers.sanitizeNotes(r.notes)
                                )
                                result.assessment = assessment
                                context.insert(result)
                            }
                        }
                    }
                }
            }

            // Attendance
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

        for backupRecord in backupRunningRecords {
            guard let student = studentByUUID[backupRecord.studentUUID] else { continue }
            let runningRecord = RunningRecord(
                date: backupRecord.date,
                textTitle: backupRecord.textTitle,
                totalWords: SecurityHelpers.validateCount(backupRecord.totalWords, min: 0, max: 1_000_000),
                errors: SecurityHelpers.validateCount(backupRecord.errors, min: 0, max: 1_000_000),
                selfCorrections: SecurityHelpers.validateCount(backupRecord.selfCorrections, min: 0, max: 1_000_000),
                notes: SecurityHelpers.sanitizeNotes(backupRecord.notes)
            )
            runningRecord.student = student
            context.insert(runningRecord)
        }

        var criterionByID: [UUID: RubricCriterion] = [:]
        for backupTemplate in backupRubricTemplates {
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

        for backupScore in backupDevelopmentScores {
            guard let student = studentByUUID[backupScore.studentUUID],
                  let criterion = criterionByID[backupScore.criterionID] else { continue }
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

        for backupEvent in backupCalendarEvents {
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

        for backupEntry in backupClassDiaryEntries {
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
        
        try context.save()

        if let settings = backupAppSettings {
            restoreAppSettings(settings)
        }
        
        // Record successful backup
        UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
        NotificationCenter.default.post(name: .backupRestoreDidComplete, object: nil)
        
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
