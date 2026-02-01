import Foundation
import SwiftData

@Model
class RubricCriterion {
    var id: UUID
    var name: String
    var details: String
    var sortOrder: Int
    
    var category: RubricCategory?
    
    @Relationship(deleteRule: .cascade)
    var scores: [DevelopmentScore] = []
    
    init(name: String, details: String = "") {
        self.id = UUID()
        self.name = name
        self.details = details
        self.sortOrder = 0
    }
}
