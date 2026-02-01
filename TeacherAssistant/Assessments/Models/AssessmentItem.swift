import Foundation
import SwiftData

@Model
class AssessmentItem {
    var title: String
    var score: Int
    
    init(title: String, score: Int = 0) {
        self.title = title
        self.score = score
    }
}
