import SwiftUI
import SwiftData

struct LibraryRootView: View {

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<LibraryFolder> { $0.parentID == nil })
    private var rootCandidates: [LibraryFolder]

    @State private var rootFolder: LibraryFolder?

    var body: some View {
        Group {
            if let root = rootFolder {
                LibraryView(folderID: root.id)
            } else {
                ProgressView("Loading Library...")
            }
        }
        .onAppear {
            loadOrCreateRoot()
        }
    }

    // MARK: - Root Logic

    func loadOrCreateRoot() {
        if let existing = rootCandidates.first {
            rootFolder = existing
            return
        }

        let root = LibraryFolder(name: "Library", parentID: nil)
        context.insert(root)
        rootFolder = root
    }
}
