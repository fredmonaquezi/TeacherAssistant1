import Foundation
import SwiftData

@Model
class LibraryFile {
    var id: UUID
    var name: String
    var pdfData: Data
    var parentFolderID: UUID
    var drawingData: Data?
    
    @Relationship(deleteRule: .nullify, inverse: \Subject.linkedFiles)
    var linkedSubject: Subject?
    
    @Relationship(deleteRule: .nullify, inverse: \Unit.linkedFiles)
    var linkedUnit: Unit?

    init(name: String, pdfData: Data, parentFolderID: UUID) {
        self.id = UUID()
        self.name = name
        self.pdfData = pdfData
        self.parentFolderID = parentFolderID
        self.drawingData = nil
        self.linkedSubject = nil
        self.linkedUnit = nil
    }
}
