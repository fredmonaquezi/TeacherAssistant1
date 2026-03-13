import SwiftUI

struct MoveDestinationPicker: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appMotionContext) private var motion

    let allFolders: [LibraryFolder]
    let currentFolderID: UUID
    let onPick: (LibraryFolder) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(rootFolders, id: \.id) { folder in
                    FolderRow(
                        folder: folder,
                        allFolders: allFolders,
                        currentFolderID: currentFolderID,
                        level: 0,
                        onPick: onPick
                    )
                }
            }
            .appMotionReveal(index: 0)
            .navigationTitle("Move To…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .appSheetMotion()
        .animation(motion.animation(.standard), value: rootFolders.count)
    }

    var rootFolders: [LibraryFolder] {
        allFolders.filter { $0.parentID == nil }
    }
}

struct FolderRow: View {
    @Environment(\.appMotionContext) private var motion

    let folder: LibraryFolder
    let allFolders: [LibraryFolder]
    let currentFolderID: UUID
    let level: Int
    let onPick: (LibraryFolder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if folder.id != currentFolderID {
                    onPick(folder)
                }
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.orange)
                    Text(folder.name)
                    Spacer()
                    if folder.id != currentFolderID {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.leading, CGFloat(level) * 20)
                .padding(.vertical, 6)
                .opacity(folder.id == currentFolderID ? 0.5 : 1)
            }
            .buttonStyle(AppPressableButtonStyle())
            .disabled(folder.id == currentFolderID)

            ForEach(children, id: \.id) { child in
                FolderRow(
                    folder: child,
                    allFolders: allFolders,
                    currentFolderID: currentFolderID,
                    level: level + 1,
                    onPick: onPick
                )
            }
        }
        .animation(motion.animation(.quick), value: children.count)
    }

    var children: [LibraryFolder] {
        allFolders.filter { $0.parentID == folder.id }
    }
}
