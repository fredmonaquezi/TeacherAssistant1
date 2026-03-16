import Foundation

struct BackupFile: Codable {
    var classes: [BackupClass]
}

struct BackupUsefulLink: Codable {
    var id: UUID
    var title: String
    var url: String
    var description: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        description: String = "",
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.description = description
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct BackupClass: Codable {
    var name: String
    var grade: String
    var schoolYear: String?
    var sortOrder: Int
    var students: [BackupStudent]
    var categories: [BackupAssessmentCategory]
    var attendanceSessions: [BackupAttendanceSession]
    var seatingChart: BackupSeatingChart?
    var participationEvents: [BackupParticipationEvent]
    var behaviorSupportEvents: [BackupBehaviorSupportEvent]
    var liveObservations: [BackupLiveObservation]
    var subjects: [BackupSubject]

    init(
        name: String,
        grade: String,
        schoolYear: String? = nil,
        sortOrder: Int = 0,
        students: [BackupStudent],
        categories: [BackupAssessmentCategory] = [],
        attendanceSessions: [BackupAttendanceSession] = [],
        seatingChart: BackupSeatingChart? = nil,
        participationEvents: [BackupParticipationEvent] = [],
        behaviorSupportEvents: [BackupBehaviorSupportEvent] = [],
        liveObservations: [BackupLiveObservation] = [],
        subjects: [BackupSubject]
    ) {
        self.name = name
        self.grade = grade
        self.schoolYear = schoolYear
        self.sortOrder = sortOrder
        self.students = students
        self.categories = categories
        self.attendanceSessions = attendanceSessions
        self.seatingChart = seatingChart
        self.participationEvents = participationEvents
        self.behaviorSupportEvents = behaviorSupportEvents
        self.liveObservations = liveObservations
        self.subjects = subjects
    }

    enum CodingKeys: String, CodingKey {
        case name
        case grade
        case schoolYear
        case sortOrder
        case students
        case categories
        case attendanceSessions
        case seatingChart
        case participationEvents
        case behaviorSupportEvents
        case liveObservations
        case subjects
    }

    enum LegacyCodingKeys: String, CodingKey {
        case schoolYearSnake = "school_year"
        case sortOrderSnake = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        grade = try container.decode(String.self, forKey: .grade)
        schoolYear =
            try container.decodeIfPresent(String.self, forKey: .schoolYear) ??
            legacyContainer.decodeIfPresent(String.self, forKey: .schoolYearSnake)
        sortOrder =
            try container.decodeIfPresent(Int.self, forKey: .sortOrder) ??
            legacyContainer.decodeIfPresent(Int.self, forKey: .sortOrderSnake) ??
            0
        students = try container.decodeIfPresent([BackupStudent].self, forKey: .students) ?? []
        categories = try container.decodeIfPresent([BackupAssessmentCategory].self, forKey: .categories) ?? []
        attendanceSessions = try container.decodeIfPresent([BackupAttendanceSession].self, forKey: .attendanceSessions) ?? []
        seatingChart = try container.decodeIfPresent(BackupSeatingChart.self, forKey: .seatingChart)
        participationEvents = try container.decodeIfPresent([BackupParticipationEvent].self, forKey: .participationEvents) ?? []
        behaviorSupportEvents = try container.decodeIfPresent([BackupBehaviorSupportEvent].self, forKey: .behaviorSupportEvents) ?? []
        liveObservations = try container.decodeIfPresent([BackupLiveObservation].self, forKey: .liveObservations) ?? []
        subjects = try container.decodeIfPresent([BackupSubject].self, forKey: .subjects) ?? []
    }
}

struct BackupSeatingChart: Codable {
    var id: UUID
    var title: String
    var rows: Int
    var columns: Int
    var layoutStyleRaw: String?
    var centerGroupSize: Int?
    var createdAt: Date
    var updatedAt: Date
    var placements: [BackupSeatPlacement]
}

struct BackupSeatPlacement: Codable {
    var id: UUID
    var row: Int
    var column: Int
    var studentUUID: UUID?
    var studentName: String
}

struct BackupParticipationEvent: Codable {
    var id: UUID
    var createdAt: Date
    var kindRaw: String
    var note: String
    var studentUUID: UUID?
    var studentName: String
}

struct BackupBehaviorSupportEvent: Codable {
    var id: UUID
    var createdAt: Date
    var kindRaw: String
    var note: String
    var studentUUID: UUID?
    var studentName: String
}

struct BackupLiveObservation: Codable {
    var id: UUID
    var createdAt: Date
    var sessionDate: Date
    var sourceRaw: String
    var understandingLevelRaw: String
    var engagementLevelRaw: String
    var supportLevelRaw: String
    var note: String
    var studentUUID: UUID?
    var studentName: String
    var checklistResponses: [BackupLiveObservationChecklistResponse]
}

struct BackupLiveObservationChecklistResponse: Codable {
    var id: UUID
    var criterionTitle: String
    var levelRaw: String
    var sortOrder: Int
}

struct BackupStudent: Codable {
    var uuid: UUID
    var name: String
    var firstName: String?
    var lastName: String?
    var notes: String
    var gender: String
    var sortOrder: Int
    var isParticipatingWell: Bool
    var needsHelp: Bool
    var missingHomework: Bool
    var separationList: String
    var assessmentScores: [BackupAssessmentScore]
    var interventions: [BackupInterventionItem]

