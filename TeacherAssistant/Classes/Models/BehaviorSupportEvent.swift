import Foundation
import SwiftData
import SwiftUI

enum BehaviorSupportEventKind: String, Codable, CaseIterable {
    case positiveBehavior = "positive_behavior"
    case supportCheckIn = "support_check_in"
    case redirectNeeded = "redirect_needed"

    var title: String {
        switch self {
        case .positiveBehavior:
            return "Positive Behavior".localized
        case .supportCheckIn:
            return "Support Check-In".localized
        case .redirectNeeded:
            return "Redirect Needed".localized
        }
    }

    var systemImage: String {
        switch self {
        case .positiveBehavior:
            return "hand.thumbsup.fill"
        case .supportCheckIn:
            return "person.fill.questionmark"
        case .redirectNeeded:
            return "exclamationmark.bubble.fill"
        }
    }

    var color: Color {
        switch self {
        case .positiveBehavior:
            return .green
        case .supportCheckIn:
            return .orange
        case .redirectNeeded:
            return .red
        }
    }

    var shouldFlagNeedsHelp: Bool {
        switch self {
        case .positiveBehavior:
            return false
        case .supportCheckIn, .redirectNeeded:
            return true
        }
    }
}

@Model
class BehaviorSupportEvent {
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
        kind: BehaviorSupportEventKind = .supportCheckIn,
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

    var kind: BehaviorSupportEventKind {
        get { BehaviorSupportEventKind(rawValue: kindRaw) ?? .supportCheckIn }
        set { kindRaw = newValue.rawValue }
    }
}
