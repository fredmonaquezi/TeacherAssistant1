import Foundation
import SwiftData

struct RunningRecordsDerivedData {
    let classOptions: [SchoolClass]
    let studentOptions: [Student]
    let sortedRecords: [RunningRecord]
    let uniqueStudentsCount: Int
    let averageAccuracy: Double
    let filteredAverageAccuracy: Double
    let levelCounts: (independent: Int, instructional: Int, frustration: Int)

    static let empty = RunningRecordsDerivedData(
        classOptions: [],
        studentOptions: [],
        sortedRecords: [],
        uniqueStudentsCount: 0,
        averageAccuracy: 0,
        filteredAverageAccuracy: 0,
        levelCounts: (0, 0, 0)
    )
}

enum RunningRecordsStore {
    static func derive(
        allStudents: [Student],
        allRunningRecords: [RunningRecord],
        selectedClass: SchoolClass?,
        selectedStudent: Student?,
        filterLevel: ReadingLevel?,
        selectedDateRange: RunningRecordDateRangePreset,
        customDateStart: Date,
        customDateEnd: Date,
        sortOption: RunningRecordSortOption,
        searchText: String
    ) -> RunningRecordsDerivedData {
        let classOptions = makeClassOptions(allStudents: allStudents)
        let studentOptions = makeStudentOptions(allStudents: allStudents, selectedClass: selectedClass)
        let snapshots = makeRunningRecordSnapshots(allRunningRecords)
        let computation = computeRecordDerivation(
            snapshots: snapshots,
            selectedClassKey: selectedClass.map { String(describing: $0.id) },
            selectedStudentUUID: selectedStudent?.uuid,
            filterLevel: filterLevel,
            selectedDateRange: selectedDateRange,
            normalizedCustomRange: normalizedCustomRange(start: customDateStart, end: customDateEnd),
            sortOption: sortOption,
            trimmedQuery: searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )

        return makeDerivedData(
            classOptions: classOptions,
            studentOptions: studentOptions,
            allRunningRecords: allRunningRecords,
            computation: computation
        )
    }

    static func deriveAsync(
        allStudents: [Student],
        allRunningRecords: [RunningRecord],
        selectedClass: SchoolClass?,
        selectedStudent: Student?,
        filterLevel: ReadingLevel?,
        selectedDateRange: RunningRecordDateRangePreset,
        customDateStart: Date,
        customDateEnd: Date,
        sortOption: RunningRecordSortOption,
        searchText: String
    ) async -> RunningRecordsDerivedData {
        let classOptions = makeClassOptions(allStudents: allStudents)
        let studentOptions = makeStudentOptions(allStudents: allStudents, selectedClass: selectedClass)
        let snapshots = makeRunningRecordSnapshots(allRunningRecords)
        let selectedClassKey = selectedClass.map { String(describing: $0.id) }
        let selectedStudentUUID = selectedStudent?.uuid
        let normalizedRange = normalizedCustomRange(start: customDateStart, end: customDateEnd)
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return await DerivationRunner.runAsync(
            compute: {
                computeRecordDerivation(
                    snapshots: snapshots,
                    selectedClassKey: selectedClassKey,
                    selectedStudentUUID: selectedStudentUUID,
                    filterLevel: filterLevel,
                    selectedDateRange: selectedDateRange,
                    normalizedCustomRange: normalizedRange,
                    sortOption: sortOption,
                    trimmedQuery: trimmedQuery
                )
            },
            cancelledResult: .empty
        ) { computation in
            makeDerivedData(
                classOptions: classOptions,
                studentOptions: studentOptions,
                allRunningRecords: allRunningRecords,
                computation: computation
            )
        }
    }

    private static func normalizedCustomRange(start: Date, end: Date) -> (start: Date, end: Date) {
        let startDay = Calendar.current.startOfDay(for: start)
        let endDayStart = Calendar.current.startOfDay(for: end)
        let endDay = Calendar.current.date(byAdding: .day, value: 1, to: endDayStart)?.addingTimeInterval(-1) ?? endDayStart
        return startDay <= endDay ? (startDay, endDay) : (endDay, startDay)
    }

