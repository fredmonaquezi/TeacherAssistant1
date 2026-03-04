import Foundation

#if BACKUP_VERIFY

struct RetainedSnapshotFile {
    let url: URL
    let createdAt: Date
}

enum SnapshotRetentionPolicy {
    static func urlsToKeep(
        files: [RetainedSnapshotFile],
        keepLatestCount: Int,
        keepOnePerDayForLastDays: Int,
        now: Date,
        calendar: Calendar
    ) -> Set<URL> {
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: -keepOnePerDayForLastDays,
            to: now
        ) ?? .distantPast

        let sortedFiles = files.sorted { $0.createdAt > $1.createdAt }
        var keptURLs = Set(sortedFiles.prefix(keepLatestCount).map(\.url))
        var keptDays: Set<Date> = []

        for file in sortedFiles.dropFirst(keepLatestCount) {
            guard file.createdAt >= cutoffDate else { continue }

            let day = calendar.startOfDay(for: file.createdAt)
            if keptDays.insert(day).inserted {
                keptURLs.insert(file.url)
            }
        }

        return keptURLs
    }

    static func urlsToKeepNewest(
        files: [RetainedSnapshotFile],
        keepLatestCount: Int
    ) -> Set<URL> {
        Set(
            files
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(keepLatestCount)
                .map(\.url)
        )
    }
}

@main
struct SnapshotRetentionVerifier {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_709_478_000)

        do {
            let files = makeSyntheticFiles(now: now, calendar: calendar)
            let keptURLs = SnapshotRetentionPolicy.urlsToKeep(
                files: files,
                keepLatestCount: 3,
                keepOnePerDayForLastDays: 3,
                now: now,
                calendar: calendar
            )

            try require(keptURLs.count == 5, "Expected 5 retained files, got \(keptURLs.count)")
            try require(keptURLs.contains(url(named: "snapshot-0.backup")), "Newest snapshot was not kept")
            try require(keptURLs.contains(url(named: "snapshot-1.backup")), "Second newest snapshot was not kept")
            try require(keptURLs.contains(url(named: "snapshot-2.backup")), "Third newest snapshot was not kept")
            try require(keptURLs.contains(url(named: "snapshot-3.backup")), "Daily retained snapshot for day -1 missing")
            try require(keptURLs.contains(url(named: "snapshot-5.backup")), "Daily retained snapshot for day -2 missing")

            let newestOnly = SnapshotRetentionPolicy.urlsToKeepNewest(
                files: files,
                keepLatestCount: 2
            )
            try require(newestOnly.count == 2, "Expected 2 newest-only retained files")
            try require(newestOnly.contains(url(named: "snapshot-0.backup")), "Newest-only retention missed latest file")
            try require(newestOnly.contains(url(named: "snapshot-1.backup")), "Newest-only retention missed second file")

            print("RESULT: PASS")
            print("  - Snapshot retention keeps newest files plus one-per-day history")
            print("  - External retention keeps only the newest N files")
        } catch {
            print("RESULT: FAIL")
            print("  - \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func makeSyntheticFiles(now: Date, calendar: Calendar) -> [RetainedSnapshotFile] {
        [
            RetainedSnapshotFile(url: url(named: "snapshot-0.backup"), createdAt: now),
            RetainedSnapshotFile(url: url(named: "snapshot-1.backup"), createdAt: now.addingTimeInterval(-3_600)),
            RetainedSnapshotFile(url: url(named: "snapshot-2.backup"), createdAt: now.addingTimeInterval(-7_200)),
            RetainedSnapshotFile(url: url(named: "snapshot-3.backup"), createdAt: calendar.date(byAdding: .day, value: -1, to: now)!),
            RetainedSnapshotFile(url: url(named: "snapshot-4.backup"), createdAt: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(-3_600)),
            RetainedSnapshotFile(url: url(named: "snapshot-5.backup"), createdAt: calendar.date(byAdding: .day, value: -2, to: now)!),
            RetainedSnapshotFile(url: url(named: "snapshot-6.backup"), createdAt: calendar.date(byAdding: .day, value: -4, to: now)!),
        ]
    }

    private static func url(named name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(
                domain: "SnapshotRetentionVerifier",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

#endif
