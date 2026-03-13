import Foundation
import SwiftData

struct DecodedBackupPayload {
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
}

enum BackupDecodeService {
    static func decodePayload(
        from data: Data,
        currentSchemaVersion: Int
    ) throws -> DecodedBackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let versionedBackup = try? decoder.decode(VersionedBackupFile.self, from: data) {
            guard versionedBackup.schemaVersion <= currentSchemaVersion else {
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
                liveObservationTemplates: versionedBackup.liveObservationTemplates,
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
            liveObservationTemplates: [],
            libraryFolders: [],
            libraryFiles: [],
            usefulLinks: [],
            appSettings: nil
        )
    }
}

enum BackupPayloadValidationService {
    static func validateTopLevelContents(_ classes: [BackupClass]) throws {
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

    static func validateRestorePayload(_ payload: DecodedBackupPayload) throws {
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

        try BackupPayloadApplyService.apply(
            payload,
            to: validationContext,
            clearExistingData: false
        )
    }
}

enum BackupPayloadApplyService {
    static func apply(
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
            try deleteAll(LiveObservationTemplate.self, in: context)
            try deleteAll(LiveObservationTemplateCriterion.self, in: context)
            try deleteAll(RubricTemplate.self, in: context)
            try deleteAll(RunningRecord.self, in: context)
            try deleteAll(UsefulLink.self, in: context)
            try deleteAll(SchoolClass.self, in: context)
        }

        var studentByUUID: [UUID: Student] = [:]
        var subjectByID: [UUID: Subject] = [:]
        var unitByID: [UUID: Unit] = [:]
        var assignmentByID: [UUID: Assignment] = [:]
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
                student.interventions = studentBackup.interventions.map { interventionBackup in
                    Intervention(
                        id: interventionBackup.id,
                        title: SecurityHelpers.sanitizeName(interventionBackup.title) ?? "Intervention".localized,
                        notes: SecurityHelpers.sanitizeNotes(interventionBackup.notes),
                        category: InterventionCategory(rawValue: interventionBackup.categoryRaw) ?? .other,
                        status: InterventionStatus(rawValue: interventionBackup.statusRaw) ?? .open,
                        createdAt: interventionBackup.createdAt,
                        updatedAt: interventionBackup.updatedAt,
                        followUpDate: interventionBackup.followUpDate,
                        student: student
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

            if let backupSeatingChart = backupClass.seatingChart {
                let seatingChart = SeatingChart(
                    id: backupSeatingChart.id,
                    title: SecurityHelpers.sanitizeName(backupSeatingChart.title) ?? "Main Layout",
                    rows: SecurityHelpers.validateCount(backupSeatingChart.rows, min: 1, max: 20),
                    columns: SecurityHelpers.validateCount(backupSeatingChart.columns, min: 1, max: 20),
                    createdAt: backupSeatingChart.createdAt,
                    updatedAt: backupSeatingChart.updatedAt
                )
                seatingChart.schoolClass = newClass
                newClass.seatingChart = seatingChart
                context.insert(seatingChart)

                var seenStudentUUIDs: Set<UUID> = []
                var seenCoordinates: Set<String> = []

                for placementBackup in backupSeatingChart.placements {
                    guard placementBackup.row >= 0,
                          placementBackup.column >= 0,
                          placementBackup.row < seatingChart.rows,
                          placementBackup.column < seatingChart.columns else {
                        continue
                    }

                    guard let student = resolveStudent(
                        studentUUID: placementBackup.studentUUID,
                        studentName: placementBackup.studentName,
                        classStudents: newClass.students,
                        studentByUUID: studentByUUID
                    ) else {
                        continue
                    }

                    guard seenStudentUUIDs.insert(student.uuid).inserted else {
                        continue
                    }

                    let coordinateKey = "\(placementBackup.row)-\(placementBackup.column)"
                    guard seenCoordinates.insert(coordinateKey).inserted else {
                        continue
                    }

                    let placement = SeatingPlacement(
                        id: placementBackup.id,
                        row: placementBackup.row,
                        column: placementBackup.column,
                        studentUUID: student.uuid,
                        studentNameSnapshot: student.name,
                        chart: seatingChart
                    )
                    seatingChart.placements.append(placement)
                    context.insert(placement)
                }
            }

            for eventBackup in backupClass.participationEvents {
                guard let student = resolveStudent(
                    studentUUID: eventBackup.studentUUID,
                    studentName: eventBackup.studentName,
                    classStudents: newClass.students,
                    studentByUUID: studentByUUID
                ) else {
                    continue
                }

                let event = ParticipationEvent(
                    id: eventBackup.id,
                    createdAt: eventBackup.createdAt,
                    kind: ParticipationEventKind(rawValue: eventBackup.kindRaw) ?? .contribution,
                    note: SecurityHelpers.sanitizeNotes(eventBackup.note),
                    studentUUID: student.uuid,
                    studentNameSnapshot: student.name,
                    student: student,
                    schoolClass: newClass
                )
                newClass.participationEvents.append(event)
                student.participationEvents.append(event)
                context.insert(event)
            }

            for eventBackup in backupClass.behaviorSupportEvents {
                guard let student = resolveStudent(
                    studentUUID: eventBackup.studentUUID,
                    studentName: eventBackup.studentName,
                    classStudents: newClass.students,
                    studentByUUID: studentByUUID
                ) else {
                    continue
                }

                let event = BehaviorSupportEvent(
                    id: eventBackup.id,
                    createdAt: eventBackup.createdAt,
                    kind: BehaviorSupportEventKind(rawValue: eventBackup.kindRaw) ?? .supportCheckIn,
                    note: SecurityHelpers.sanitizeNotes(eventBackup.note),
                    studentUUID: student.uuid,
                    studentNameSnapshot: student.name,
                    student: student,
                    schoolClass: newClass
                )
                newClass.behaviorSupportEvents.append(event)
                student.behaviorSupportEvents.append(event)
                context.insert(event)
            }

            for observationBackup in backupClass.liveObservations {
                guard let student = resolveStudent(
                    studentUUID: observationBackup.studentUUID,
                    studentName: observationBackup.studentName,
                    classStudents: newClass.students,
                    studentByUUID: studentByUUID
                ) else {
                    continue
                }

                let observation = LiveObservation(
                    id: observationBackup.id,
                    createdAt: observationBackup.createdAt,
                    sessionDate: observationBackup.sessionDate,
                    source: LiveObservationSource(rawValue: observationBackup.sourceRaw) ?? .standaloneTool,
                    understandingLevel: LiveObservationLevel(rawValue: observationBackup.understandingLevelRaw) ?? .developing,
                    engagementLevel: LiveObservationLevel(rawValue: observationBackup.engagementLevelRaw) ?? .developing,
                    supportLevel: LiveObservationLevel(rawValue: observationBackup.supportLevelRaw) ?? .developing,
                    note: SecurityHelpers.sanitizeNotes(observationBackup.note),
                    studentUUID: student.uuid,
                    studentNameSnapshot: student.name,
                    student: student,
                    schoolClass: newClass
                )
                newClass.liveObservations.append(observation)
                student.liveObservations.append(observation)

                observation.checklistResponses = observationBackup.checklistResponses.map { responseBackup in
                    LiveObservationChecklistResponse(
                        id: responseBackup.id,
                        criterionTitle: SecurityHelpers.sanitizeName(responseBackup.criterionTitle) ?? "Criterion".localized,
                        level: LiveObservationLevel(rawValue: responseBackup.levelRaw) ?? .developing,
                        sortOrder: SecurityHelpers.validateCount(responseBackup.sortOrder, min: 0, max: 10000),
                        observation: observation
                    )
                }
                context.insert(observation)
                for response in observation.checklistResponses {
                    context.insert(response)
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
                                    hasScore: resultBackup.hasScore ?? (resultBackup.score > 0),
                                    status: AssessmentResultStatus(rawValue: resultBackup.statusRaw ?? "")
                                        ?? ((resultBackup.hasScore ?? (resultBackup.score > 0)) ? .scored : .ungraded)
                                )
                                result.assessment = assessment
                                context.insert(result)
                            }
                        }
                    }

