import Foundation
import SwiftData

@MainActor
final class SnapshotManager {
    static let shared = SnapshotManager()

    private enum AppVersionKeys {
        static let lastLaunchedVersion = "ta_last_launched_app_version"
    }

    private let debounceDelayNanoseconds: UInt64 = 45_000_000_000
    private let automaticSnapshotBaseName = "TeacherAssistant-AutoSnapshot"
    private let snapshotRetentionCount = 20
    private let snapshotRetentionDays = 30

    private var pendingSnapshotTask: Task<Void, Never>?
    private var hasPendingSnapshotRequest = false

    private init() { }

    func captureUpgradeSnapshotIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let previousVersion = defaults.string(forKey: AppVersionKeys.lastLaunchedVersion)

        defer {
            defaults.set(currentVersion, forKey: AppVersionKeys.lastLaunchedVersion)
        }

        guard let previousVersion, previousVersion != currentVersion else {
            return
        }

        do {
            let directory = try automaticSnapshotDirectory()
            let snapshotURL = try BackupManager.createPersistentSnapshot(
                context: context,
                baseName: "TeacherAssistant-Upgrade-\(sanitizedVersion(previousVersion))-to-\(sanitizedVersion(currentVersion))",
                directory: directory
            )
            pruneSnapshots(in: directory)
            OffDeviceBackupManager.shared.mirrorSnapshotIfEnabled(
                snapshotURL: snapshotURL,
                trigger: "upgrade"
            )
            SecureLogger.info("Created upgrade snapshot: \(snapshotURL.lastPathComponent)")
        } catch {
            SecureLogger.error("Upgrade snapshot failed", error: error)
        }
    }

    func scheduleDebouncedSnapshot(context: ModelContext, reason: String) {
        let delay = debounceDelayNanoseconds
        hasPendingSnapshotRequest = true
        pendingSnapshotTask?.cancel()

        pendingSnapshotTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.captureSnapshotIfNeeded(
                context: context,
                trigger: "save:\(reason)"
            )
        }
    }

    func captureLifecycleSnapshotIfNeeded(context: ModelContext, trigger: String) {
        pendingSnapshotTask?.cancel()
        pendingSnapshotTask = nil

        guard hasPendingSnapshotRequest || context.hasChanges else {
            return
        }

        captureSnapshotIfNeeded(context: context, trigger: trigger)
    }

    private func captureSnapshotIfNeeded(context: ModelContext, trigger: String) {
        guard hasPendingSnapshotRequest || context.hasChanges else {
            return
        }

        do {
            let directory = try automaticSnapshotDirectory()
            let snapshotURL = try BackupManager.createPersistentSnapshot(
                context: context,
                baseName: automaticSnapshotBaseName,
                directory: directory
            )

            hasPendingSnapshotRequest = false
            pruneSnapshots(in: directory)
            OffDeviceBackupManager.shared.mirrorSnapshotIfEnabled(
                snapshotURL: snapshotURL,
                trigger: trigger
            )

            SecureLogger.debug(
                "Created automatic snapshot (\(trigger)): \(snapshotURL.lastPathComponent)"
            )
        } catch {
            SecureLogger.error("Automatic snapshot failed (\(trigger))", error: error)
        }
    }

    private func automaticSnapshotDirectory() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleDirectory = applicationSupportDirectory.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "TeacherAssistant",
            isDirectory: true
        )
        let snapshotDirectory = bundleDirectory.appendingPathComponent(
            "AutomaticSnapshots",
            isDirectory: true
        )

        if !FileManager.default.fileExists(atPath: snapshotDirectory.path) {
            try FileManager.default.createDirectory(
                at: snapshotDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return snapshotDirectory
    }

    private func pruneSnapshots(in directory: URL) {
        let resourceKeys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey]
        let calendar = Calendar.autoupdatingCurrent

        do {
            let snapshotFiles = try FileManager.default.contentsOfDirectory(
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

            let keptURLs = SnapshotRetentionPolicy.urlsToKeep(
                files: snapshotFiles,
                keepLatestCount: snapshotRetentionCount,
                keepOnePerDayForLastDays: snapshotRetentionDays,
                now: Date(),
                calendar: calendar
            )

            for snapshot in snapshotFiles where !keptURLs.contains(snapshot.url) {
                try FileManager.default.removeItem(at: snapshot.url)
            }
        } catch {
            SecureLogger.warning("Failed to prune automatic snapshots")
        }
    }

    private func sanitizedVersion(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { partialResult, character in
            partialResult.append(character)
        }
    }
}
