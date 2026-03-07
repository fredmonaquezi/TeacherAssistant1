import Foundation
import SwiftData

enum LibraryFolderCardActions {
    static func saveRename(
        folder: LibraryFolder,
        editingName: String,
        context: ModelContext
    ) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        folder.name = trimmed
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Rename library folder")
        }
    }

    static func deleteFolder(
        folder: LibraryFolder,
        context: ModelContext
    ) {
        context.delete(folder)
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Delete library folder")
        }
    }

    static func duplicateFolder(
        folder: LibraryFolder,
        context: ModelContext
    ) {
        let duplicate = LibraryFolder(
            name: "\(folder.name) Copy",
            parentID: folder.parentID,
            colorHex: folder.colorHex
        )
        context.insert(duplicate)
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Duplicate library folder")
        }
    }

    static func moveDraggedItem(
        payload: String,
        allFolders: [LibraryFolder],
        allFiles: [LibraryFile],
        targetFolder: LibraryFolder,
        folderByID: [UUID: LibraryFolder],
        context: ModelContext
    ) {
        if payload.hasPrefix("folder:") {
            let idString = String(payload.dropFirst("folder:".count))
            guard let uuid = UUID(uuidString: idString),
                  let draggedFolder = allFolders.first(where: { $0.id == uuid }) else {
                return
            }
            moveFolder(
                draggedFolder,
                into: targetFolder,
                folderByID: folderByID,
                context: context
            )
            return
        }

        if payload.hasPrefix("file:") {
            let idString = String(payload.dropFirst("file:".count))
            guard let uuid = UUID(uuidString: idString),
                  let draggedFile = allFiles.first(where: { $0.id == uuid }) else {
                return
            }
            moveFile(draggedFile, into: targetFolder, context: context)
        }
    }

    private static func moveFolder(
        _ draggedFolder: LibraryFolder,
        into targetFolder: LibraryFolder,
        folderByID: [UUID: LibraryFolder],
        context: ModelContext
    ) {
        guard draggedFolder.id != targetFolder.id else { return }
        guard !isDescendant(targetFolder, of: draggedFolder, folderByID: folderByID) else { return }

        draggedFolder.parentID = targetFolder.id
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Move library folder")
        }
    }

    private static func moveFile(
        _ file: LibraryFile,
        into targetFolder: LibraryFolder,
        context: ModelContext
    ) {
        file.parentFolderID = targetFolder.id
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Move library file")
        }
    }

    private static func isDescendant(
        _ possibleChild: LibraryFolder,
        of parent: LibraryFolder,
        folderByID: [UUID: LibraryFolder]
    ) -> Bool {
        var currentParentID = possibleChild.parentID

        while let parentID = currentParentID {
            if parentID == parent.id {
                return true
            }
            currentParentID = folderByID[parentID]?.parentID
        }

        return false
    }
}

enum LibraryPDFCardActions {
    static func saveRename(
        file: LibraryFile,
        editingName: String,
        context: ModelContext
    ) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        file.name = trimmed
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Rename library file")
        }
    }

    static func deleteFile(
        file: LibraryFile,
        context: ModelContext
    ) {
        context.delete(file)
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Delete library file")
        }
    }
}
