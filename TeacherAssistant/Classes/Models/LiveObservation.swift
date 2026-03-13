import Foundation
import SwiftData
import SwiftUI

enum LiveObservationLevel: String, Codable, CaseIterable {
    case secure = "secure"
    case developing = "developing"
    case emerging = "emerging"
    case needsSupport = "needs_support"

    var title: String {
        switch self {
        case .secure:
            return "Secure".localized
        case .developing:
            return "Developing".localized
        case .emerging:
            return "Emerging".localized
        case .needsSupport:
            return "Needs Support".localized
        }
    }

    var systemImage: String {
        switch self {
        case .secure:
            return "checkmark.circle.fill"
        case .developing:
            return "arrow.up.right.circle.fill"
        case .emerging:
            return "exclamationmark.circle.fill"
        case .needsSupport:
            return "cross.case.fill"
        }
    }

    var color: Color {
        switch self {
        case .secure:
            return .green
        case .developing:
            return .teal
        case .emerging:
            return .orange
        case .needsSupport:
            return .red
        }
    }
}

enum LiveObservationSource: String, Codable, CaseIterable {
    case standaloneTool = "standalone_tool"
    case classroomSession = "classroom_session"

    var title: String {
        switch self {
        case .standaloneTool:
            return "Live Check-In".localized
        case .classroomSession:
            return "Session Check-In".localized
        }
    }
}

@Model
final class LiveObservationTemplate {
    var id: UUID
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LiveObservationTemplateCriterion.template)
    var criteria: [LiveObservationTemplateCriterion] = []

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        criteria: [LiveObservationTemplateCriterion] = []
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.criteria = criteria
    }
}

@Model
final class LiveObservationTemplateCriterion {
    var id: UUID
    var title: String
    var sortOrder: Int

    var template: LiveObservationTemplate?

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int = 0,
        template: LiveObservationTemplate? = nil
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.template = template
    }
}

@Model
final class LiveObservation {
    var id: UUID
    var createdAt: Date
    var sessionDate: Date
    var sourceRaw: String
    var understandingLevelRaw: String
    var engagementLevelRaw: String
    var supportLevelRaw: String
    var note: String
    var studentUUID: UUID
    var studentNameSnapshot: String

    var student: Student?
    var schoolClass: SchoolClass?

    @Relationship(deleteRule: .cascade, inverse: \LiveObservationChecklistResponse.observation)
    var checklistResponses: [LiveObservationChecklistResponse] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sessionDate: Date,
        source: LiveObservationSource,
        understandingLevel: LiveObservationLevel,
        engagementLevel: LiveObservationLevel,
        supportLevel: LiveObservationLevel,
        note: String = "",
        studentUUID: UUID,
        studentNameSnapshot: String,
        student: Student? = nil,
        schoolClass: SchoolClass? = nil,
        checklistResponses: [LiveObservationChecklistResponse] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sessionDate = sessionDate
        self.sourceRaw = source.rawValue
        self.understandingLevelRaw = understandingLevel.rawValue
        self.engagementLevelRaw = engagementLevel.rawValue
        self.supportLevelRaw = supportLevel.rawValue
        self.note = note
        self.studentUUID = studentUUID
        self.studentNameSnapshot = studentNameSnapshot
        self.student = student
        self.schoolClass = schoolClass
        self.checklistResponses = checklistResponses
    }

    var source: LiveObservationSource {
        get { LiveObservationSource(rawValue: sourceRaw) ?? .standaloneTool }
        set { sourceRaw = newValue.rawValue }
    }

    var understandingLevel: LiveObservationLevel {
        get { LiveObservationLevel(rawValue: understandingLevelRaw) ?? .developing }
        set { understandingLevelRaw = newValue.rawValue }
    }

    var engagementLevel: LiveObservationLevel {
        get { LiveObservationLevel(rawValue: engagementLevelRaw) ?? .developing }
        set { engagementLevelRaw = newValue.rawValue }
    }

    var supportLevel: LiveObservationLevel {
        get { LiveObservationLevel(rawValue: supportLevelRaw) ?? .developing }
        set { supportLevelRaw = newValue.rawValue }
    }
}

@Model
final class LiveObservationChecklistResponse {
    var id: UUID
    var criterionTitle: String
    var levelRaw: String
    var sortOrder: Int

    var observation: LiveObservation?

    init(
        id: UUID = UUID(),
        criterionTitle: String,
        level: LiveObservationLevel,
        sortOrder: Int = 0,
        observation: LiveObservation? = nil
    ) {
        self.id = id
        self.criterionTitle = criterionTitle
        self.levelRaw = level.rawValue
        self.sortOrder = sortOrder
        self.observation = observation
    }

    var level: LiveObservationLevel {
        get { LiveObservationLevel(rawValue: levelRaw) ?? .developing }
        set { levelRaw = newValue.rawValue }
    }
}
