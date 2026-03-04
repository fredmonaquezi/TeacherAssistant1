import Foundation

@MainActor
final class OffDeviceBackupManager {
    static let shared = OffDeviceBackupManager()

    private let externalRetentionCount = 10

    private init() { }

    var destinationDisplayPath: String? {
        UserDefaults.standard.string(forKey: AppPreferencesKeys.offDeviceBackupPath)
    }

    var isEnabled: Bool {
        UserDefaults.standard.data(forKey: AppPreferencesKeys.offDeviceBackupBookmark) != nil
    }

    func storeDestination(url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let defaults = UserDefaults.standard
        defaults.set(bookmark, forKey: AppPreferencesKeys.offDeviceBackupBookmark)
        defaults.set(url.path, forKey: AppPreferencesKeys.offDeviceBackupPath)
    }

    func clearDestination() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppPreferencesKeys.offDeviceBackupBookmark)
        defaults.removeObject(forKey: AppPreferencesKeys.offDeviceBackupPath)
    }

    func mirrorSnapshotIfEnabled(snapshotURL: URL, trigger: String) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: AppPreferencesKeys.offDeviceBackupBookmark) else {
            return
        }

        do {
            var isStale = false
            let destinationDirectory = try URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try storeDestination(url: destinationDirectory)
            }

            let didStartAccessing = destinationDirectory.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    destinationDirectory.stopAccessingSecurityScopedResource()
                }
            }

            let destinationURL = destinationDirectory.appendingPathComponent(snapshotURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: snapshotURL, to: destinationURL)
            pruneBackups(in: destinationDirectory)

            SecureLogger.debug(
                "Mirrored snapshot to off-device folder (\(trigger)): \(destinationURL.lastPathComponent)"
            )
        } catch {
            SecureLogger.error("Off-device backup mirror failed (\(trigger))", error: error)
        }
    }

    private func pruneBackups(in directory: URL) {
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey]

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "backup" }
            .compactMap { url -> RetainedSnapshotFile? in
                let values = try? url.resourceValues(forKeys: resourceKeys)
                guard let createdAt = values?.contentModificationDate ?? values?.creationDate else {
                    return nil
                }
                return RetainedSnapshotFile(url: url, createdAt: createdAt)
            }

            let keptURLs = SnapshotRetentionPolicy.urlsToKeepNewest(
                files: files,
                keepLatestCount: externalRetentionCount
            )

            for file in files where !keptURLs.contains(file.url) {
                try FileManager.default.removeItem(at: file.url)
            }
        } catch {
            SecureLogger.warning("Failed to prune off-device backups")
        }
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return .withSecurityScope
        #else
        return []
        #endif
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }
}