                    for assignmentBackup in unitBackup.assignments {
                        guard let sanitizedTitle = SecurityHelpers.sanitizeName(assignmentBackup.title) else {
                            SecureLogger.warning("Skipping assignment with invalid title")
                            continue
                        }

                        let assignment = Assignment(id: assignmentBackup.id, title: sanitizedTitle)
                        assignment.details = SecurityHelpers.sanitizeNotes(assignmentBackup.details)
                        assignment.dueDate = assignmentBackup.dueDate
                        assignment.createdAt = assignmentBackup.createdAt
                        assignment.sortOrder = SecurityHelpers.validateCount(
                            assignmentBackup.sortOrder,
                            min: 0,
                            max: 10000
                        )
                        assignment.unit = unit
                        unit.assignments.append(assignment)
                        assignmentByID[assignment.id] = assignment

                        for entryBackup in assignmentBackup.entries {
                            guard let student = resolveStudent(
                                studentUUID: entryBackup.studentUUID,
                                studentName: entryBackup.studentName,
                                classStudents: newClass.students,
                                studentByUUID: studentByUUID
                            ) else {
                                continue
                            }

                            let entry = StudentAssignment(
                                student: student,
                                assignment: assignment,
                                status: AssignmentEntryStatus(rawValue: entryBackup.statusRaw) ?? .pending,
                                submittedAt: entryBackup.submittedAt,
                                notes: SecurityHelpers.sanitizeNotes(entryBackup.notes)
                            )
                            assignment.entries.append(entry)
                            student.assignmentEntries.append(entry)
                            context.insert(entry)
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

        for backupTemplate in payload.liveObservationTemplates {
            guard let sanitizedTitle = SecurityHelpers.sanitizeName(backupTemplate.title) else {
                continue
            }

            let template = LiveObservationTemplate(
                id: backupTemplate.id,
                title: sanitizedTitle,
                sortOrder: SecurityHelpers.validateCount(backupTemplate.sortOrder, min: 0, max: 10000),
                createdAt: backupTemplate.createdAt,
                updatedAt: backupTemplate.updatedAt
            )
            template.criteria = backupTemplate.criteria.map { backupCriterion in
                LiveObservationTemplateCriterion(
                    id: backupCriterion.id,
                    title: SecurityHelpers.sanitizeName(backupCriterion.title) ?? "Criterion".localized,
                    sortOrder: SecurityHelpers.validateCount(backupCriterion.sortOrder, min: 0, max: 10000),
                    template: template
                )
            }
            context.insert(template)
            for criterion in template.criteria {
                context.insert(criterion)
            }
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
                schoolClass: linkedClass,
                assignment: backupEvent.assignmentID.flatMap { assignmentByID[$0] }
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
                unit: backupEntry.unitID.flatMap { unitByID[$0] },
                assignment: backupEntry.assignmentID.flatMap { assignmentByID[$0] }
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
