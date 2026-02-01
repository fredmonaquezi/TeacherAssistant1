import SwiftUI

struct MoveDestinationPicker: View {

    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("Move To…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var rootFolders: [LibraryFolder] {
        allFolders.filter { $0.parentID == nil }
    }
}

struct FolderRow: View {

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
                    Text(folder.name)
                    Spacer()
                }
                .padding(.leading, CGFloat(level) * 20)
            }
            .buttonStyle(.plain)
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
    }

    var children: [LibraryFolder] {
        allFolders.filter { $0.parentID == folder.id }
    }
}
