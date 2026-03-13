import SwiftUI
import SwiftData

struct LibraryRootView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appMotionContext) private var motion
    @Query(filter: #Predicate<LibraryFolder> { $0.parentID == nil })
    private var rootCandidates: [LibraryFolder]

    @State private var rootFolder: LibraryFolder?

    var body: some View {
        Group {
            if let root = rootFolder {
                LibraryView(folderID: root.id)
                    .transition(motion.transition(.sectionSwitch))
            } else {
                ProgressView("Loading Library...")
                    .appMotionReveal(index: 0)
            }
        }
        .animation(motion.animation(.standard), value: rootFolder?.id)
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
