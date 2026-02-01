import Foundation
import SwiftData

@Model
class Unit: Hashable {
    var id: UUID
    var name: String
    var sortOrder: Int
    
    var subject: Subject?
    
    @Relationship(deleteRule: .cascade, inverse: \Assessment.unit)
    var assessments: [Assessment] = []
    
    @Relationship(deleteRule: .nullify)
    var linkedFiles: [LibraryFile] = []  // ← ADD THIS
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.sortOrder = 0
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: Unit, rhs: Unit) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
