import Foundation
import SwiftData

@Model
class Subject: Hashable {
    var id: UUID
    var name: String
    var sortOrder: Int
    
    var schoolClass: SchoolClass?
    
    @Relationship(deleteRule: .cascade, inverse: \Unit.subject)
    var units: [Unit] = []
    
    @Relationship(deleteRule: .nullify)
    var linkedFiles: [LibraryFile] = []  // ← ADD THIS
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.sortOrder = 0
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: Subject, rhs: Subject) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
