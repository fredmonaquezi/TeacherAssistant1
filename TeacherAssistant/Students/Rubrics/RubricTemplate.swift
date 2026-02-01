import Foundation
import SwiftData

@Model
class RubricTemplate {
    var id: UUID
    var name: String
    var gradeLevel: String
    var subject: String
    var sortOrder: Int
    
    @Relationship(deleteRule: .cascade, inverse: \RubricCategory.template)
    var categories: [RubricCategory] = []
    
    init(name: String, gradeLevel: String, subject: String) {
        self.id = UUID()
        self.name = name
        self.gradeLevel = gradeLevel
        self.subject = subject
        self.sortOrder = 0
    }
}
