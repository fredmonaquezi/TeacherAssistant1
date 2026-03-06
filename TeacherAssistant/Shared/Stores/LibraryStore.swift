import Foundation

struct LibraryDerivedData {
    let folder: LibraryFolder?
    let subfolders: [LibraryFolder]
    let files: [LibraryFile]
    let matchingFolders: [LibraryFolder]
    let matchingFiles: [LibraryFile]
    let folderByID: [UUID: LibraryFolder]
    let fileCountByParent: [UUID: Int]
    let subfolderCountByParent: [UUID: Int]

    static let empty = LibraryDerivedData(
        folder: nil,
        subfolders: [],
        files: [],
        matchingFolders: [],
        matchingFiles: [],
        folderByID: [:],
        fileCountByParent: [:],
        subfolderCountByParent: [:]
    )
}

enum LibraryStore {
    static func derive(
        allFolders: [LibraryFolder],
        allFiles: [LibraryFile],
        folderID: UUID,
        searchText: String
    ) -> LibraryDerivedData {
        let folder = allFolders.first { $0.id == folderID }
        let folderByID = Dictionary(uniqueKeysWithValues: allFolders.map { ($0.id, $0) })
        let fileByID = Dictionary(uniqueKeysWithValues: allFiles.map { ($0.id, $0) })
        let fileCountByParent = allFiles.reduce(into: [UUID: Int]()) { partialResult, file in
            partialResult[file.parentFolderID, default: 0] += 1
        }
        let subfolderCountByParent = allFolders.reduce(into: [UUID: Int]()) { partialResult, folder in
            guard let parentID = folder.parentID else { return }
            partialResult[parentID, default: 0] += 1
        }
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let computation = computeLibraryDerivation(
            folderSnapshots: makeFolderSnapshots(allFolders),
            fileSnapshots: makeFileSnapshots(allFiles),
            folderID: folderID,
            normalizedSearch: normalizedSearch
        )
        return makeDerivedData(
            folder: folder,
            folderByID: folderByID,
            fileByID: fileByID,
            fileCountByParent: fileCountByParent,
            subfolderCountByParent: subfolderCountByParent,
            computation: computation
        )
    }

    static func deriveAsync(
        allFolders: [LibraryFolder],
        allFiles: [LibraryFile],
        folderID: UUID,
        searchText: String
    ) async -> LibraryDerivedData {
        let folder = allFolders.first { $0.id == folderID }
        let folderByID = Dictionary(uniqueKeysWithValues: allFolders.map { ($0.id, $0) })
        let fileByID = Dictionary(uniqueKeysWithValues: allFiles.map { ($0.id, $0) })
        let fileCountByParent = allFiles.reduce(into: [UUID: Int]()) { partialResult, file in
            partialResult[file.parentFolderID, default: 0] += 1
        }
        let subfolderCountByParent = allFolders.reduce(into: [UUID: Int]()) { partialResult, folder in
            guard let parentID = folder.parentID else { return }
            partialResult[parentID, default: 0] += 1
        }
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let folderSnapshots = makeFolderSnapshots(allFolders)
        let fileSnapshots = makeFileSnapshots(allFiles)

        let computation = await Task.detached(priority: .userInitiated) {
            computeLibraryDerivation(
                folderSnapshots: folderSnapshots,
                fileSnapshots: fileSnapshots,
                folderID: folderID,
                normalizedSearch: normalizedSearch
            )
        }.value

        if Task.isCancelled {
            return .empty
        }

        return makeDerivedData(
            folder: folder,
            folderByID: folderByID,
            fileByID: fileByID,
            fileCountByParent: fileCountByParent,
            subfolderCountByParent: subfolderCountByParent,
            computation: computation
        )
    }

    private static func makeFolderSnapshots(_ folders: [LibraryFolder]) -> [LibraryFolderSnapshot] {
        folders.map { folder in
            LibraryFolderSnapshot(
                id: folder.id,
                parentID: folder.parentID,
                normalizedName: folder.name.lowercased()
            )
        }
    }

    private static func makeFileSnapshots(_ files: [LibraryFile]) -> [LibraryFileSnapshot] {
        files.map { file in
            LibraryFileSnapshot(
                id: file.id,
                parentFolderID: file.parentFolderID,
                normalizedName: file.name.lowercased()
            )
        }
    }

    nonisolated private static func computeLibraryDerivation(
        folderSnapshots: [LibraryFolderSnapshot],
        fileSnapshots: [LibraryFileSnapshot],
        folderID: UUID,
        normalizedSearch: String
    ) -> LibraryDerivationComputation {
        let subfolderIDs = folderSnapshots
            .filter { $0.parentID == folderID }
            .map(\.id)
        let fileIDs = fileSnapshots
            .filter { $0.parentFolderID == folderID }
            .map(\.id)

        let matchingFolderIDs: [UUID]
        let matchingFileIDs: [UUID]

        if normalizedSearch.isEmpty {
            matchingFolderIDs = []
            matchingFileIDs = []
        } else {
            matchingFolderIDs = folderSnapshots
                .filter { $0.normalizedName.contains(normalizedSearch) }
                .map(\.id)
            matchingFileIDs = fileSnapshots
                .filter { $0.normalizedName.contains(normalizedSearch) }
                .map(\.id)
        }

        return LibraryDerivationComputation(
            subfolderIDs: subfolderIDs,
            fileIDs: fileIDs,
            matchingFolderIDs: matchingFolderIDs,
            matchingFileIDs: matchingFileIDs
        )
    }

    private static func makeDerivedData(
        folder: LibraryFolder?,
        folderByID: [UUID: LibraryFolder],
        fileByID: [UUID: LibraryFile],
        fileCountByParent: [UUID: Int],
        subfolderCountByParent: [UUID: Int],
        computation: LibraryDerivationComputation
    ) -> LibraryDerivedData {
        let subfolders = computation.subfolderIDs.compactMap { folderByID[$0] }
        let files = computation.fileIDs.compactMap { fileByID[$0] }
        let matchingFolders = computation.matchingFolderIDs.compactMap { folderByID[$0] }
        let matchingFiles = computation.matchingFileIDs.compactMap { fileByID[$0] }

        return LibraryDerivedData(
            folder: folder,
            subfolders: subfolders,
            files: files,
            matchingFolders: matchingFolders,
            matchingFiles: matchingFiles,
            folderByID: folderByID,
            fileCountByParent: fileCountByParent,
            subfolderCountByParent: subfolderCountByParent
        )
    }
}

private struct LibraryFolderSnapshot: Sendable {
    let id: UUID
    let parentID: UUID?
    let normalizedName: String
}

private struct LibraryFileSnapshot: Sendable {
    let id: UUID
    let parentFolderID: UUID
    let normalizedName: String
}

private struct LibraryDerivationComputation: Sendable {
    let subfolderIDs: [UUID]
    let fileIDs: [UUID]
    let matchingFolderIDs: [UUID]
    let matchingFileIDs: [UUID]
}
