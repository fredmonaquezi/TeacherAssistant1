import Foundation
import SwiftData

struct DuplicateStudentCleanupReport {
    var classesScanned: Int = 0
    var duplicateClassReferencesRemoved: Int = 0
    var duplicateUUIDGroups: Int = 0
    var duplicateNameGroups: Int = 0
    var studentsMerged: Int = 0
    var studentsSkippedAsAmbiguous: Int = 0
    var runningRecordsReassigned: Int = 0
    var attendanceRecordsReassigned: Int = 0
    var studentResultsReassigned: Int = 0
    var developmentScoresReassigned: Int = 0
    var assessmentResultsCollapsed: Int = 0
    var alreadyCompleted: Bool = false

    var didChange: Bool {
        duplicateClassReferencesRemoved > 0 ||
        studentsMerged > 0 ||
        runningRecordsReassigned > 0 ||
        attendanceRecordsReassigned > 0 ||
        studentResultsReassigned > 0 ||
        developmentScoresReassigned > 0 ||
        assessmentResultsCollapsed > 0
    }

    var summaryMessage: String {
        if alreadyCompleted {
            return "Duplicate cleanup was already completed once for this app data."
        }

        var lines: [String] = []
        lines.append("Classes scanned: \(classesScanned)")
        lines.append("Duplicate class references removed: \(duplicateClassReferencesRemoved)")
        lines.append("Duplicate UUID groups processed: \(duplicateUUIDGroups)")
        lines.append("Duplicate name groups analyzed: \(duplicateNameGroups)")
        lines.append("Students merged/removed: \(studentsMerged)")
        lines.append("Ambiguous same-name students skipped: \(studentsSkippedAsAmbiguous)")
        lines.append("Reassigned running records: \(runningRecordsReassigned)")
        lines.append("Reassigned attendance records: \(attendanceRecordsReassigned)")
        lines.append("Reassigned assessment results: \(studentResultsReassigned)")
        lines.append("Reassigned development scores: \(developmentScoresReassigned)")
        lines.append("Collapsed duplicate assessment result rows: \(assessmentResultsCollapsed)")

        if !didChange {
            lines.append("No changes were needed.")
        }

        return lines.joined(separator: "\n")
    }
}

@MainActor
enum DuplicateStudentCleanupService {
    private static let completionKey = "duplicateStudentCleanup.v1.completedAt"

    static var hasCompleted: Bool {
        UserDefaults.standard.object(forKey: completionKey) != nil
    }

    static func run(context: ModelContext) throws -> DuplicateStudentCleanupReport {
        if hasCompleted {
            var report = DuplicateStudentCleanupReport()
            report.alreadyCompleted = true
            return report
        }

        var report = DuplicateStudentCleanupReport()
        let classes = try context.fetch(FetchDescriptor<SchoolClass>())
        let allDevelopmentScores = try context.fetch(FetchDescriptor<DevelopmentScore>())

        for schoolClass in classes {
            report.classesScanned += 1
            report.duplicateClassReferencesRemoved += dedupeClassStudentReferences(in: schoolClass)

            var studentsByUUID: [UUID: [Student]] = [:]
            for student in schoolClass.students {
                studentsByUUID[student.uuid, default: []].append(student)
            }

            let uuidGroups = studentsByUUID.values.filter { $0.count > 1 }
            report.duplicateUUIDGroups += uuidGroups.count
            for group in uuidGroups {
                guard let canonical = preferredStudent(in: group) else { continue }
                for duplicate in group where duplicate.id != canonical.id {
                    merge(
                        duplicate: duplicate,
                        into: canonical,
                        in: schoolClass,
                        context: context,
                        allDevelopmentScores: allDevelopmentScores,
                        report: &report
                    )
                }
            }

            let nameGroups = duplicateNameGroups(in: schoolClass.students)
            report.duplicateNameGroups += nameGroups.count
            for group in nameGroups {
                guard let canonical = preferredStudent(in: group) else { continue }
                let canonicalFootprint = footprint(
                    for: canonical,
                    in: schoolClass,
                    allDevelopmentScores: allDevelopmentScores
                )

                for duplicate in group where duplicate.id != canonical.id {
                    if duplicate.uuid != canonical.uuid {
                        let duplicateFootprint = footprint(
                            for: duplicate,
                            in: schoolClass,
                            allDevelopmentScores: allDevelopmentScores
                        )
                        if canonicalFootprint.hasMeaningfulData && duplicateFootprint.hasMeaningfulData {
                            report.studentsSkippedAsAmbiguous += 1
                            continue
                        }
                    }

                    merge(
                        duplicate: duplicate,
                        into: canonical,
                        in: schoolClass,
                        context: context,
                        allDevelopmentScores: allDevelopmentScores,
                        report: &report
                    )
                }
            }

            report.assessmentResultsCollapsed += collapseDuplicateAssessmentResults(
                in: schoolClass,
                context: context
            )
            resequenceStudentSortOrder(in: schoolClass)
        }

        if report.didChange {
            try context.save()
        }
        UserDefaults.standard.set(Date(), forKey: completionKey)
        return report
    }

