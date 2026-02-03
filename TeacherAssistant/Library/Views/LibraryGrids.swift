import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct LibraryBrowseGrid: View {
    let subfolders: [LibraryFolder]
    let files: [LibraryFile]
    
    @State private var renamingFolderID: UUID?
    @State private var renamingFileID: UUID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
                ], spacing: 24) {

                ForEach(subfolders, id: \.id) { sub in
                    FolderCardView(
                        folder: sub,
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
        }
    }
}

struct LibrarySelectGrid: View {
    let subfolders: [LibraryFolder]
    let files: [LibraryFile]

    @Binding var selectedFolderIDs: Set<UUID>
    @Binding var selectedFileIDs: Set<UUID>

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
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
        }
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

// MARK: - Folder Card

struct FolderCardView: View {
    @Bindable var folder: LibraryFolder
    let isRenaming: Bool
    let onRename: () -> Void
    let onEndRename: () -> Void
    
    @State private var isHovered = false
    @State private var isDropTarget = false
    @State private var editingName: String = ""
    @State private var showingColorPicker = false
    @State private var showingInfo = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    // Delete confirmation
    @State private var showingDeleteAlert = false
    
    @Query private var allFolders: [LibraryFolder]
    @Query private var allFiles: [LibraryFile]
    
    // Predefined folder colors
    let folderColors: [(name: String, hex: String, color: Color)] = [
        ("Blue", "#3B82F6", .blue),
        ("Purple", "#A855F7", .purple),
        ("Pink", "#EC4899", .pink),
        ("Red", "#EF4444", .red),
        ("Orange", "#F97316", .orange),
        ("Yellow", "#EAB308", .yellow),
        ("Green", "#10B981", .green),
        ("Teal", "#14B8A6", .teal),
        ("Cyan", "#06B6D4", .cyan),
        ("Gray", "#6B7280", .gray)
    ]
    
