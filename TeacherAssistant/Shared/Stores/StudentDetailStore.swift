import Foundation
import SwiftData

struct StudentDetailAttendanceSummary {
    let total: Int
    let present: Int
    let absent: Int
    let late: Int
    let leftEarly: Int

    static let empty = StudentDetailAttendanceSummary(
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
        leftEarly: 0
    )
}

struct StudentDetailSubjectSummary {
    let subject: Subject
    let results: [StudentResult]
    let averageScore: Double
}

struct StudentDetailDevelopmentCategory {
    let category: String
    let scores: [DevelopmentScore]
}

struct StudentDetailSubjectCardViewModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let subjectName: String
    let assessmentCount: Int
    let averageScore: Double
}

struct StudentDetailRecentGradeViewModel: Identifiable, Equatable, Sendable {
    let id: Int
    let assessmentTitle: String
    let subjectName: String?
    let unitName: String?
    let score: Double
}

struct StudentDetailDevelopmentScoreViewModel: Identifiable, Equatable, Sendable {
    let id: Int
    let criterionName: String
    let rating: Int
    let ratingLabel: String
    let notes: String
    let date: Date
}

struct StudentDetailDevelopmentCategoryViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let category: String
    let scores: [StudentDetailDevelopmentScoreViewModel]
}

struct StudentDetailDerivedData {
    let subjectsForStudentClass: [Subject]
    let resultsForStudent: [StudentResult]
    let scoredResultsForStudent: [StudentResult]
    let studentAverage: Double
    let attendanceRecords: [AttendanceRecord]
    let attendanceSummary: StudentDetailAttendanceSummary
    let subjectSummaries: [StudentDetailSubjectSummary]
    let subjectSummariesByID: [UUID: StudentDetailSubjectSummary]
    let recentResults: [StudentResult]
    let subjectCardViewModels: [StudentDetailSubjectCardViewModel]
    let recentGradeViewModels: [StudentDetailRecentGradeViewModel]
    let latestDevelopmentScores: [DevelopmentScore]
    let groupedLatestDevelopmentScores: [StudentDetailDevelopmentCategory]
    let developmentCategoryViewModels: [StudentDetailDevelopmentCategoryViewModel]

    static let empty = StudentDetailDerivedData(
        subjectsForStudentClass: [],
        resultsForStudent: [],
        scoredResultsForStudent: [],
        studentAverage: 0,
        attendanceRecords: [],
        attendanceSummary: .empty,
        subjectSummaries: [],
        subjectSummariesByID: [:],
        recentResults: [],
        subjectCardViewModels: [],
        recentGradeViewModels: [],
        latestDevelopmentScores: [],
        groupedLatestDevelopmentScores: [],
        developmentCategoryViewModels: []
    )
}

enum StudentDetailStore {
    static func derive(
        student: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allScores: [DevelopmentScore]
    ) -> StudentDetailDerivedData {
        let subjectsForStudentClass = sortedSubjects(for: student)
        let studentIDKey = String(describing: student.id)
        let resultSnapshots = makeResultSnapshots(allResults)
        let attendanceSnapshots = makeAttendanceSnapshots(allAttendanceSessions)
        let scoreSnapshots = makeScoreSnapshots(allScores, student: student)
        let computation = computeDerivation(
            studentIDKey: studentIDKey,
            resultSnapshots: resultSnapshots,
            attendanceSnapshots: attendanceSnapshots,
            scoreSnapshots: scoreSnapshots
        )

        return makeDerivedData(
            subjectsForStudentClass: subjectsForStudentClass,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allScores: allScores,
            computation: computation
        )
    }

    static func deriveAsync(
        student: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allScores: [DevelopmentScore]
    ) async -> StudentDetailDerivedData {
        let subjectsForStudentClass = sortedSubjects(for: student)
        let studentIDKey = String(describing: student.id)
        let resultSnapshots = makeResultSnapshots(allResults)
        let attendanceSnapshots = makeAttendanceSnapshots(allAttendanceSessions)
        let scoreSnapshots = makeScoreSnapshots(allScores, student: student)

        return await DerivationRunner.runAsync(
            compute: {
                computeDerivation(
                    studentIDKey: studentIDKey,
                    resultSnapshots: resultSnapshots,
                    attendanceSnapshots: attendanceSnapshots,
                    scoreSnapshots: scoreSnapshots
                )
            },
            cancelledResult: .empty
        ) { computation in
            makeDerivedData(
                subjectsForStudentClass: subjectsForStudentClass,
                allResults: allResults,
                allAttendanceSessions: allAttendanceSessions,
                allScores: allScores,
                computation: computation
            )
        }
    }

