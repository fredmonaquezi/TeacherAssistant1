import Foundation
import SwiftData

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
    
    // Relationship
    var student: Student?
    
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
