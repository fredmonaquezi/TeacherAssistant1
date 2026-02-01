import Foundation
import SwiftData

@Model
class RubricCategory {
    var id: UUID
    var name: String
    var sortOrder: Int
    
    var template: RubricTemplate?
    
    @Relationship(deleteRule: .cascade, inverse: \RubricCriterion.category)
    var criteria: [RubricCriterion] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.sortOrder = 0
    }
}
