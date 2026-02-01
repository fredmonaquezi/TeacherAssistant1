import Foundation
import SwiftData

@Model
class AssessmentCategory {
    var title: String
    
    init(title: String) {
        self.title = title
    }
}
