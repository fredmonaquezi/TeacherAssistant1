import Foundation

struct RetainedSnapshotFile {
    let url: URL
    let createdAt: Date
}

enum SnapshotRetentionPolicy {
    static func urlsToKeep(
        files: [RetainedSnapshotFile],
        keepLatestCount: Int,
        keepOnePerDayForLastDays: Int,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
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
