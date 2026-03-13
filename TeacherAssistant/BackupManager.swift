import SwiftData
import Foundation

/// Current backup schema version for compatibility checking
private let currentBackupSchemaVersion = 13

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
    var liveObservationTemplates: [BackupLiveObservationTemplate]
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
        liveObservationTemplates: [BackupLiveObservationTemplate],
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
        self.liveObservationTemplates = liveObservationTemplates
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
        case liveObservationTemplates
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
        liveObservationTemplates = try container.decodeIfPresent([BackupLiveObservationTemplate].self, forKey: .liveObservationTemplates) ?? []
        libraryFolders = try container.decodeIfPresent([BackupLibraryFolder].self, forKey: .libraryFolders) ?? []
        libraryFiles = try container.decodeIfPresent([BackupLibraryFile].self, forKey: .libraryFiles) ?? []
        usefulLinks = try container.decodeIfPresent([BackupUsefulLink].self, forKey: .usefulLinks) ?? []
        appSettings = try container.decodeIfPresent(BackupAppSettings.self, forKey: .appSettings)
    }
}

@MainActor
final class BackupManager {
    
    /// Tracks if an operation is in progress to prevent concurrent operations
    private static var isOperationInProgress = false
    private static var applicationSupportDirectoryOverride: URL?
    
    /// Minimum interval between operations (5 seconds)
    private static let minimumOperationInterval: TimeInterval = 5.0
    
    /// Last operation timestamp
    private static var lastOperationTime: Date?
    
    // MARK: - Export
    
