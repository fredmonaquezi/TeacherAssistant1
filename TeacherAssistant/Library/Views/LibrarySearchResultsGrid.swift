import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibrarySearchResultsGrid: View {

    let folders: [LibraryFolder]
    let files: [LibraryFile]
    
    @State private var renamingFolderID: UUID?
    @State private var renamingFileID: UUID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
            ], spacing: 24) {
                
                ForEach(folders, id: \.id) { folder in
                    FolderCardView(
                        folder: folder,
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
        }
    }
}
