import Foundation
import SwiftData

enum ParticipationEventKind: String, Codable, CaseIterable {
    case contribution = "contribution"
    case leadership = "leadership"
    case collaboration = "collaboration"

    var title: String {
        switch self {
        case .contribution:
            return "Contribution".localized
        case .leadership:
            return "Leadership".localized
        case .collaboration:
            return "Collaboration".localized
        }
    }
}

@Model
class ParticipationEvent {
    var id: UUID
    var createdAt: Date
    var kindRaw: String
    var note: String
    var studentUUID: UUID
    var studentNameSnapshot: String

    var student: Student?
    var schoolClass: SchoolClass?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ParticipationEventKind = .contribution,
        note: String = "",
        studentUUID: UUID,
        studentNameSnapshot: String,
        student: Student? = nil,
        schoolClass: SchoolClass? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kindRaw = kind.rawValue
        self.note = note
        self.studentUUID = studentUUID
        self.studentNameSnapshot = studentNameSnapshot
        self.student = student
        self.schoolClass = schoolClass
    }

    var kind: ParticipationEventKind {
        get { ParticipationEventKind(rawValue: kindRaw) ?? .contribution }
        set { kindRaw = newValue.rawValue }
    }
}