    private static func sortedSubjects(for student: Student) -> [Subject] {
        (student.schoolClass?.subjects ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private static func makeResultSnapshots(_ results: [StudentResult]) -> [StudentDetailResultSnapshot] {
        results.enumerated().map { index, result in
            StudentDetailResultSnapshot(
                index: index,
                studentIDKey: result.student.map { String(describing: $0.id) },
                isScored: result.isScored,
                normalizedScoreOutOfTen: normalizedScoreOutOfTen(
                    score: result.score,
                    maxScore: result.assessment?.safeMaxScore ?? Assessment.defaultMaxScore,
                    isScored: result.isScored
                ),
                assessmentSortOrder: result.assessment?.sortOrder ?? 0,
                subjectID: result.assessment?.unit?.subject?.id
            )
        }
    }

    private static func makeAttendanceSnapshots(_ sessions: [AttendanceSession]) -> [StudentDetailAttendanceSnapshot] {
        var snapshots: [StudentDetailAttendanceSnapshot] = []
        snapshots.reserveCapacity(sessions.reduce(0) { $0 + $1.records.count })

        for (sessionIndex, session) in sessions.enumerated() {
            for (recordIndex, record) in session.records.enumerated() {
                snapshots.append(
                    StudentDetailAttendanceSnapshot(
                        sessionIndex: sessionIndex,
                        recordIndex: recordIndex,
                        studentIDKey: record.student.map { String(describing: $0.id) },
                        statusRaw: record.statusRaw
                    )
                )
            }
        }

        return snapshots
    }

    private static func makeScoreSnapshots(
        _ scores: [DevelopmentScore],
        student: Student
    ) -> [StudentDetailScoreSnapshot] {
        scores.enumerated().map { index, score in
            StudentDetailScoreSnapshot(
                index: index,
                matchesStudent: score.matchesStudent(student),
                criterionID: score.criterion?.id,
                date: score.date,
                criterionSortOrder: score.criterion?.sortOrder ?? 0,
                categoryName: score.criterion?.category?.name ?? "Other"
            )
        }
    }

    private static func normalizedScoreOutOfTen(score: Double, maxScore: Double, isScored: Bool) -> Double? {
        guard isScored, score.isFinite else { return nil }
        let validatedMax = min(max(maxScore.isFinite ? maxScore : Assessment.defaultMaxScore, 1), 1000)
        let validatedScore = min(max(score, 0), validatedMax)
        return (validatedScore / validatedMax) * 10
    }

    nonisolated private static func computeDerivation(
        studentIDKey: String,
        resultSnapshots: [StudentDetailResultSnapshot],
        attendanceSnapshots: [StudentDetailAttendanceSnapshot],
        scoreSnapshots: [StudentDetailScoreSnapshot]
    ) -> StudentDetailComputation {
        let resultsForStudent = resultSnapshots.filter { $0.studentIDKey == studentIDKey }
        let resultIndices = resultsForStudent.map(\.index)
        let scoredResultIndices = resultsForStudent.filter(\.isScored).map(\.index)

        let studentAverage: Double
        let normalizedScores = resultsForStudent.compactMap(\.normalizedScoreOutOfTen)
        if normalizedScores.isEmpty {
            studentAverage = 0
        } else {
            studentAverage = normalizedScores.reduce(0, +) / Double(normalizedScores.count)
        }

        let recentResultIndices = Array(
            resultsForStudent
                .sorted { lhs, rhs in
                    if lhs.assessmentSortOrder == rhs.assessmentSortOrder {
                        return lhs.index < rhs.index
                    }
                    return lhs.assessmentSortOrder > rhs.assessmentSortOrder
                }
                .prefix(10)
                .map(\.index)
        )

        var subjectResultIndicesByID: [UUID: [Int]] = [:]
        var subjectAverageByID: [UUID: Double] = [:]
        for snapshot in resultsForStudent {
            guard let subjectID = snapshot.subjectID else { continue }
            subjectResultIndicesByID[subjectID, default: []].append(snapshot.index)
        }
        for (subjectID, indices) in subjectResultIndicesByID {
            let subjectScores = indices.compactMap { index in
                resultSnapshots[index].normalizedScoreOutOfTen
            }
            if subjectScores.isEmpty {
                subjectAverageByID[subjectID] = 0
            } else {
                subjectAverageByID[subjectID] = subjectScores.reduce(0, +) / Double(subjectScores.count)
            }
        }

        let attendanceForStudent = attendanceSnapshots.filter { $0.studentIDKey == studentIDKey }
        let attendanceCoordinates = attendanceForStudent.map { snapshot in
            StudentDetailAttendanceCoordinate(
                sessionIndex: snapshot.sessionIndex,
                recordIndex: snapshot.recordIndex
            )
        }

        let attendanceSummary = attendanceForStudent.reduce(
            into: StudentDetailAttendanceCounts(total: 0, present: 0, absent: 0, late: 0, leftEarly: 0)
        ) { partialResult, snapshot in
            partialResult.total += 1
            switch snapshot.statusRaw {
            case AttendanceStatus.present.rawValue:
                partialResult.present += 1
            case AttendanceStatus.absent.rawValue:
                partialResult.absent += 1
            case AttendanceStatus.late.rawValue:
                partialResult.late += 1
            case AttendanceStatus.leftEarly.rawValue:
                partialResult.leftEarly += 1
            default:
                break
            }
        }

        let matchingScores = scoreSnapshots.filter(\.matchesStudent)
        var latestByCriterionID: [UUID: StudentDetailScoreSnapshot] = [:]
        for snapshot in matchingScores {
            guard let criterionID = snapshot.criterionID else { continue }
            if let existing = latestByCriterionID[criterionID], existing.date >= snapshot.date {
                continue
            }
            latestByCriterionID[criterionID] = snapshot
        }

        let latestScores = latestByCriterionID.values.sorted { lhs, rhs in
            if lhs.criterionSortOrder == rhs.criterionSortOrder {
                return lhs.index < rhs.index
            }
            return lhs.criterionSortOrder < rhs.criterionSortOrder
        }
        let latestScoreIndices = latestScores.map(\.index)

        var scoresByCategory: [String: [Int]] = [:]
        for snapshot in latestScores {
            scoresByCategory[snapshot.categoryName, default: []].append(snapshot.index)
        }
        let groupedCategoryScores = scoresByCategory
            .map { StudentDetailCategoryComputation(category: $0.key, scoreIndices: $0.value) }
            .sorted {
                $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
            }

        return StudentDetailComputation(
            resultIndices: resultIndices,
            scoredResultIndices: scoredResultIndices,
            studentAverage: studentAverage,
            recentResultIndices: recentResultIndices,
            subjectResultIndicesByID: subjectResultIndicesByID,
            subjectAverageByID: subjectAverageByID,
            attendanceCoordinates: attendanceCoordinates,
            attendanceSummary: attendanceSummary,
            latestScoreIndices: latestScoreIndices,
            groupedCategoryScores: groupedCategoryScores
        )
    }

    private static func makeDerivedData(
        subjectsForStudentClass: [Subject],
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allScores: [DevelopmentScore],
        computation: StudentDetailComputation
    ) -> StudentDetailDerivedData {
        let resultsForStudent = computation.resultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }
        let scoredResultsForStudent = computation.scoredResultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }
        let recentResults = computation.recentResultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }

        let attendanceRecords: [AttendanceRecord] = computation.attendanceCoordinates.compactMap { coordinate in
            guard allAttendanceSessions.indices.contains(coordinate.sessionIndex) else { return nil }
            let session = allAttendanceSessions[coordinate.sessionIndex]
            guard session.records.indices.contains(coordinate.recordIndex) else { return nil }
            return session.records[coordinate.recordIndex]
        }

        let subjectSummaries = subjectsForStudentClass.map { subject in
            let subjectResults = (computation.subjectResultIndicesByID[subject.id] ?? []).compactMap { index in
                allResults.indices.contains(index) ? allResults[index] : nil
            }
            return StudentDetailSubjectSummary(
                subject: subject,
                results: subjectResults,
                averageScore: computation.subjectAverageByID[subject.id] ?? 0
            )
        }

        let subjectSummariesByID = Dictionary(uniqueKeysWithValues: subjectSummaries.map { ($0.subject.id, $0) })
        let subjectCardViewModels = subjectSummaries.map { summary in
            StudentDetailSubjectCardViewModel(
                id: summary.subject.id,
                subjectName: summary.subject.name,
                assessmentCount: summary.results.count,
                averageScore: summary.averageScore
            )
        }
        let recentGradeViewModels = computation.recentResultIndices.compactMap { index -> StudentDetailRecentGradeViewModel? in
            guard allResults.indices.contains(index) else { return nil }
            let result = allResults[index]
            return StudentDetailRecentGradeViewModel(
                id: index,
                assessmentTitle: result.assessment?.title ?? "Assessment",
                subjectName: result.assessment?.unit?.subject?.name,
                unitName: result.assessment?.unit?.name,
                score: result.score
            )
        }
        let latestDevelopmentScores = computation.latestScoreIndices.compactMap { index in
            allScores.indices.contains(index) ? allScores[index] : nil
        }
        let groupedLatestDevelopmentScores = computation.groupedCategoryScores.map { group in
            StudentDetailDevelopmentCategory(
                category: group.category,
                scores: group.scoreIndices.compactMap { index in
                    allScores.indices.contains(index) ? allScores[index] : nil
                }
            )
        }
        let developmentCategoryViewModels = computation.groupedCategoryScores.map { group in
            StudentDetailDevelopmentCategoryViewModel(
                id: group.category,
                category: group.category,
                scores: group.scoreIndices.compactMap { index in
                    guard allScores.indices.contains(index) else { return nil }
                    let score = allScores[index]
                    return StudentDetailDevelopmentScoreViewModel(
                        id: index,
                        criterionName: score.criterion?.name ?? "Unknown",
                        rating: score.rating,
                        ratingLabel: score.ratingLabel,
                        notes: score.notes,
                        date: score.date
                    )
                }
            )
        }