    init(
        uuid: UUID = UUID(),
        name: String,
        firstName: String? = nil,
        lastName: String? = nil,
        notes: String = "",
        gender: String = "Prefer not to say",
        sortOrder: Int,
        isParticipatingWell: Bool,
        needsHelp: Bool,
        missingHomework: Bool,
        separationList: String = "",
        assessmentScores: [BackupAssessmentScore] = [],
        interventions: [BackupInterventionItem] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.notes = notes
        self.gender = gender
        self.sortOrder = sortOrder
        self.isParticipatingWell = isParticipatingWell
        self.needsHelp = needsHelp
        self.missingHomework = missingHomework
        self.separationList = separationList
        self.assessmentScores = assessmentScores
        self.interventions = interventions
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case firstName
        case lastName
        case notes
        case gender
        case sortOrder
        case isParticipatingWell
        case needsHelp
        case missingHomework
        case separationList
        case assessmentScores
        case interventions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? "Prefer not to say"
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isParticipatingWell = try container.decodeIfPresent(Bool.self, forKey: .isParticipatingWell) ?? false
        needsHelp = try container.decodeIfPresent(Bool.self, forKey: .needsHelp) ?? false
        missingHomework = try container.decodeIfPresent(Bool.self, forKey: .missingHomework) ?? false
        separationList = try container.decodeIfPresent(String.self, forKey: .separationList) ?? ""
        assessmentScores = try container.decodeIfPresent([BackupAssessmentScore].self, forKey: .assessmentScores) ?? []
        interventions = try container.decodeIfPresent([BackupInterventionItem].self, forKey: .interventions) ?? []
    }
}

struct BackupInterventionItem: Codable {
    var id: UUID
    var title: String
    var notes: String
    var categoryRaw: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var followUpDate: Date?
}

struct BackupAssessmentScore: Codable {
    var value: Int
}

struct BackupSubject: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var units: [BackupUnit]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortOrder
        case units
    }

    init(id: UUID = UUID(), name: String, sortOrder: Int, units: [BackupUnit]) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.units = units
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        units = try container.decodeIfPresent([BackupUnit].self, forKey: .units) ?? []
    }
}

struct BackupUnit: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var assessments: [BackupAssessment]
    var assignments: [BackupAssignmentItem]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortOrder
        case assessments
        case assignments
    }

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        assessments: [BackupAssessment],
        assignments: [BackupAssignmentItem] = []
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.assessments = assessments
        self.assignments = assignments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        assessments = try container.decodeIfPresent([BackupAssessment].self, forKey: .assessments) ?? []
        assignments = try container.decodeIfPresent([BackupAssignmentItem].self, forKey: .assignments) ?? []
    }
}

struct BackupAssignmentItem: Codable {
    var id: UUID
    var title: String
    var details: String
    var dueDate: Date
    var createdAt: Date
    var sortOrder: Int
    var entries: [BackupStudentAssignmentEntry]

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        dueDate: Date = Date(),
        createdAt: Date = Date(),
        sortOrder: Int,
        entries: [BackupStudentAssignmentEntry]
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case details
        case dueDate
        case createdAt
        case sortOrder
        case entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? dueDate
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        entries = try container.decodeIfPresent([BackupStudentAssignmentEntry].self, forKey: .entries) ?? []
    }
}

