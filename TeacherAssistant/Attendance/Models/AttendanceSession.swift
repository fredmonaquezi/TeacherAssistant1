import Foundation
import SwiftData

@Model
class AttendanceSession {
    var date: Date
    var records: [AttendanceRecord]
    
    init(date: Date, records: [AttendanceRecord] = []) {
        self.date = date
        self.records = records
    }
}

extension AttendanceSession {
    @discardableResult
    func normalizeRecordsIfNeeded(
        for classStudents: [Student],
        context: ModelContext
    ) -> Int {
        var changeCount = 0
        changeCount += repairCollapsedStudentReferencesIfNeeded(for: classStudents)
        changeCount += collapseDuplicateRecords(context: context)
        return changeCount
    }

    @discardableResult
    func collapseDuplicateRecords(context: ModelContext) -> Int {
        var removedCount = removeDuplicateRecordReferences()
        var grouped: [PersistentIdentifier: [AttendanceRecord]] = [:]

        for record in records {
            guard let studentID = record.student?.id else { continue }
            grouped[studentID, default: []].append(record)
        }

        for group in grouped.values where group.count > 1 {
            guard let keeper = Self.preferredRecord(in: group) else { continue }
            removedCount += group.count - 1
            collapse(group: group, keeping: keeper, context: context)
        }

        return removedCount
    }

    @discardableResult
    func repairCollapsedStudentReferencesIfNeeded(for classStudents: [Student]) -> Int {
        let expectedStudents = deduplicatedStudents(from: classStudents).sorted {
            if $0.sortOrder == $1.sortOrder {
                return String(describing: $0.id) < String(describing: $1.id)
            }
            return $0.sortOrder < $1.sortOrder
        }
        guard expectedStudents.count > 1, records.count == expectedStudents.count else {
            return 0
        }

        var seenStudentIDs: Set<PersistentIdentifier> = []
        var candidateRecords: [AttendanceRecord] = []
        var seenCandidateRecordIDs: Set<PersistentIdentifier> = []
        for record in records {
            guard let studentID = record.student?.id else {
                if seenCandidateRecordIDs.insert(record.id).inserted {
                    candidateRecords.append(record)
                }
                continue
            }

            if !seenStudentIDs.insert(studentID).inserted {
                if seenCandidateRecordIDs.insert(record.id).inserted {
                    candidateRecords.append(record)
                }
            }
        }

        let missingStudents = expectedStudents.filter { student in
            !seenStudentIDs.contains(student.id)
        }

        guard !missingStudents.isEmpty, candidateRecords.count == missingStudents.count else {
            return 0
        }

        var repairedCount = 0
        for (record, student) in zip(candidateRecords, missingStudents) {
            guard record.student?.id != student.id else { continue }
            record.student = student
            repairedCount += 1
        }
        return repairedCount
    }

    private func deduplicatedStudents(from students: [Student]) -> [Student] {
        var seenIDs: Set<PersistentIdentifier> = []
        var deduplicated: [Student] = []
        for student in students where seenIDs.insert(student.id).inserted {
            deduplicated.append(student)
        }
        return deduplicated
    }

    private func collapse(
        group: [AttendanceRecord],
        keeping keeper: AttendanceRecord,
        context: ModelContext
    ) {
        let mergedNotes = Self.mergeNotes(from: group)
        if !mergedNotes.isEmpty {
            keeper.notes = mergedNotes
        }

        for duplicate in group where duplicate.id != keeper.id {
            if Self.statusPriority(duplicate.status) > Self.statusPriority(keeper.status) {
                keeper.status = duplicate.status
            }
            records.removeAll { $0.id == duplicate.id }
            context.delete(duplicate)
        }
    }

    private func removeDuplicateRecordReferences() -> Int {
        var seen: Set<PersistentIdentifier> = []
        let originalCount = records.count
        records = records.filter { seen.insert($0.id).inserted }
        return originalCount - records.count
    }

    private static func preferredRecord(in records: [AttendanceRecord]) -> AttendanceRecord? {
        records.sorted {
            let lhsPriority = statusPriority($0.status)
            let rhsPriority = statusPriority($1.status)
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }
            if $0.notes.count != $1.notes.count {
                return $0.notes.count > $1.notes.count
            }
            return String(describing: $0.id) < String(describing: $1.id)
        }.first
    }

    private static func statusPriority(_ status: AttendanceStatus) -> Int {
        switch status {
        case .absent: return 4
        case .leftEarly: return 3
        case .late: return 2
        case .present: return 1
        }
    }

    private static func mergeNotes(from records: [AttendanceRecord]) -> String {
        var seen: Set<String> = []
        let notes = records
            .map { $0.notes.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
        return notes.joined(separator: "\n\n")
    }
}
