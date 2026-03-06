import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    let folderID: UUID

    @Query private var allFolders: [LibraryFolder]
    @Query private var allFiles: [LibraryFile]

    // UI state
    @State private var showingRenameSheet = false
    @State private var showingImportPicker = false
    @State private var showingDeleteConfirm = false

    // Select mode
    @State private var isSelecting = false
    @State private var selectedFolderIDs: Set<UUID> = []
    @State private var selectedFileIDs: Set<UUID> = []
    
    @State private var showingMoveSheet = false
    
    @State private var searchText: String = ""
    @State private var derivedData: LibraryDerivedData = .empty

    // Current folder
    var folder: LibraryFolder? {
        derivedData.folder
    }

    var subfolders: [LibraryFolder] {
        derivedData.subfolders
    }

    var files: [LibraryFile] {
        derivedData.files
    }

    var isRootFolder: Bool {
        folder?.parentID == nil
    }

    var selectionCount: Int {
        selectedFolderIDs.count + selectedFileIDs.count
    }
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var matchingFolders: [LibraryFolder] {
        derivedData.matchingFolders
    }

    var matchingFiles: [LibraryFile] {
        derivedData.matchingFiles
    }

    var folderByID: [UUID: LibraryFolder] {
        derivedData.folderByID
    }

    var fileCountByParent: [UUID: Int] {
        derivedData.fileCountByParent
    }

    var subfolderCountByParent: [UUID: Int] {
        derivedData.subfolderCountByParent
    }

    private var refreshToken: String {
        [
            String(allFolders.count),
            String(allFiles.count),
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            folderID.uuidString,
        ].joined(separator: "|")
    }

    var body: some View {
        if let folder = folder {
            Group {
                #if os(macOS)
                VStack(spacing: 0) {
                    libraryTopBar
                    Divider()
                    libraryGridContent
                }
                #else
                libraryGridContent
                    .navigationTitle(folder.name)
                    .toolbar {

                        // 🔍 SEARCH FIELD (CENTER)
                        ToolbarItem(placement: .principal) {
                            TextField("Search", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 300)
                        }

                        // 🔘 ACTION BUTTONS (RIGHT)
                        ToolbarItemGroup(placement: .primaryAction) {

                            if isSelecting {
                                Button("Cancel") {
                                    exitSelectMode()
                                }

                                Button {
                                    showingMoveSheet = true
                                } label: {
                                    Label("Move", systemImage: "folder")
                                }
                                .disabled(selectionCount == 0)

                                Button(role: .destructive) {
                                    showingDeleteConfirm = true
                                } label: {
                                    Label(
                                        String(format: languageManager.localized("Delete (%d)"), selectionCount),
                                        systemImage: "trash"
                                    )
                                }
                                .disabled(selectionCount == 0)

                            } else {
                                Button {
                                    createFolder()
                                } label: {
                                    Label("New Folder", systemImage: "folder.badge.plus")
                                }

                                Button {
                                    showingImportPicker = true
                                } label: {
                                    Label("Import PDF", systemImage: "square.and.arrow.down")
                                }

                                Button {
                                    showingRenameSheet = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    showingDeleteConfirm = true
                                } label: {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                                .disabled(isRootFolder)

                                Button {
                                    enterSelectMode()
                                } label: {
                                    Text("Select")
                                }
                            }
                        }
                    }
                #endif
            }

            // Rename
            .sheet(isPresented: $showingRenameSheet) {
                RenameFolderSheet(currentName: folder.name) { newName in
                    renameFolder(to: newName)
                }
            }
            
            // Moving
            .sheet(isPresented: $showingMoveSheet) {
                MoveDestinationPicker(
                    allFolders: allFolders,
                    currentFolderID: folderID
                ) { destination in
                    moveSelection(to: destination)
                    showingMoveSheet = false
                }
            }

            // Import
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    importPDF(from: url)
                }
            }
            // Delete
            .confirmationDialog(
                isSelecting
                    ? languageManager.localized("Delete selected items?")
                    : languageManager.localized("Delete this folder?"),
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                if isSelecting {
                    Button(languageManager.localized("Delete"), role: .destructive) {
                        deleteSelection()
                    }
                } else {
                    Button(languageManager.localized("Delete Folder"), role: .destructive) {
                        deleteCurrentFolder()
                    }
                }
                Button(languageManager.localized("Cancel"), role: .cancel) {}
            }
            // Tag PDF Sheet
            .sheet(isPresented: $showingTagSheet) {
                if let pending = pendingFile {
                    PDFTagSheet(
                        fileName: pending.name,
                        onSave: { editedName, subject, unit in
                            // Sanitize the edited name before saving
                            let safeName = SecurityHelpers.sanitizeFilename(editedName)
                            savePDF(
                                name: safeName,
                                data: pending.data,
                                subject: subject,
                                unit: unit
                            )
                            pendingFile = nil
                        },
                        onCancel: {
                            pendingFile = nil
                        }
                    )
                }
            }
            // File size error alert
            .alert(languageManager.localized("File Too Large"), isPresented: $showingFileSizeError) {
                Button(languageManager.localized("OK")) { }
            } message: {
                Text(languageManager.localized("The selected PDF exceeds the maximum allowed file size of 100 MB."))
            }
            .task(id: refreshToken) {
                do {
                    try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
                } catch {
                    return
                }
                await refreshDerivedData()
            }
        } else {
            ProgressView("Loading folder...")
                .task(id: refreshToken) {
                    do {
                        try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
                    } catch {
                        return
                    }
                    await refreshDerivedData()
                }
        }
    }

    @ViewBuilder
    var libraryGridContent: some View {
        if isSearching {
            LibrarySearchResultsGrid(
                folders: matchingFolders,
                files: matchingFiles,
                allFolders: allFolders,
                allFiles: allFiles
            )
        } else if isSelecting {
            LibrarySelectGrid(
                subfolders: subfolders,
                files: files,
                selectedFolderIDs: $selectedFolderIDs,
                selectedFileIDs: $selectedFileIDs
            )
        } else {
            LibraryBrowseGrid(
                subfolders: subfolders,
                files: files,
                allFolders: allFolders,
                allFiles: allFiles,
                folderByID: folderByID,
                fileCountByParent: fileCountByParent,
                subfolderCountByParent: subfolderCountByParent
            )
        }
    }

    var libraryTopBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                Spacer()

                if isSelecting {
                    Button("Cancel") {
                        exitSelectMode()
                    }

                    Button {
                        showingMoveSheet = true
                    } label: {
                        Label("Move", systemImage: "folder")
                    }
                    .disabled(selectionCount == 0)

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label(
                            String(format: languageManager.localized("Delete (%d)"), selectionCount),
                            systemImage: "trash"
                        )
                    }
                    .disabled(selectionCount == 0)
                } else {
                    Button {
                        createFolder()
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import PDF", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showingRenameSheet = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                    .disabled(isRootFolder)

                    Button("Select") {
                        enterSelectMode()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.secondarySystemBackground))
        #endif
    }


    // MARK: - Select mode

    func enterSelectMode() {
        isSelecting = true
        selectedFolderIDs.removeAll()
        selectedFileIDs.removeAll()
    }

    func exitSelectMode() {
        isSelecting = false
        selectedFolderIDs.removeAll()
        selectedFileIDs.removeAll()
    }

    // MARK: - Actions

    func createFolder() {
        Task {
            await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Create library folder"
            ) {
                let newFolder = LibraryFolder(name: "New Folder", parentID: folderID)
                context.insert(newFolder)
            }
        }
    }

    func renameFolder(to newName: String) {
        guard let folder = folder else { return }
        Task {
            await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Rename current library folder"
            ) {
                folder.name = newName
            }
        }
    }

    func deleteCurrentFolder() {
        guard let folder = folder, folder.parentID != nil else { return }
        Task {
            let result = await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Delete current library folder"
            ) {
                deleteFolderRecursively(folder)
            }
            if result.didSave {
                dismiss()
            }
        }
    }

    func deleteSelection() {
        Task {
            let result = await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Delete library selection"
            ) {
                for id in selectedFileIDs {
                    if let file = allFiles.first(where: { $0.id == id }) {
                        context.delete(file)
                    }
                }

                for id in selectedFolderIDs {
                    if let folder = allFolders.first(where: { $0.id == id }) {
                        deleteFolderRecursively(folder)
                    }
                }
            }
            if result.didSave {
                exitSelectMode()
            }
        }
    }

    func deleteFolderRecursively(_ folder: LibraryFolder) {
        let filesToDelete = allFiles.filter { $0.parentFolderID == folder.id }
        for file in filesToDelete { context.delete(file) }

        let subfoldersToDelete = allFolders.filter { $0.parentID == folder.id }
        for sub in subfoldersToDelete { deleteFolderRecursively(sub) }

        context.delete(folder)
    }

    @State private var showingTagSheet = false
    @State private var pendingFile: (name: String, data: Data)?
    @State private var showingFileSizeError = false

    func importPDF(from url: URL) {
        // Properly handle security-scoped resource access
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { 
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource() 
            }
        }
        
        // Validate file access was granted
        guard didStartAccessing else {
            SecureLogger.warning("Failed to access security-scoped resource for PDF import")
            return
        }
        
        // Validate file size before reading
        guard SecurityHelpers.validateFileSize(at: url, maxSize: SecurityHelpers.maxPDFFileSize) else {
            SecureLogger.warning("PDF file exceeds maximum size limit")
            showingFileSizeError = true
            return
        }

        guard let data = try? Data(contentsOf: url) else { 
            SecureLogger.warning("Failed to read PDF data")
            return 
        }
        
        // Sanitize the filename
        let originalName = url.deletingPathExtension().lastPathComponent
        let sanitizedName = SecurityHelpers.sanitizeFilename(originalName)

        pendingFile = (
            name: sanitizedName,
            data: data
        )
        showingTagSheet = true
    }

    func savePDF(name: String, data: Data, subject: Subject?, unit: Unit?) {
        Task {
            await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Import PDF into library"
            ) {
                let newFile = LibraryFile(
                    name: name,
                    pdfData: data,
                    parentFolderID: folderID
                )

                // Link to subject/unit
                newFile.linkedSubject = subject
                newFile.linkedUnit = unit

                context.insert(newFile)
            }
        }
    }
    
    func moveSelection(to destination: LibraryFolder) {
        Task {
            let result = await PersistenceWriteCoordinator.shared.perform(
                context: context,
                reason: "Move library selection"
            ) {
                // Move files
                for id in selectedFileIDs {
                    if let file = allFiles.first(where: { $0.id == id }) {
                        file.parentFolderID = destination.id
                    }
                }

                // Move folders (with safety check)
                for id in selectedFolderIDs {
                    if let folder = allFolders.first(where: { $0.id == id }) {

                        // Block moving into itself.
                        if folder.id == destination.id {
                            continue
                        }

                        // Block moving into one of its descendants.
                        if isDescendant(destination, of: folder) {
                            continue
                        }

                        // Safe to move.
                        folder.parentID = destination.id
                    }
                }
            }
            if result.didSave {
                exitSelectMode()
            }
        }
    }
    
    func isDescendant(_ possibleChild: LibraryFolder, of parent: LibraryFolder) -> Bool {
        var currentParentID = possibleChild.parentID

        while let pid = currentParentID {
            if pid == parent.id {
                return true
            }
            currentParentID = allFolders.first(where: { $0.id == pid })?.parentID
        }

        return false
    }

    @MainActor
    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.libraryDerive)
        let derived = await LibraryStore.deriveAsync(
            allFolders: allFolders,
            allFiles: allFiles,
            folderID: folderID,
            searchText: searchText
        )
        if Task.isCancelled {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }

        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
    }


}