    private static func classDisplayName(_ schoolClass: SchoolClass) -> String {
        if schoolClass.grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return schoolClass.name
        }
        return "\(schoolClass.name) (\(schoolClass.grade))"
    }

    private static func makeClassOptions(allStudents: [Student]) -> [SchoolClass] {
        var seenClassKeys: Set<String> = []
        var classOptions: [SchoolClass] = []

        for student in allStudents {
            guard let schoolClass = student.schoolClass else { continue }
            let key = String(describing: schoolClass.id)
            if seenClassKeys.insert(key).inserted {
                classOptions.append(schoolClass)
            }
        }

        classOptions.sort { lhs, rhs in
            classDisplayName(lhs) < classDisplayName(rhs)
        }

        return classOptions
    }

    private static func makeStudentOptions(
        allStudents: [Student],
        selectedClass: SchoolClass?
    ) -> [Student] {
        var seenStudentIDs: Set<PersistentIdentifier> = []
        return allStudents
            .filter { student in
                guard let selectedClass else { return true }
                return student.schoolClass?.id == selectedClass.id
            }
            .filter { student in
                seenStudentIDs.insert(student.id).inserted
            }
            .sorted {
                if $0.name.caseInsensitiveCompare($1.name) == .orderedSame {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func makeRunningRecordSnapshots(_ records: [RunningRecord]) -> [RunningRecordSnapshot] {
        records.enumerated().map { index, record in
            RunningRecordSnapshot(
                index: index,
                classKey: record.student?.schoolClass.map { String(describing: $0.id) },
                studentUUID: record.student?.uuid,
                date: record.date,
                readingLevel: record.readingLevel,
                searchableText: record.searchableText,
                accuracy: record.accuracy,
                studentDisplayName: record.studentDisplayName
            )
        }
    }

    nonisolated private static func computeRecordDerivation(
        snapshots: [RunningRecordSnapshot],
        selectedClassKey: String?,
        selectedStudentUUID: UUID?,
        filterLevel: ReadingLevel?,
        selectedDateRange: RunningRecordDateRangePreset,
        normalizedCustomRange: (start: Date, end: Date),
        sortOption: RunningRecordSortOption,
        trimmedQuery: String
    ) -> RunningRecordComputation {
        var filtered = snapshots

        if let selectedClassKey {
            filtered = filtered.filter { $0.classKey == selectedClassKey }
        }

        if let selectedStudentUUID {
            filtered = filtered.filter { $0.studentUUID == selectedStudentUUID }
        }

        if let filterLevel {
            filtered = filtered.filter { $0.readingLevel == filterLevel }
        }

        filtered = filtered.filter { snapshot in
            let customStart = selectedDateRange == .custom ? normalizedCustomRange.start : nil
            let customEnd = selectedDateRange == .custom ? normalizedCustomRange.end : nil
            return selectedDateRange.includes(snapshot.date, customStartDate: customStart, customEndDate: customEnd)
        }

        if !trimmedQuery.isEmpty {
            filtered = filtered.filter { $0.searchableText.contains(trimmedQuery) }
        }

        let sortedSnapshots = filtered.sorted { lhs, rhs in
            switch sortOption {
            case .dateDescending:
                if lhs.date == rhs.date { return lhs.index < rhs.index }
                return lhs.date > rhs.date
            case .dateAscending:
                if lhs.date == rhs.date { return lhs.index < rhs.index }
                return lhs.date < rhs.date
            case .accuracyDescending:
                if lhs.accuracy == rhs.accuracy { return lhs.index < rhs.index }
                return lhs.accuracy > rhs.accuracy
            case .accuracyAscending:
                if lhs.accuracy == rhs.accuracy { return lhs.index < rhs.index }
                return lhs.accuracy < rhs.accuracy
            case .studentAscending:
                let order = lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName)
                if order == .orderedSame { return lhs.index < rhs.index }
                return order == .orderedAscending
            case .studentDescending:
                let order = lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName)
                if order == .orderedSame { return lhs.index < rhs.index }
                return order == .orderedDescending
            }
        }

        let filteredAverageAccuracy: Double
        if sortedSnapshots.isEmpty {
            filteredAverageAccuracy = 0
        } else {
            let total = sortedSnapshots.reduce(0.0) { partial, snapshot in
                partial + snapshot.accuracy
            }
            filteredAverageAccuracy = total / Double(sortedSnapshots.count)
        }

        let levelCounts = sortedSnapshots.reduce(into: (independent: 0, instructional: 0, frustration: 0)) { counts, snapshot in
            switch snapshot.readingLevel {
            case .independent:
                counts.independent += 1
            case .instructional:
                counts.instructional += 1
            case .frustration:
                counts.frustration += 1
            }
        }

        let uniqueStudentsCount = Set(snapshots.compactMap(\.studentUUID)).count
        let averageAccuracy: Double
        if snapshots.isEmpty {
            averageAccuracy = 0
        } else {
            let total = snapshots.reduce(0.0) { partial, snapshot in
                partial + snapshot.accuracy
            }
            averageAccuracy = total / Double(snapshots.count)
        }

        return RunningRecordComputation(
            sortedIndices: sortedSnapshots.map(\.index),
            uniqueStudentsCount: uniqueStudentsCount,
            averageAccuracy: averageAccuracy,
            filteredAverageAccuracy: filteredAverageAccuracy,
            levelCounts: levelCounts
        )
    }

    private static func makeDerivedData(
        classOptions: [SchoolClass],
        studentOptions: [Student],
        allRunningRecords: [RunningRecord],
        computation: RunningRecordComputation
    ) -> RunningRecordsDerivedData {
        let sortedRecords: [RunningRecord] = computation.sortedIndices.compactMap { index in
            guard allRunningRecords.indices.contains(index) else { return nil }
            return allRunningRecords[index]
        }

        return RunningRecordsDerivedData(
            classOptions: classOptions,
            studentOptions: studentOptions,
            sortedRecords: sortedRecords,
            uniqueStudentsCount: computation.uniqueStudentsCount,
            averageAccuracy: computation.averageAccuracy,
            filteredAverageAccuracy: computation.filteredAverageAccuracy,
            levelCounts: (
                independent: computation.levelCounts.independent,
                instructional: computation.levelCounts.instructional,
                frustration: computation.levelCounts.frustration
            )
        )
    }
}

private struct RunningRecordSnapshot: Sendable {
    let index: Int
    let classKey: String?
    let studentUUID: UUID?
    let date: Date
    let readingLevel: ReadingLevel
    let searchableText: String
    let accuracy: Double
    let studentDisplayName: String
}

private struct RunningRecordComputation: Sendable {
    let sortedIndices: [Int]
    let uniqueStudentsCount: Int
    let averageAccuracy: Double
    let filteredAverageAccuracy: Double
    let levelCounts: (independent: Int, instructional: Int, frustration: Int)
}