struct BackupStudentAssignmentEntry: Codable {
    var studentUUID: UUID?
    var studentName: String
    var statusRaw: String
    var submittedAt: Date?
    var notes: String

    init(
        studentUUID: UUID? = nil,
        studentName: String,
        statusRaw: String,
        submittedAt: Date? = nil,
        notes: String = ""
    ) {
        self.studentUUID = studentUUID
        self.studentName = studentName
        self.statusRaw = statusRaw
        self.submittedAt = submittedAt
        self.notes = notes
    }
}

struct BackupAssessment: Codable {
    var title: String
    var details: String
    var date: Date
    var maxScore: Double
    var sortOrder: Int
    var results: [BackupResult]

    init(
        title: String,
        details: String,
        date: Date = Date(),
        maxScore: Double = 10,
        sortOrder: Int,
        results: [BackupResult]
    ) {
        self.title = title
        self.details = details
        self.date = date
        self.maxScore = maxScore
        self.sortOrder = sortOrder
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case title
        case details
        case date
        case maxScore
        case sortOrder
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        maxScore = try container.decodeIfPresent(Double.self, forKey: .maxScore) ?? 10
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        results = try container.decodeIfPresent([BackupResult].self, forKey: .results) ?? []
    }
}

struct BackupResult: Codable {
    var studentUUID: UUID?
    var studentName: String
    var score: Double
    var hasScore: Bool?
    var statusRaw: String?
    var notes: String

    init(
        studentUUID: UUID? = nil,
        studentName: String,
        score: Double,
        hasScore: Bool? = nil,
        statusRaw: String? = nil,
        notes: String
    ) {
        self.studentUUID = studentUUID
        self.studentName = studentName
        self.score = score
        self.hasScore = hasScore
        self.statusRaw = statusRaw
        self.notes = notes
    }
}

struct BackupAssessmentCategory: Codable {
    var title: String
}

struct BackupAttendanceSession: Codable {
    var date: Date
    var records: [BackupAttendanceRecord]
}

struct BackupAttendanceRecord: Codable {
    var studentUUID: UUID?
    var studentName: String
    var statusRaw: String
    var notes: String
}

struct BackupRunningRecord: Codable {
    var studentUUID: UUID
    var date: Date
    var textTitle: String
    var bookLevel: String?
    var totalWords: Int
    var errors: Int
    var selfCorrections: Int
    var notes: String
}

struct BackupRubricTemplate: Codable {
    var id: UUID
    var name: String
    var gradeLevel: String
    var subject: String
    var sortOrder: Int
    var categories: [BackupRubricCategory]
}

struct BackupRubricCategory: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var criteria: [BackupRubricCriterion]
}

struct BackupRubricCriterion: Codable {
    var id: UUID
    var name: String
    var details: String
    var sortOrder: Int
}

struct BackupDevelopmentScore: Codable {
    var id: UUID
    var studentUUID: UUID
    var criterionID: UUID
    var rating: Int
    var date: Date
    var notes: String
}

struct BackupCalendarEvent: Codable {
    var title: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var details: String
    var isAllDay: Bool
    var className: String?
    var classGrade: String?
    var assignmentID: UUID?
}

struct BackupClassDiaryEntry: Codable {
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var plan: String
    var objectives: String
    var materials: String
    var notes: String
    var className: String?
    var classGrade: String?
    var subjectID: UUID?
    var unitID: UUID?
    var assignmentID: UUID?
}

struct BackupLiveObservationTemplate: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var criteria: [BackupLiveObservationTemplateCriterion]
}

struct BackupLiveObservationTemplateCriterion: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
}

struct BackupLibraryFolder: Codable {
    var id: UUID
    var name: String
    var parentID: UUID?
    var colorHex: String?
}

struct BackupLibraryFile: Codable {
    var id: UUID
    var name: String
    var pdfData: Data
    var parentFolderID: UUID
    var drawingData: Data?
    var linkedSubjectID: UUID?
    var linkedUnitID: UUID?
}

struct BackupAppSettings: Codable {
    var appLanguage: String?
    var helperRotation: String
    var guardianRotation: String
    var lineLeaderRotation: String
    var messengerRotation: String
    var customCategoriesData: String
    var customRotationData: String
    var dateFormat: String
    var timeFormat: String
    var defaultLandingSection: String
    var motionProfile: String
    var attentionRemindersEnabled: Bool
    var attentionNotificationsEnabled: Bool
    var attentionNotificationHour: Int
    var attentionNotificationMinute: Int
    var timerCustomMinutes: Int
    var timerCustomSeconds: Int
    var timerCustomChecklistText: String