    var folderColor: Color {
        if let hex = folder.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Folder Icon/Thumbnail
            NavigationLink(destination: LibraryView(folderID: folder.id)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    folderColor.opacity(isDropTarget ? 0.6 : (isHovered ? 0.4 : 0.3)),
                                    folderColor.opacity(isDropTarget ? 0.4 : (isHovered ? 0.2 : 0.1))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isDropTarget ? folderColor : folderColor.opacity(isHovered ? 0.5 : 0.2),
                                    lineWidth: isDropTarget ? 4 : 2
                                )
                        )
                        .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, x: 0, y: 2)
                    
                    Image(systemName: isDropTarget ? "folder.fill.badge.plus" : "folder.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [folderColor, folderColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Quick action overlay on hover
                    if isHovered && !isDropTarget {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Drop target indicator
                    if isDropTarget {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Drop here".localized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
                handleDrop(providers: providers)
            }
            .onDrag {
                return NSItemProvider(object: "folder:\(folder.id.uuidString)" as NSString)
            }
            
            // Folder Name (editable)
            if isRenaming {
                TextField(languageManager.localized("Folder name"), text: $editingName, onCommit: {
                    saveRename()
                })
                .textFieldStyle(.plain)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                .focused($isTextFieldFocused)
                .onAppear {
                    editingName = folder.name
                    isTextFieldFocused = true
                }
            } else {
                Text(folder.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .frame(height: 36)
            }
        }
        .frame(width: 180)
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label(languageManager.localized("Rename"), systemImage: "pencil")
            }
            
            Button {
                showingColorPicker = true
            } label: {
                Label(languageManager.localized("Change Color"), systemImage: "paintpalette")
            }
            
            Divider()
            
            Button {
                duplicateFolder()
            } label: {
                Label(languageManager.localized("Duplicate"), systemImage: "plus.square.on.square")
            }
            
            Button {
                showInFinder()
            } label: {
                Label(languageManager.localized("Get Info"), systemImage: "info.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label(languageManager.localized("Delete"), systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            colorPickerSheet
        }
        .sheet(isPresented: $showingInfo) {
            folderInfoSheet
        }
        .alert(languageManager.localized("Delete Folder?"), isPresented: $showingDeleteAlert) {
            Button(languageManager.localized("Cancel"), role: .cancel) {}
            
            Button(languageManager.localized("Delete"), role: .destructive) {
                deleteFolder()
            }
        } message: {
            Text(String(
                format: languageManager.localized("Are you sure you want to delete \"%@\" and all its contents? This action cannot be undone."),
                folder.name
            ))
        }
    }
    
    func saveRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            folder.name = trimmed
            try? context.save()
        }
        onEndRename()
    }
    
    func deleteFolder() {
        context.delete(folder)
        try? context.save()
    }
    
    // MARK: - Drag and Drop
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            guard let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) else { return }
            
            DispatchQueue.main.async {
                if string.hasPrefix("folder:") {
                    // Moving a folder
                    let idString = String(string.dropFirst("folder:".count))
                    if let uuid = UUID(uuidString: idString),
                       let draggedFolder = allFolders.first(where: { $0.id == uuid }) {
                        moveFolder(draggedFolder, into: folder)
                    }
                } else if string.hasPrefix("file:") {
                    // Moving a file
                    let idString = String(string.dropFirst("file:".count))
                    if let uuid = UUID(uuidString: idString),
                       let draggedFile = allFiles.first(where: { $0.id == uuid }) {
                        moveFile(draggedFile, into: folder)
                    }
                }
            }
        }
        
        return true
    }
    
    func moveFolder(_ draggedFolder: LibraryFolder, into targetFolder: LibraryFolder) {
        // Prevent moving a folder into itself
        guard draggedFolder.id != targetFolder.id else { return }
        
        // Prevent moving a folder into one of its descendants
        guard !isDescendant(targetFolder, of: draggedFolder) else { return }
        
        draggedFolder.parentID = targetFolder.id
        try? context.save()
    }
    
    func moveFile(_ file: LibraryFile, into targetFolder: LibraryFolder) {
        file.parentFolderID = targetFolder.id
        try? context.save()
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
    
    // MARK: - Additional Actions
    
    func duplicateFolder() {
        let duplicate = LibraryFolder(
            name: "\(folder.name) Copy",
            parentID: folder.parentID,
            colorHex: folder.colorHex
        )
        context.insert(duplicate)
        try? context.save()
    }
    
    func showInFinder() {
        showingInfo = true
    }
    
    // MARK: - Color Picker Sheet
    
    var colorPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 50))
                            .foregroundColor(folderColor)
                        
                        Text("Choose Folder Color")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(folder.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Color Grid
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 16)
                    ], spacing: 16) {
                        ForEach(folderColors, id: \.name) { colorOption in
                            colorOptionButton(colorOption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reset to default
                    Button {
                        folder.colorHex = nil
                        try? context.save()
                        showingColorPicker = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Folder Color")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingColorPicker = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }
    
    func colorOptionButton(_ colorOption: (name: String, hex: String, color: Color)) -> some View {
        let isSelected = folder.colorHex == colorOption.hex
        
        return Button {
            folder.colorHex = colorOption.hex
            try? context.save()
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorOption.color.opacity(0.3),
                                    colorOption.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? colorOption.color : colorOption.color.opacity(0.3),
                                    lineWidth: isSelected ? 4 : 2
                                )
                        )
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colorOption.color, colorOption.color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colorOption.color)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 18, height: 18)
                                    )
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(colorOption.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? colorOption.color : .primary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    // MARK: - Folder Info Sheet
    
    var folderInfoSheet: some View {
        let fileCount = allFiles.filter { $0.parentFolderID == folder.id }.count
        let subfolderCount = allFolders.filter { $0.parentID == folder.id }.count
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Folder Preview
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            folderColor.opacity(0.3),
                                            folderColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [folderColor, folderColor.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        VStack(spacing: 4) {
                            Text(folder.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [folderColor.opacity(0.1), folderColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Info Sections
                    VStack(spacing: 16) {
                        // Contents Section
                        infoCard(
                            title: "Contents",
                            items: [
                                (icon: "doc.fill", label: "Files", value: "\(fileCount)"),
                                (icon: "folder.fill", label: "Subfolders", value: "\(subfolderCount)")
                            ]
                        )
                        
                        // Details Section
                        infoCard(
                            title: "Details",
                            items: [
                                (icon: "tag.fill", label: "Color", value: folderColorName),
                                (icon: "number", label: "ID", value: folder.id.uuidString.prefix(8) + "...")
                            ]
                        )
                        
                        // Location Section
                        if let parentFolder = allFolders.first(where: { $0.id == folder.parentID }) {
                            infoCard(
                                title: "Location",
                                items: [
                                    (icon: "folder.fill", label: "Parent", value: parentFolder.name)
                                ]
                            )
                        } else {
                            infoCard(
                                title: "Location",
                                items: [
                                    (icon: "house.fill", label: "Parent", value: "Root")
                                ]
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Folder Info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingInfo = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 550)
        #endif
    }
    
    var folderColorName: String {
        guard let hex = folder.colorHex else { return "Blue (Default)" }
        return folderColors.first(where: { $0.hex == hex })?.name ?? "Custom"
    }
    
    func infoCard(title: String, items: [(icon: String, label: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.body)
                            .foregroundColor(folderColor)
                            .frame(width: 24)
                        
                        Text(item.label)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(item.value)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding()
                    
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        
        guard hex.count == 6 else { return nil }
        
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - PDF Card

struct PDFCardView: View {
    @Bindable var file: LibraryFile
    let isRenaming: Bool
    let onRename: () -> Void
    let onEndRename: () -> Void
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var editingName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    // Delete confirmation
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 8) {
            // PDF Thumbnail
            NavigationLink(destination: PDFViewerView(file: file)) {
                ZStack {
                    // Thumbnail background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(isHovered ? 0.4 : 0.2), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, x: 0, y: 2)
                    
                    // PDF Thumbnail
                    if let thumbnail = generateThumbnail(from: file.pdfData) {
                        #if os(macOS)
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        #else
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        #endif
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }
                    
                    // Tags badge
                    if file.linkedSubject != nil || file.linkedUnit != nil {
                        VStack {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    
                    // Quick action overlay on hover
                    if isHovered {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                            
                            VStack(spacing: 12) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                
                                Text(languageManager.localized("Open PDF"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .opacity(isDragging ? 0.5 : 1.0)
            .onDrag {
                isDragging = true
                return NSItemProvider(object: "file:\(file.id.uuidString)" as NSString)
            }
            
            // File Name (editable)
            if isRenaming {
                TextField(languageManager.localized("File name"), text: $editingName, onCommit: {
                    saveRename()
                })
                .textFieldStyle(.plain)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
                .focused($isTextFieldFocused)
                .onAppear {
                    editingName = file.name
                    isTextFieldFocused = true
                }
            } else {
                VStack(spacing: 2) {
                    Text(file.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    // Subject/Unit tags
                    if let subject = file.linkedSubject {
                        Text(subject.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 44)
            }
        }
        .frame(width: 180)
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label(languageManager.localized("Rename"), systemImage: "pencil")
            }
            
            Button {
                // TODO: Edit tags
            } label: {
                Label(languageManager.localized("Edit Tags"), systemImage: "tag")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label(languageManager.localized("Delete"), systemImage: "trash")
            }
        }
        .alert(languageManager.localized("Delete PDF?"), isPresented: $showingDeleteAlert) {
            Button(languageManager.localized("Cancel"), role: .cancel) {}
            
            Button(languageManager.localized("Delete"), role: .destructive) {
                deleteFile()
            }
        } message: {
            Text(String(
                format: languageManager.localized("Are you sure you want to delete \"%@\"? This action cannot be undone."),
                file.name
            ))
        }
    }
    
    func saveRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            file.name = trimmed
            try? context.save()
        }
        onEndRename()
    }
    
    func deleteFile() {
        context.delete(file)
        try? context.save()
    }
    
    // MARK: - Thumbnail Generation
    
    #if os(macOS)
    func generateThumbnail(from pdfData: Data) -> NSImage? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 180, height: 200)
        
        // Calculate scale to fill the thumbnail area
        let scale = max(
            thumbnailSize.width / pageRect.width,
            thumbnailSize.height / pageRect.height
        )
        
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        firstPage.draw(with: .mediaBox, to: NSGraphicsContext.current!.cgContext)
        
        image.unlockFocus()
        
        return image
    }
    #else
    func generateThumbnail(from pdfData: Data) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 180, height: 200)
        
        // Calculate scale to fill the thumbnail area
        let scale = max(
            thumbnailSize.width / pageRect.width,
            thumbnailSize.height / pageRect.height
        )
        
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.interpolationQuality = .high
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
    #endif
}

// MARK: - Selectable Cards

struct SelectableFolderCard: View {
    let folder: LibraryFolder
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(isSelected ? 0.5 : 0.3),
                                    Color.blue.opacity(isSelected ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSelected ? Color.blue : Color.blue.opacity(0.2),
                                    lineWidth: isSelected ? 4 : 2
                                )
                        )
                        .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.08), radius: isSelected ? 12 : 4, x: 0, y: 2)
                        .scaleEffect(isSelected ? 0.97 : 1.0)
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Selection indicator
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 32, height: 32)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(folder.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .frame(height: 36)
            }
            .frame(width: 180)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct SelectablePDFCard: View {
    let file: LibraryFile
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSelected ? Color.blue : Color.gray.opacity(0.2),
                                    lineWidth: isSelected ? 4 : 2
                                )
                        )
                        .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.08), radius: isSelected ? 12 : 4, x: 0, y: 2)
                        .scaleEffect(isSelected ? 0.97 : 1.0)
                    
                    // PDF Thumbnail
                    if let thumbnail = generateThumbnail(from: file.pdfData) {
                        #if os(macOS)
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .opacity(isSelected ? 0.7 : 1.0)
                        #else
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .opacity(isSelected ? 0.7 : 1.0)
                        #endif
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }
                    
                    // Selection overlay
                    if isSelected {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.2))
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(file.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .frame(height: 36)
            }
            .frame(width: 180)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    #if os(macOS)
    func generateThumbnail(from pdfData: Data) -> NSImage? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 180, height: 200)
        
        let scale = max(
            thumbnailSize.width / pageRect.width,
            thumbnailSize.height / pageRect.height
        )
        
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        firstPage.draw(with: .mediaBox, to: NSGraphicsContext.current!.cgContext)
        
        image.unlockFocus()
        
        return image
    }
    #else
    func generateThumbnail(from pdfData: Data) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 180, height: 200)
        
        let scale = max(
            thumbnailSize.width / pageRect.width,
            thumbnailSize.height / pageRect.height
        )
        
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.interpolationQuality = .high
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
    #endif
}
