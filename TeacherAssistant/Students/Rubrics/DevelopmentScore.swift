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
        case 1: return "Needs Significant Support"
        case 2: return "Beginning to Develop"
        case 3: return "Developing"
        case 4: return "Proficient"
        case 5: return "Mastering / Exceeding"
        default: return "Not Rated"
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