    init(
        appLanguage: String?,
        helperRotation: String,
        guardianRotation: String,
        lineLeaderRotation: String,
        messengerRotation: String,
        customCategoriesData: String,
        customRotationData: String,
        dateFormat: String,
        timeFormat: String,
        defaultLandingSection: String,
        motionProfile: String,
        attentionRemindersEnabled: Bool,
        attentionNotificationsEnabled: Bool,
        attentionNotificationHour: Int,
        attentionNotificationMinute: Int,
        timerCustomMinutes: Int,
        timerCustomSeconds: Int,
        timerCustomChecklistText: String
    ) {
        self.appLanguage = appLanguage
        self.helperRotation = helperRotation
        self.guardianRotation = guardianRotation
        self.lineLeaderRotation = lineLeaderRotation
        self.messengerRotation = messengerRotation
        self.customCategoriesData = customCategoriesData
        self.customRotationData = customRotationData
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
        self.defaultLandingSection = defaultLandingSection
        self.motionProfile = motionProfile
        self.attentionRemindersEnabled = attentionRemindersEnabled
        self.attentionNotificationsEnabled = attentionNotificationsEnabled
        self.attentionNotificationHour = attentionNotificationHour
        self.attentionNotificationMinute = attentionNotificationMinute
        self.timerCustomMinutes = timerCustomMinutes
        self.timerCustomSeconds = timerCustomSeconds
        self.timerCustomChecklistText = timerCustomChecklistText
    }

    enum CodingKeys: String, CodingKey {
        case appLanguage
        case helperRotation
        case guardianRotation
        case lineLeaderRotation
        case messengerRotation
        case customCategoriesData
        case customRotationData
        case dateFormat
        case timeFormat
        case defaultLandingSection
        case motionProfile
        case attentionRemindersEnabled
        case attentionNotificationsEnabled
        case attentionNotificationHour
        case attentionNotificationMinute
        case timerCustomMinutes
        case timerCustomSeconds
        case timerCustomChecklistText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try container.decodeIfPresent(String.self, forKey: .appLanguage)
        helperRotation = try container.decodeIfPresent(String.self, forKey: .helperRotation) ?? ""
        guardianRotation = try container.decodeIfPresent(String.self, forKey: .guardianRotation) ?? ""
        lineLeaderRotation = try container.decodeIfPresent(String.self, forKey: .lineLeaderRotation) ?? ""
        messengerRotation = try container.decodeIfPresent(String.self, forKey: .messengerRotation) ?? ""
        customCategoriesData = try container.decodeIfPresent(String.self, forKey: .customCategoriesData) ?? ""
        customRotationData = try container.decodeIfPresent(String.self, forKey: .customRotationData) ?? ""
        dateFormat = try container.decodeIfPresent(String.self, forKey: .dateFormat) ?? AppDateFormatPreference.system.rawValue
        timeFormat = try container.decodeIfPresent(String.self, forKey: .timeFormat) ?? AppTimeFormatPreference.system.rawValue
        defaultLandingSection = try container.decodeIfPresent(String.self, forKey: .defaultLandingSection) ?? AppSection.dashboard.rawValue
        motionProfile = try container.decodeIfPresent(String.self, forKey: .motionProfile) ?? AppMotionProfile.full.rawValue
        attentionRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .attentionRemindersEnabled) ?? true
        attentionNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .attentionNotificationsEnabled) ?? false
        attentionNotificationHour = try container.decodeIfPresent(Int.self, forKey: .attentionNotificationHour) ?? 7
        attentionNotificationMinute = try container.decodeIfPresent(Int.self, forKey: .attentionNotificationMinute) ?? 30
        timerCustomMinutes = try container.decodeIfPresent(Int.self, forKey: .timerCustomMinutes) ?? 5
        timerCustomSeconds = try container.decodeIfPresent(Int.self, forKey: .timerCustomSeconds) ?? 0
        timerCustomChecklistText = try container.decodeIfPresent(String.self, forKey: .timerCustomChecklistText) ?? ""
    }
}