        return StudentDetailDerivedData(
            subjectsForStudentClass: subjectsForStudentClass,
            resultsForStudent: resultsForStudent,
            scoredResultsForStudent: scoredResultsForStudent,
            studentAverage: computation.studentAverage,
            attendanceRecords: attendanceRecords,
            attendanceSummary: StudentDetailAttendanceSummary(
                total: computation.attendanceSummary.total,
                present: computation.attendanceSummary.present,
                absent: computation.attendanceSummary.absent,
                late: computation.attendanceSummary.late,
                leftEarly: computation.attendanceSummary.leftEarly
            ),
            subjectSummaries: subjectSummaries,
            subjectSummariesByID: subjectSummariesByID,
            recentResults: recentResults,
            subjectCardViewModels: subjectCardViewModels,
            recentGradeViewModels: recentGradeViewModels,
            latestDevelopmentScores: latestDevelopmentScores,
            groupedLatestDevelopmentScores: groupedLatestDevelopmentScores,
            developmentCategoryViewModels: developmentCategoryViewModels
        )
    }
}

private struct StudentDetailResultSnapshot: Sendable {
    let index: Int
    let studentIDKey: String?
    let isScored: Bool
    let normalizedScoreOutOfTen: Double?
    let assessmentSortOrder: Int
    let subjectID: UUID?
}

private struct StudentDetailAttendanceSnapshot: Sendable {
    let sessionIndex: Int
    let recordIndex: Int
    let studentIDKey: String?
    let statusRaw: String
}

private struct StudentDetailAttendanceCoordinate: Sendable {
    let sessionIndex: Int
    let recordIndex: Int
}

private struct StudentDetailScoreSnapshot: Sendable {
    let index: Int
    let matchesStudent: Bool
    let criterionID: UUID?
    let date: Date
    let criterionSortOrder: Int
    let categoryName: String
}

private struct StudentDetailAttendanceCounts: Sendable {
    var total: Int
    var present: Int
    var absent: Int
    var late: Int
    var leftEarly: Int
}

private struct StudentDetailCategoryComputation: Sendable {
    let category: String
    let scoreIndices: [Int]
}

private struct StudentDetailComputation: Sendable {
    let resultIndices: [Int]
    let scoredResultIndices: [Int]
    let studentAverage: Double
    let recentResultIndices: [Int]
    let subjectResultIndicesByID: [UUID: [Int]]
    let subjectAverageByID: [UUID: Double]
    let attendanceCoordinates: [StudentDetailAttendanceCoordinate]
    let attendanceSummary: StudentDetailAttendanceCounts
    let latestScoreIndices: [Int]
    let groupedCategoryScores: [StudentDetailCategoryComputation]
}
