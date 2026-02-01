import Foundation
import SwiftData

@Model
class LibraryFolder {
    var id: UUID
    var name: String

    /// The ID of the parent folder (nil = root)
    var parentID: UUID?
    
    /// Folder color (stored as hex string, e.g., "#3B82F6" for blue)
    var colorHex: String?

    init(name: String, parentID: UUID? = nil, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.parentID = parentID
        self.colorHex = colorHex
    }
}
