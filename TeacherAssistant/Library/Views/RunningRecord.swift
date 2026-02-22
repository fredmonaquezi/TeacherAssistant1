import Foundation
import SwiftData

enum RunningRecordDateRangePreset: String, CaseIterable, Codable, Identifiable {
    case all
    case last7Days
    case last30Days
    case last90Days
    case thisTerm
    case custom

    var id: String { rawValue }

    func includes(
        _ date: Date,
        customStartDate: Date?,
        customEndDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        switch self {
        case .all:
            return true
        case .last7Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= cutoff
        case .last30Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= cutoff
        case .last90Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return date >= cutoff
        case .thisTerm:
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            let inFirstTerm = month <= 6
            let startMonth = inFirstTerm ? 1 : 7
            let endMonth = inFirstTerm ? 6 : 12
            guard
                let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)),
                let endMonthStart = calendar.date(from: DateComponents(year: year, month: endMonth, day: 1)),
                let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: endMonthStart)
            else {
                return true
            }
            return date >= start && date <= end
        case .custom:
            if let customStartDate, date < customStartDate {
                return false
            }
            if let customEndDate, date > customEndDate {
                return false
            }
            return true
        }
    }
}

enum RunningRecordSortOption: String, CaseIterable, Codable, Identifiable {
    case dateDescending
    case dateAscending
    case accuracyDescending
    case accuracyAscending
    case studentAscending
    case studentDescending

    var id: String { rawValue }
}

enum ReadingLevel: String, Codable, CaseIterable {
    case independent = "Independent (95-100%)"
    case instructional = "Instructional (90-94%)"
    case frustration = "Frustration (<90%)"
    
    var color: String {
        switch self {
        case .independent: return "green"
        case .instructional: return "orange"
        case .frustration: return "red"
        }
    }
    
    var systemImage: String {
        switch self {
        case .independent: return "checkmark.circle.fill"
        case .instructional: return "book.fill"
        case .frustration: return "exclamationmark.triangle.fill"
        }
    }
}

@Model
class RunningRecord {
    var date: Date
    var textTitle: String
    var totalWords: Int
    var errors: Int
    var selfCorrections: Int
    var notes: String
    
    // Computed properties
    var accuracy: Double {
        guard totalWords > 0 else { return 0 }
        return Double(totalWords - errors) / Double(totalWords) * 100
    }
    
    var readingLevel: ReadingLevel {
        if accuracy >= 95 {
            return .independent
        } else if accuracy >= 90 {
            return .instructional
        } else {
            return .frustration
        }
    }
    
    var selfCorrectionRatio: String {
        guard selfCorrections > 0 else { return "N/A" }
        let ratio = Double(errors + selfCorrections) / Double(selfCorrections)
        return String(format: "1:%.1f", ratio)
    }

    var selfCorrectionRatioValue: Double? {
        guard selfCorrections > 0 else { return nil }
        return Double(errors + selfCorrections) / Double(selfCorrections)
    }
    
    // Relationship
    var student: Student?

    var studentDisplayName: String {
        guard let name = student?.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unknown Student"
        }
        return name
    }

    var classDisplayName: String {
        guard let schoolClass = student?.schoolClass else { return "No Class" }
        if schoolClass.grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return schoolClass.name
        }
        return "\(schoolClass.name) (\(schoolClass.grade))"
    }

    var searchableText: String {
        [
            studentDisplayName,
            classDisplayName,
            textTitle,
            notes,
            readingLevel.rawValue
        ].joined(separator: " ").lowercased()
    }
    
    init(
        date: Date = Date(),
        textTitle: String = "",
        totalWords: Int = 0,
        errors: Int = 0,
        selfCorrections: Int = 0,
        notes: String = ""
    ) {
        self.date = date
        self.textTitle = textTitle
        self.totalWords = totalWords
        self.errors = errors
        self.selfCorrections = selfCorrections
        self.notes = notes
    }
}
