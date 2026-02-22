import Foundation

struct BackupFile: Codable {
    var classes: [BackupClass]
}

struct BackupClass: Codable {
    var name: String
    var grade: String
    var schoolYear: String?
    var sortOrder: Int
    var students: [BackupStudent]
    var categories: [BackupAssessmentCategory]
    var attendanceSessions: [BackupAttendanceSession]
    var subjects: [BackupSubject]

    init(
        name: String,
        grade: String,
        schoolYear: String? = nil,
        sortOrder: Int = 0,
        students: [BackupStudent],
        categories: [BackupAssessmentCategory] = [],
        attendanceSessions: [BackupAttendanceSession] = [],
        subjects: [BackupSubject]
    ) {
        self.name = name
        self.grade = grade
        self.schoolYear = schoolYear
        self.sortOrder = sortOrder
        self.students = students
        self.categories = categories
        self.attendanceSessions = attendanceSessions
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
        subjects = try container.decodeIfPresent([BackupSubject].self, forKey: .subjects) ?? []
    }
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
        separationList: String = ""
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
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortOrder
        case assessments
    }

    init(id: UUID = UUID(), name: String, sortOrder: Int, assessments: [BackupAssessment]) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.assessments = assessments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        assessments = try container.decodeIfPresent([BackupAssessment].self, forKey: .assessments) ?? []
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
    var notes: String

    init(studentUUID: UUID? = nil, studentName: String, score: Double, notes: String) {
        self.studentUUID = studentUUID
        self.studentName = studentName
        self.score = score
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
}

struct BackupAppSettings: Codable {
    var appLanguage: String?
    var helperRotation: String
    var guardianRotation: String
    var lineLeaderRotation: String
    var messengerRotation: String
    var customCategoriesData: String
    var customRotationData: String
}
