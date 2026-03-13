import Foundation
import SwiftData

enum InterventionCategory: String, Codable, CaseIterable {
    case academics = "academics"
    case attendance = "attendance"
    case homework = "homework"
    case behavior = "behavior"
    case wellbeing = "wellbeing"
    case other = "other"

    var title: String {
        switch self {
        case .academics:
            return "Academics".localized
        case .attendance:
            return "Attendance".localized
        case .homework:
            return "Homework".localized
        case .behavior:
            return "Behavior".localized
        case .wellbeing:
            return "Wellbeing".localized
        case .other:
            return "Other".localized
        }
    }
}

enum InterventionStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case resolved = "resolved"

    var title: String {
        switch self {
        case .open:
            return "Open".localized
        case .inProgress:
            return "In Progress".localized
        case .resolved:
            return "Resolved".localized
        }
    }
}

@Model
class Intervention {
    var id: UUID
    var title: String
    var notes: String
    var categoryRaw: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var followUpDate: Date?
    var student: Student?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        category: InterventionCategory = .academics,
        status: InterventionStatus = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        followUpDate: Date? = nil,
        student: Student? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.followUpDate = followUpDate
        self.student = student
    }

    var category: InterventionCategory {
        get { InterventionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var status: InterventionStatus {
        get { InterventionStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var needsFollowUp: Bool {
        guard let followUpDate, status != .resolved else { return false }
        return followUpDate < Calendar.current.startOfDay(for: Date())
    }
}
