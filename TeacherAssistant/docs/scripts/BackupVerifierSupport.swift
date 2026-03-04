import Foundation

#if BACKUP_VERIFY

enum AppDateFormatPreference: String {
    case system
}

enum AppTimeFormatPreference: String {
    case system
}

enum AppSection: String {
    case dashboard = "Dashboard"
}

struct VersionedBackupFileHarness: Codable {
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
        schemaVersion: Int,
        createdAt: Date,
        appVersion: String,
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
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
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

func makeSampleVersionedBackup(schemaVersion: Int = 6) -> VersionedBackupFileHarness {
    let baseDate = Date(timeIntervalSince1970: 1_709_478_000)
    let studentUUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let subjectID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let unitID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let criterionID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let folderID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let fileID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    let student = BackupStudent(
        uuid: studentUUID,
        name: "Alex Smith",
        firstName: "Alex",
        lastName: "Smith",
        notes: "Strong reader",
        gender: "Non-binary",
        sortOrder: 1,
        isParticipatingWell: true,
        needsHelp: false,
        missingHomework: false,
        separationList: "",
        assessmentScores: [
            BackupAssessmentScore(value: 4),
            BackupAssessmentScore(value: 3),
        ]
    )

    let assessment = BackupAssessment(
        title: "Fractions Quiz",
        details: "Chapter 2",
        date: baseDate,
        maxScore: 10,
        sortOrder: 0,
        results: [
            BackupResult(
                studentUUID: studentUUID,
                studentName: "Alex Smith",
                score: 9,
                hasScore: true,
                notes: "Recovered well"
            )
        ]
    )

    let schoolClass = BackupClass(
        name: "Room 4",
        grade: "4",
        schoolYear: "2025-2026",
        sortOrder: 0,
        students: [student],
        categories: [
            BackupAssessmentCategory(title: "Tests"),
            BackupAssessmentCategory(title: "Homework"),
        ],
        attendanceSessions: [
            BackupAttendanceSession(
                date: baseDate,
                records: [
                    BackupAttendanceRecord(
                        studentUUID: studentUUID,
                        studentName: "Alex Smith",
                        statusRaw: "present",
                        notes: ""
                    )
                ]
            )
        ],
        subjects: [
            BackupSubject(
                id: subjectID,
                name: "Math",
                sortOrder: 0,
                units: [
                    BackupUnit(
                        id: unitID,
                        name: "Fractions",
                        sortOrder: 0,
                        assessments: [assessment]
                    )
                ]
            )
        ]
    )

    return VersionedBackupFileHarness(
        schemaVersion: schemaVersion,
        createdAt: baseDate,
        appVersion: "2.0.0",
        classes: [schoolClass],
        runningRecords: [
            BackupRunningRecord(
                studentUUID: studentUUID,
                date: baseDate,
                textTitle: "Stone Fox",
                bookLevel: "R",
                totalWords: 120,
                errors: 3,
                selfCorrections: 1,
                notes: "Good pace"
            )
        ],
        rubricTemplates: [
            BackupRubricTemplate(
                id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                name: "Writing Rubric",
                gradeLevel: "4",
                subject: "ELA",
                sortOrder: 0,
                categories: [
                    BackupRubricCategory(
                        id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                        name: "Ideas",
                        sortOrder: 0,
                        criteria: [
                            BackupRubricCriterion(
                                id: criterionID,
                                name: "Clarity",
                                details: "Writes clearly",
                                sortOrder: 0
                            )
                        ]
                    )
                ]
            )
        ],
        developmentScores: [
            BackupDevelopmentScore(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                studentUUID: studentUUID,
                criterionID: criterionID,
                rating: 4,
                date: baseDate,
                notes: "Consistent progress"
            )
        ],
        calendarEvents: [
            BackupCalendarEvent(
                title: "Parent Conference",
                date: baseDate,
                startTime: baseDate,
                endTime: Date(timeInterval: 1_800, since: baseDate),
                details: "Room 12",
                isAllDay: false,
                className: "Room 4",
                classGrade: "4"
            )
        ],
        classDiaryEntries: [
            BackupClassDiaryEntry(
                date: baseDate,
                startTime: baseDate,
                endTime: Date(timeInterval: 3_600, since: baseDate),
                plan: "Fractions small groups",
                objectives: "Compare fractions",
                materials: "Fraction strips",
                notes: "Group B needed extra help",
                className: "Room 4",
                classGrade: "4",
                subjectID: subjectID,
                unitID: unitID
            )
        ],
        libraryFolders: [
            BackupLibraryFolder(
                id: folderID,
                name: "Math PDFs",
                parentID: nil,
                colorHex: "#00AAFF"
            )
        ],
        libraryFiles: [
            BackupLibraryFile(
                id: fileID,
                name: "fractions-practice.pdf",
                pdfData: Data([0x25, 0x50, 0x44, 0x46]),
                parentFolderID: folderID,
                drawingData: Data([0x01, 0x02, 0x03]),
                linkedSubjectID: subjectID,
                linkedUnitID: unitID
            )
        ],
        usefulLinks: [
            BackupUsefulLink(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                title: "Fraction Games",
                url: "https://example.com/fractions",
                description: "Practice resource",
                sortOrder: 0,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        ],
        appSettings: BackupAppSettings(
            appLanguage: "en",
            helperRotation: "[]",
            guardianRotation: "[]",
            lineLeaderRotation: "[]",
            messengerRotation: "[]",
            customCategoriesData: "[]",
            customRotationData: "[]",
            dateFormat: AppDateFormatPreference.system.rawValue,
            timeFormat: AppTimeFormatPreference.system.rawValue,
            defaultLandingSection: AppSection.dashboard.rawValue,
            timerCustomMinutes: 7,
            timerCustomSeconds: 30,
            timerCustomChecklistText: "Pack up"
        )
    )
}

func summarize(_ backup: BackupFile) -> String {
    let classCount = backup.classes.count
    let studentCount = backup.classes.reduce(0) { $0 + $1.students.count }
    let subjectCount = backup.classes.reduce(0) { $0 + $1.subjects.count }
    let assessmentCount = backup.classes.reduce(0) { total, schoolClass in
        total + schoolClass.subjects.reduce(0) { subjectTotal, subject in
            subjectTotal + subject.units.reduce(0) { unitTotal, unit in
                unitTotal + unit.assessments.count
            }
        }
    }
    return "classes=\(classCount), students=\(studentCount), subjects=\(subjectCount), assessments=\(assessmentCount)"
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(
            domain: "BackupVerifier",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

#endif
