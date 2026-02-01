import Foundation
import SwiftData

@Model
class AssessmentScore {
    var value: Int
    
    init(value: Int = 0) {
        self.value = value
    }
}