    private static func dedupeClassStudentReferences(in schoolClass: SchoolClass) -> Int {
        var seen: Set<PersistentIdentifier> = []
        var uniqueStudents: [Student] = []

        for student in schoolClass.students {
            if seen.insert(student.id).inserted {
                uniqueStudents.append(student)
            }
        }

        let removed = schoolClass.students.count - uniqueStudents.count
        if removed > 0 {
            schoolClass.students = uniqueStudents
        }
        return removed
    }

    private static func duplicateNameGroups(in students: [Student]) -> [[Student]] {
        let grouped = Dictionary(grouping: students) { student in
            normalizedName(student.name)
        }
        return grouped
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map { $0.value }
    }

    private static func preferredStudent(in students: [Student]) -> Student? {
        students.sorted {
            if $0.sortOrder == $1.sortOrder {
                return String(describing: $0.id) < String(describing: $1.id)
            }
            return $0.sortOrder < $1.sortOrder
        }.first
    }

    private static func normalizedName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func merge(
        duplicate: Student,
        into canonical: Student,
        in schoolClass: SchoolClass,
        context: ModelContext,
        allDevelopmentScores: [DevelopmentScore],
        report: inout DuplicateStudentCleanupReport
    ) {
        mergeStudentMetadata(from: duplicate, into: canonical)
        replaceSeparationReferences(in: schoolClass.students, duplicate: duplicate, canonical: canonical)
        report.runningRecordsReassigned += reassignRunningRecords(from: duplicate, to: canonical)
        report.attendanceRecordsReassigned += reassignAttendanceRecords(from: duplicate, to: canonical, schoolClass: schoolClass)
        report.studentResultsReassigned += reassignStudentResults(from: duplicate, to: canonical, schoolClass: schoolClass)
        report.developmentScoresReassigned += reassignDevelopmentScores(
            from: duplicate,
            to: canonical,
            allDevelopmentScores: allDevelopmentScores
        )

        schoolClass.students.removeAll { $0.id == duplicate.id }
        context.delete(duplicate)
        report.studentsMerged += 1
    }