    @MainActor
    static func exportBackup(context: ModelContext) throws -> URL {
        Task { await PerformanceMonitor.shared.incrementCounter(.backupExport) }
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
        let allLiveObservationTemplates = try exportContext.fetch(FetchDescriptor<LiveObservationTemplate>())
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
                        },
                        interventions: s.interventions.map { intervention in
                            BackupInterventionItem(
                                id: intervention.id,
                                title: intervention.title,
                                notes: SecurityHelpers.sanitizeNotes(intervention.notes),
                                categoryRaw: intervention.category.rawValue,
                                statusRaw: intervention.status.rawValue,
                                createdAt: intervention.createdAt,
                                updatedAt: intervention.updatedAt,
                                followUpDate: intervention.followUpDate
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

            let backupSeatingChart = schoolClass.seatingChart.map { chart in
                BackupSeatingChart(
                    id: chart.id,
                    title: chart.title,
                    rows: SecurityHelpers.validateCount(chart.rows, min: 1, max: 20),
                    columns: SecurityHelpers.validateCount(chart.columns, min: 1, max: 20),
                    createdAt: chart.createdAt,
                    updatedAt: chart.updatedAt,
                    placements: chart.placements
                        .sorted {
                            if $0.row != $1.row {
                                return $0.row < $1.row
                            }
                            return $0.column < $1.column
                        }
                        .map { placement in
                            BackupSeatPlacement(
                                id: placement.id,
                                row: SecurityHelpers.validateCount(placement.row, min: 0, max: 100),
                                column: SecurityHelpers.validateCount(placement.column, min: 0, max: 100),
                                studentUUID: placement.studentUUID,
                                studentName: placement.studentNameSnapshot
                            )
                        }
                )
            }

            let backupParticipationEvents = schoolClass.participationEvents
                .sorted { $0.createdAt > $1.createdAt }
                .map { event in
                    BackupParticipationEvent(
                        id: event.id,
                        createdAt: event.createdAt,
                        kindRaw: event.kind.rawValue,
                        note: SecurityHelpers.sanitizeNotes(event.note),
                        studentUUID: event.studentUUID,
                        studentName: event.studentNameSnapshot
                    )
                }

            let backupBehaviorSupportEvents = schoolClass.behaviorSupportEvents
                .sorted { $0.createdAt > $1.createdAt }
                .map { event in
                    BackupBehaviorSupportEvent(
                        id: event.id,
                        createdAt: event.createdAt,
                        kindRaw: event.kind.rawValue,
                        note: SecurityHelpers.sanitizeNotes(event.note),
                        studentUUID: event.studentUUID,
                        studentName: event.studentNameSnapshot
                    )
                }

            let backupLiveObservations = schoolClass.liveObservations
                .sorted { $0.createdAt > $1.createdAt }
                .map { observation in
                    BackupLiveObservation(
                        id: observation.id,
                        createdAt: observation.createdAt,
                        sessionDate: observation.sessionDate,
                        sourceRaw: observation.source.rawValue,
                        understandingLevelRaw: observation.understandingLevel.rawValue,
                        engagementLevelRaw: observation.engagementLevel.rawValue,
                        supportLevelRaw: observation.supportLevel.rawValue,
                        note: SecurityHelpers.sanitizeNotes(observation.note),
                        studentUUID: observation.studentUUID,
                        studentName: observation.studentNameSnapshot,
                        checklistResponses: observation.checklistResponses
                            .sorted { $0.sortOrder < $1.sortOrder }
                            .map { response in
                                BackupLiveObservationChecklistResponse(
                                    id: response.id,
                                    criterionTitle: response.criterionTitle,
                                    levelRaw: response.level.rawValue,
                                    sortOrder: SecurityHelpers.validateCount(response.sortOrder, min: 0, max: 10000)
                                )
                            }
                    )
                }
            
            var backupSubjects: [BackupSubject] = []
            
            for subject in schoolClass.subjects {
                var backupUnits: [BackupUnit] = []
                
                for unit in subject.units {
                    var backupAssessments: [BackupAssessment] = []
                    var backupAssignments: [BackupAssignmentItem] = []
                    
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
                                    statusRaw: result.status.rawValue,
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

                    for assignment in unit.assignments {
                        let backupEntries = assignment.entries.map { entry in
                            BackupStudentAssignmentEntry(
                                studentUUID: entry.student?.uuid,
                                studentName: entry.student?.name ?? "",
                                statusRaw: entry.status.rawValue,
                                submittedAt: entry.submittedAt,
                                notes: SecurityHelpers.sanitizeNotes(entry.notes)
                            )
                        }

                        backupAssignments.append(
                            BackupAssignmentItem(
                                id: assignment.id,
                                title: assignment.title,
                                details: SecurityHelpers.sanitizeNotes(assignment.details),
                                dueDate: assignment.dueDate,
                                createdAt: assignment.createdAt,
                                sortOrder: SecurityHelpers.validateCount(assignment.sortOrder, min: 0, max: 10000),
                                entries: backupEntries
                            )
                        )
                    }
                    
                    backupUnits.append(
                        BackupUnit(
                            id: unit.id,
                            name: unit.name,
                            sortOrder: SecurityHelpers.validateCount(unit.sortOrder, min: 0, max: 10000),
                            assessments: backupAssessments,
                            assignments: backupAssignments
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
                    seatingChart: backupSeatingChart,
                    participationEvents: backupParticipationEvents,
                    behaviorSupportEvents: backupBehaviorSupportEvents,
                    liveObservations: backupLiveObservations,
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
                classGrade: event.schoolClass?.grade,
                assignmentID: event.assignment?.id
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
                unitID: entry.unit?.id,
                assignmentID: entry.assignment?.id
            )
        }

        let backupLiveObservationTemplates = allLiveObservationTemplates
            .sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.createdAt < $1.createdAt
            }
            .map { template in
                BackupLiveObservationTemplate(
                    id: template.id,
                    title: template.title,
                    sortOrder: SecurityHelpers.validateCount(template.sortOrder, min: 0, max: 10000),
                    createdAt: template.createdAt,
                    updatedAt: template.updatedAt,
                    criteria: template.criteria
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { criterion in
                            BackupLiveObservationTemplateCriterion(
                                id: criterion.id,
                                title: criterion.title,
                                sortOrder: SecurityHelpers.validateCount(criterion.sortOrder, min: 0, max: 10000)
                            )
                        }
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
            motionProfile: defaults.string(forKey: AppPreferencesKeys.motionProfile) ?? AppMotionProfile.full.rawValue,
            attentionRemindersEnabled: defaults.object(forKey: AppPreferencesKeys.attentionRemindersEnabled) as? Bool ?? true,
            attentionNotificationsEnabled: defaults.object(forKey: AppPreferencesKeys.attentionNotificationsEnabled) as? Bool ?? false,
            attentionNotificationHour: defaults.object(forKey: AppPreferencesKeys.attentionNotificationHour) as? Int ?? 7,
            attentionNotificationMinute: defaults.object(forKey: AppPreferencesKeys.attentionNotificationMinute) as? Int ?? 30,
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
            liveObservationTemplates: backupLiveObservationTemplates,
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

        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            guard shouldRetryWriteWithoutFileProtection(error) else {
                throw error
            }
            SecureLogger.warning("Retrying backup write without complete file protection")
            try data.write(to: url, options: [.atomic])
        }

        if scheduleCleanup {
            self.scheduleTemporaryFileCleanup(url: url, delay: 300)
        }

        return url
    }

    private static func shouldRetryWriteWithoutFileProtection(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError
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
        Task { await PerformanceMonitor.shared.incrementCounter(.backupImport) }
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
                    let payload = try BackupDecodeService.decodePayload(
                        from: data,
                        currentSchemaVersion: currentBackupSchemaVersion
                    )
                    SecureLogger.backupStep(1, "Decoded backup with \(payload.classes.count) classes")
                    try BackupPayloadValidationService.validateTopLevelContents(payload.classes)
                    return payload
                },
                validatePayload: { payload in
                    try BackupPayloadValidationService.validateRestorePayload(payload)
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
                    try BackupPayloadApplyService.apply(
                        payload,
                        to: restoreContext,
                        clearExistingData: true
                    )
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

    static func setApplicationSupportDirectoryOverrideForTests(_ url: URL?) {
        applicationSupportDirectoryOverride = url
    }

    static func applicationSupportSubdirectory(
        named name: String,
        createIfMissing: Bool
    ) throws -> URL {
        let bundleDirectory: URL
        if let overrideDirectory = applicationSupportDirectoryOverride {
            bundleDirectory = overrideDirectory
        } else {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            bundleDirectory = applicationSupportDirectory.appendingPathComponent(
                Bundle.main.bundleIdentifier ?? "TeacherAssistant",
                isDirectory: true
            )
        }
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
        defaults.set(settings.motionProfile, forKey: AppPreferencesKeys.motionProfile)
        defaults.set(settings.attentionRemindersEnabled, forKey: AppPreferencesKeys.attentionRemindersEnabled)
        defaults.set(settings.attentionNotificationsEnabled, forKey: AppPreferencesKeys.attentionNotificationsEnabled)
        defaults.set(settings.attentionNotificationHour, forKey: AppPreferencesKeys.attentionNotificationHour)
        defaults.set(settings.attentionNotificationMinute, forKey: AppPreferencesKeys.attentionNotificationMinute)
        defaults.set(settings.timerCustomMinutes, forKey: TimerPreferenceKeys.customMinutes)
        defaults.set(settings.timerCustomSeconds, forKey: TimerPreferenceKeys.customSeconds)
        defaults.set(settings.timerCustomChecklistText, forKey: TimerPreferenceKeys.customChecklistText)
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
