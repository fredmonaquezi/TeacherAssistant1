import Foundation
import SwiftData
import SwiftUI 


@Model
class DevelopmentScore {
    var id: UUID
    var rating: Int // 1-5
    var date: Date
    var notes: String
    
    var student: Student?
    var criterion: RubricCriterion?
    
    init(student: Student, criterion: RubricCriterion, rating: Int, notes: String = "", date: Date = Date()) {
        self.id = UUID()
        self.student = student
        self.criterion = criterion
        self.rating = rating
        self.notes = notes
        self.date = date
    }
}

// Rating labels
extension DevelopmentScore {
    var ratingLabel: String {
        switch rating {
        case 1: return "Needs Significant Support".localized
        case 2: return "Beginning to Develop".localized
        case 3: return "Developing".localized
        case 4: return "Proficient".localized
        case 5: return "Mastering / Exceeding".localized
        default: return "Not Rated".localized
        }
    }
    
    var ratingColor: Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}
