import Foundation
import SwiftData

@MainActor
func getOrCreateLibraryRoot(context: ModelContext) -> LibraryFolder {
    let descriptor = FetchDescriptor<LibraryFolder>(
        predicate: #Predicate { $0.parentID == nil }
    )

    if let existing = try? context.fetch(descriptor).first {
        return existing
    }

    let root = LibraryFolder(name: "Library", parentID: nil)
    context.insert(root)
    return root
}