    private static func mergeStudentMetadata(from duplicate: Student, into canonical: Student) {
        if (canonical.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let duplicateFirst = duplicate.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !duplicateFirst.isEmpty {
            canonical.firstName = duplicateFirst
        }

        if (canonical.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let duplicateLast = duplicate.lastName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !duplicateLast.isEmpty {
            canonical.lastName = duplicateLast
        }

        if canonical.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.notes = duplicate.notes
        } else if !duplicate.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  canonical.notes != duplicate.notes {
            canonical.notes += "\n\n\(duplicate.notes)"
        }

        if canonical.gender == StudentGender.preferNotToSay.rawValue,
           duplicate.gender != StudentGender.preferNotToSay.rawValue {
            canonical.gender = duplicate.gender
        }

        canonical.isParticipatingWell = canonical.isParticipatingWell || duplicate.isParticipatingWell
        canonical.needsHelp = canonical.needsHelp || duplicate.needsHelp
        canonical.missingHomework = canonical.missingHomework || duplicate.missingHomework
        canonical.sortOrder = min(canonical.sortOrder, duplicate.sortOrder)

        mergeAssessmentScores(from: duplicate, into: canonical)
        mergeSeparationList(from: duplicate, into: canonical)
    }

    private static func mergeAssessmentScores(from duplicate: Student, into canonical: Student) {
        if canonical.scores.count < duplicate.scores.count {
            for _ in canonical.scores.count..<duplicate.scores.count {
                canonical.scores.append(AssessmentScore(value: 0))
            }
        }

        for (index, duplicateScore) in duplicate.scores.enumerated() {
            guard index < canonical.scores.count else { continue }
            canonical.scores[index].value = max(canonical.scores[index].value, duplicateScore.value)
        }
    }

    private static func mergeSeparationList(from duplicate: Student, into canonical: Student) {
        let merged = Set(canonical.separationTokens + duplicate.separationTokens)
            .filter { token in
                token != canonical.stableIDString && token != duplicate.stableIDString
            }
            .sorted()
        canonical.separationList = merged.joined(separator: ",")
    }

    private static func replaceSeparationReferences(in students: [Student], duplicate: Student, canonical: Student) {
        let legacyPersistentID = String(describing: duplicate.id)
        let oldTokens = Set([duplicate.stableIDString, legacyPersistentID])

        for student in students {
            var changed = false
            let remapped = student.separationTokens.map { token -> String in
                if oldTokens.contains(token) {
                    changed = true
                    return canonical.stableIDString
                }
                return token
            }

            guard changed else { continue }
            let cleaned = Set(remapped).filter { token in
                token != student.stableIDString
            }.sorted()
            student.separationList = cleaned.joined(separator: ",")
        }
    }

    private static func reassignRunningRecords(from duplicate: Student, to canonical: Student) -> Int {
        var reassigned = 0
        let records = duplicate.runningRecords
        for record in records where record.student?.id == duplicate.id {
            record.student = canonical
            reassigned += 1
        }
        return reassigned
    }

    private static func reassignAttendanceRecords(from duplicate: Student, to canonical: Student, schoolClass: SchoolClass) -> Int {
        var reassigned = 0
        for session in schoolClass.attendanceSessions {
            for record in session.records where record.student?.id == duplicate.id {
                record.student = canonical
                reassigned += 1
            }
        }
        return reassigned
    }

    private static func reassignStudentResults(from duplicate: Student, to canonical: Student, schoolClass: SchoolClass) -> Int {
        var reassigned = 0
        for subject in schoolClass.subjects {
            for unit in subject.units {
                for assessment in unit.assessments {
                    for result in assessment.results where result.student?.id == duplicate.id {
                        result.student = canonical
                        reassigned += 1
                    }
                }
            }
        }
        return reassigned
    }

    private static func reassignDevelopmentScores(
        from duplicate: Student,
        to canonical: Student,
        allDevelopmentScores: [DevelopmentScore]
    ) -> Int {
        var reassigned = 0
        for score in allDevelopmentScores where score.student?.id == duplicate.id {
            score.student = canonical
            reassigned += 1
        }
        return reassigned
    }

    private static func collapseDuplicateAssessmentResults(in schoolClass: SchoolClass, context: ModelContext) -> Int {
        var removedCount = 0

        for subject in schoolClass.subjects {
            for unit in subject.units {
                for assessment in unit.assessments {
                    var grouped: [PersistentIdentifier: [StudentResult]] = [:]
                    for result in assessment.results {
                        guard let studentID = result.student?.id else { continue }
                        grouped[studentID, default: []].append(result)
                    }

                    for group in grouped.values where group.count > 1 {
                        guard let keeper = preferredResult(in: group) else { continue }

                        let mergedNotes = group
                            .map { $0.notes.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .uniqued()
                        if !mergedNotes.isEmpty {
                            keeper.notes = mergedNotes.joined(separator: "\n\n")
                        }

                        for duplicateResult in group where duplicateResult.id != keeper.id {
                            context.delete(duplicateResult)
                            removedCount += 1
                        }
                    }
                }
            }
        }

        return removedCount
    }

    private static func preferredResult(in results: [StudentResult]) -> StudentResult? {
        results.sorted {
            if $0.score == $1.score {
                return $0.notes.count > $1.notes.count
            }
            return $0.score > $1.score
        }.first
    }

    private static func resequenceStudentSortOrder(in schoolClass: SchoolClass) {
        let sorted = schoolClass.students.sorted {
            if $0.sortOrder == $1.sortOrder {
                return String(describing: $0.id) < String(describing: $1.id)
            }
            return $0.sortOrder < $1.sortOrder
        }

        for (index, student) in sorted.enumerated() {
            student.sortOrder = index
        }
    }

    private static func footprint(
        for student: Student,
        in schoolClass: SchoolClass,
        allDevelopmentScores: [DevelopmentScore]
    ) -> StudentFootprint {
        var assessmentResultCount = 0
        for subject in schoolClass.subjects {
            for unit in subject.units {
                for assessment in unit.assessments {
                    assessmentResultCount += assessment.results.filter { $0.student?.id == student.id }.count
                }
            }
        }

        var attendanceRecordCount = 0
        for session in schoolClass.attendanceSessions {
            attendanceRecordCount += session.records.filter { $0.student?.id == student.id }.count
        }

        let developmentScoreCount = allDevelopmentScores.filter { $0.student?.id == student.id }.count

        return StudentFootprint(
            runningRecordCount: student.runningRecords.count,
            assessmentResultCount: assessmentResultCount,
            attendanceRecordCount: attendanceRecordCount,
            developmentScoreCount: developmentScoreCount,
            notesCount: student.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1,
            hasFlags: student.isParticipatingWell || student.needsHelp || student.missingHomework
        )
    }
}

private struct StudentFootprint {
    let runningRecordCount: Int
    let assessmentResultCount: Int
    let attendanceRecordCount: Int
    let developmentScoreCount: Int
    let notesCount: Int
    let hasFlags: Bool

    var hasMeaningfulData: Bool {
        runningRecordCount > 0 ||
        assessmentResultCount > 0 ||
        attendanceRecordCount > 0 ||
        developmentScoreCount > 0 ||
        notesCount > 0 ||
        hasFlags
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
