import Foundation
import SwiftData

enum AssessmentResultStatus: String, Codable, CaseIterable {
    case ungraded = "ungraded"
    case scored = "scored"
    case absent = "absent"
    case excused = "excused"

    var isResolved: Bool {
        self != .ungraded
    }
}

@Model
class StudentResult {

    var student: Student?
    var assessment: Assessment?
    var score: Double
    var hasScore: Bool
    var statusRaw: String
    var notes: String

    init(
        student: Student,
        assessment: Assessment? = nil,
        score: Double = 0,
        notes: String = "",
        hasScore: Bool? = nil,
        status: AssessmentResultStatus? = nil
    ) {
        self.student = student
        self.assessment = assessment
        self.score = score
        let resolvedStatus = status ?? ((hasScore ?? (score > 0)) ? .scored : .ungraded)
        self.hasScore = resolvedStatus == .scored
        self.statusRaw = resolvedStatus.rawValue
        self.notes = notes
    }

    var status: AssessmentResultStatus {
        get {
            if let parsedStatus = AssessmentResultStatus(rawValue: statusRaw) {
                return parsedStatus
            }
            return (hasScore || score > 0) ? .scored : .ungraded
        }
        set {
            statusRaw = newValue.rawValue
            hasScore = newValue == .scored
        }
    }

    var isScored: Bool {
        status == .scored
    }

    var isResolved: Bool {
        status.isResolved
    }

    func applyStatus(_ newStatus: AssessmentResultStatus, score newScore: Double? = nil) {
        status = newStatus
        switch newStatus {
        case .scored:
            score = newScore ?? score
        case .ungraded, .absent, .excused:
            score = 0
        }
    }

    var statusDisplayText: String {
        switch status {
        case .ungraded:
            return "—"
        case .scored:
            let safeScore = assessment?.clampedScore(score) ?? score
            if safeScore.rounded() == safeScore {
                return String(Int(safeScore))
            }
            return String(format: "%.1f", safeScore)
        case .absent:
            return "Absent".localized
        case .excused:
            return "Excused".localized
        }
    }
}
