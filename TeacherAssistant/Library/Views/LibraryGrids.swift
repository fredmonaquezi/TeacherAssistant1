import SwiftUI

struct LibraryBrowseGrid: View {
    @Environment(\.appMotionContext) private var motion
    let subfolders: [LibraryFolder]
    let files: [LibraryFile]
    let allFolders: [LibraryFolder]
    let allFiles: [LibraryFile]
    let folderByID: [UUID: LibraryFolder]
    let fileCountByParent: [UUID: Int]
    let subfolderCountByParent: [UUID: Int]

    @State private var renamingFolderID: UUID?
    @State private var renamingFileID: UUID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24),
            ], spacing: 24) {
                ForEach(subfolders, id: \.id) { sub in
                    FolderCardView(
                        folder: sub,
                        allFolders: allFolders,
                        allFiles: allFiles,
                        folderByID: folderByID,
                        fileCount: fileCountByParent[sub.id] ?? 0,
                        subfolderCount: subfolderCountByParent[sub.id] ?? 0,
                        isRenaming: renamingFolderID == sub.id,
                        onRename: { renamingFolderID = sub.id },
                        onEndRename: { renamingFolderID = nil }
                    )
                }

                ForEach(files, id: \.id) { file in
                    PDFCardView(
                        file: file,
                        isRenaming: renamingFileID == file.id,
                        onRename: { renamingFileID = file.id },
                        onEndRename: { renamingFileID = nil }
                    )
                }
            }
            .padding(24)
            .appMotionReveal(index: 0)
        }
        .animation(motion.animation(.standard), value: subfolders.count)
        .animation(motion.animation(.standard), value: files.count)
    }
}

struct LibrarySelectGrid: View {
    @Environment(\.appMotionContext) private var motion
    let subfolders: [LibraryFolder]
    let files: [LibraryFile]

    @Binding var selectedFolderIDs: Set<UUID>
    @Binding var selectedFileIDs: Set<UUID>

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24),
            ], spacing: 24) {
                ForEach(subfolders, id: \.id) { sub in
                    SelectableFolderCard(
                        folder: sub,
                        isSelected: selectedFolderIDs.contains(sub.id)
                    ) {
                        toggleFolder(sub.id)
                    }
                }

                ForEach(files, id: \.id) { file in
                    SelectablePDFCard(
                        file: file,
                        isSelected: selectedFileIDs.contains(file.id)
                    ) {
                        toggleFile(file.id)
                    }
                }
            }
            .padding(24)
            .appMotionReveal(index: 0)
        }
        .animation(motion.animation(.standard), value: selectedFolderIDs.count)
        .animation(motion.animation(.standard), value: selectedFileIDs.count)
    }

    func toggleFolder(_ id: UUID) {
        if selectedFolderIDs.contains(id) {
            selectedFolderIDs.remove(id)
        } else {
            selectedFolderIDs.insert(id)
        }
    }

    func toggleFile(_ id: UUID) {
        if selectedFileIDs.contains(id) {
            selectedFileIDs.remove(id)
        } else {
            selectedFileIDs.insert(id)
        }
    }
}
