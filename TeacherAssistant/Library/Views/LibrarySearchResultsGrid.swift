import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibrarySearchResultsGrid: View {
    @Environment(\.appMotionContext) private var motion

    let folders: [LibraryFolder]
    let files: [LibraryFile]
    let allFolders: [LibraryFolder]
    let allFiles: [LibraryFile]
    
    @State private var renamingFolderID: UUID?
    @State private var renamingFileID: UUID?

    private var folderByID: [UUID: LibraryFolder] {
        Dictionary(uniqueKeysWithValues: allFolders.map { ($0.id, $0) })
    }

    private var fileCountByParent: [UUID: Int] {
        allFiles.reduce(into: [:]) { partialResult, file in
            partialResult[file.parentFolderID, default: 0] += 1
        }
    }

    private var subfolderCountByParent: [UUID: Int] {
        allFolders.reduce(into: [:]) { partialResult, folder in
            guard let parentID = folder.parentID else { return }
            partialResult[parentID, default: 0] += 1
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
            ], spacing: 24) {
                
                ForEach(folders, id: \.id) { folder in
                    FolderCardView(
                        folder: folder,
                        allFolders: allFolders,
                        allFiles: allFiles,
                        folderByID: folderByID,
                        fileCount: fileCountByParent[folder.id] ?? 0,
                        subfolderCount: subfolderCountByParent[folder.id] ?? 0,
                        isRenaming: renamingFolderID == folder.id,
                        onRename: { renamingFolderID = folder.id },
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
        .animation(motion.animation(.standard), value: folders.count)
        .animation(motion.animation(.standard), value: files.count)
    }
}
