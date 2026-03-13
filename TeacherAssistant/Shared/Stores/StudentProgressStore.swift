import Foundation
import SwiftData

struct StudentProgressAttendanceSummary {
    let totalSessions: Int
    let present: Int
    let absent: Int
    let late: Int
    let leftEarly: Int

    static let empty = StudentProgressAttendanceSummary(
        totalSessions: 0,
        present: 0,
        absent: 0,
        late: 0,
        leftEarly: 0
    )
}

struct StudentProgressUnitSummary {
    let unit: Unit
    let results: [StudentResult]
    let averageScore: Double
}

struct StudentProgressSubjectSummary {
    let subject: Subject
    let results: [StudentResult]
    let averageScore: Double
    let units: [StudentProgressUnitSummary]
}

struct StudentProgressDevelopmentCategory {
    let category: String
    let scores: [DevelopmentScore]
}

struct StudentProgressSubjectOverviewViewModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let subjectName: String
    let assessmentCount: Int
    let averageScore: Double
}

struct StudentProgressUnitRowViewModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let unitName: String
    let criteriaCount: Int
    let averageScore: Double
}

struct StudentProgressSubjectSectionViewModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let subjectName: String
    let assessmentCount: Int
    let averageScore: Double
    let units: [StudentProgressUnitRowViewModel]
}

struct StudentProgressRecentActivityViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let kind: StudentProgressRecentActivityKind
    let title: String
    let subtitle: String?
    let detailText: String
    let date: Date
    let score: Double?
    let observationSupportLevel: LiveObservationLevel?
}

enum StudentProgressRecentActivityKind: String, Equatable, Sendable {
    case assessment
    case liveCheckIn
}

struct StudentProgressObservationChecklistItemViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let level: LiveObservationLevel
}

struct StudentProgressLatestObservationViewModel: Equatable, Sendable {
    let createdAt: Date
    let understandingLevel: LiveObservationLevel
    let engagementLevel: LiveObservationLevel
    let supportLevel: LiveObservationLevel
    let note: String
    let checklistItems: [StudentProgressObservationChecklistItemViewModel]
}

struct StudentProgressObservationLevelCountViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let level: LiveObservationLevel
    let count: Int
}

struct StudentProgressObservationSummaryViewModel: Equatable, Sendable {
    let totalObservationCount: Int
    let observationsTodayCount: Int
    let latestObservation: StudentProgressLatestObservationViewModel?
    let recentSupportCounts: [StudentProgressObservationLevelCountViewModel]

    static let empty = StudentProgressObservationSummaryViewModel(
        totalObservationCount: 0,
        observationsTodayCount: 0,
        latestObservation: nil,
        recentSupportCounts: []
    )
}

struct StudentProgressDevelopmentScoreViewModel: Identifiable, Equatable, Sendable {
    let id: Int
    let criterionName: String
    let rating: Int
    let ratingLabel: String
    let notes: String
    let date: Date
}

struct StudentProgressDevelopmentCategoryViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let category: String
    let scores: [StudentProgressDevelopmentScoreViewModel]
}

struct StudentProgressRunningRecordViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let date: Date
    let accuracy: Double
    let readingLevel: ReadingLevel
    let notes: String
}

struct StudentProgressDerivedData {
    let overallAverageScore: Double
    let resultsForStudent: [StudentResult]
    let scoredResultsForStudent: [StudentResult]
    let recentActivityViewModels: [StudentProgressRecentActivityViewModel]
    let attendanceRecordsForStudent: [AttendanceRecord]
    let subjectOverviewViewModels: [StudentProgressSubjectOverviewViewModel]
    let subjectSectionViewModels: [StudentProgressSubjectSectionViewModel]
    let subjectsForStudent: [Subject]
    let studentDevelopmentScores: [DevelopmentScore]
    let attendanceSummary: StudentProgressAttendanceSummary
    let recentResults: [StudentResult]
    let liveObservationsForStudent: [LiveObservation]
    let observationSummary: StudentProgressObservationSummaryViewModel
    let subjectSummaries: [StudentProgressSubjectSummary]
    let subjectSummariesByID: [UUID: StudentProgressSubjectSummary]
    let runningRecordsDescending: [RunningRecord]
    let runningRecordsAscending: [RunningRecord]
    let runningRecordViewModelsDescending: [StudentProgressRunningRecordViewModel]
    let runningRecordViewModelsAscending: [StudentProgressRunningRecordViewModel]
    let runningRecordAverageAccuracy: Double
    let latestRunningRecord: RunningRecord?
    let latestRunningRecordViewModel: StudentProgressRunningRecordViewModel?
    let latestDevelopmentScores: [DevelopmentScore]
    let groupedLatestDevelopmentScores: [StudentProgressDevelopmentCategory]
    let developmentCategoryViewModels: [StudentProgressDevelopmentCategoryViewModel]

    static let empty = StudentProgressDerivedData(
        overallAverageScore: 0,
        resultsForStudent: [],
        scoredResultsForStudent: [],
        recentActivityViewModels: [],
        attendanceRecordsForStudent: [],
        subjectOverviewViewModels: [],
        subjectSectionViewModels: [],
        subjectsForStudent: [],
        studentDevelopmentScores: [],
        attendanceSummary: .empty,
        recentResults: [],
        liveObservationsForStudent: [],
        observationSummary: .empty,
        subjectSummaries: [],
        subjectSummariesByID: [:],
        runningRecordsDescending: [],
        runningRecordsAscending: [],
        runningRecordViewModelsDescending: [],
        runningRecordViewModelsAscending: [],
        runningRecordAverageAccuracy: 0,
        latestRunningRecord: nil,
        latestRunningRecordViewModel: nil,
        latestDevelopmentScores: [],
        groupedLatestDevelopmentScores: [],
        developmentCategoryViewModels: []
    )
}

enum StudentProgressStore {
    static func derive(
        student: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore],
        allLiveObservations: [LiveObservation]
    ) -> StudentProgressDerivedData {
        let studentIDKey = String(describing: student.id)
        let runningRecords = student.runningRecords
        let resultSnapshots = makeResultSnapshots(allResults)
        let attendanceSnapshots = makeAttendanceSnapshots(allAttendanceSessions)
        let scoreSnapshots = makeScoreSnapshots(allDevelopmentScores, student: student)
        let runningRecordSnapshots = makeRunningRecordSnapshots(runningRecords)
        let computation = computeDerivation(
            studentIDKey: studentIDKey,
            resultSnapshots: resultSnapshots,
            attendanceSnapshots: attendanceSnapshots,
            scoreSnapshots: scoreSnapshots,
            runningRecordSnapshots: runningRecordSnapshots
        )

        return makeDerivedData(
            student: student,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores,
            allLiveObservations: allLiveObservations,
            runningRecords: runningRecords,
            computation: computation
        )
    }

    static func deriveAsync(
        student: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore],
        allLiveObservations: [LiveObservation]
    ) async -> StudentProgressDerivedData {
        let studentIDKey = String(describing: student.id)
        let runningRecords = student.runningRecords
        let resultSnapshots = makeResultSnapshots(allResults)
        let attendanceSnapshots = makeAttendanceSnapshots(allAttendanceSessions)
        let scoreSnapshots = makeScoreSnapshots(allDevelopmentScores, student: student)
        let runningRecordSnapshots = makeRunningRecordSnapshots(runningRecords)

        return await DerivationRunner.runAsync(
            compute: {
                computeDerivation(
                    studentIDKey: studentIDKey,
                    resultSnapshots: resultSnapshots,
                    attendanceSnapshots: attendanceSnapshots,
                    scoreSnapshots: scoreSnapshots,
                    runningRecordSnapshots: runningRecordSnapshots
                )
            },
            cancelledResult: .empty
        ) { computation in
            makeDerivedData(
                student: student,
                allResults: allResults,
                allAttendanceSessions: allAttendanceSessions,
                allDevelopmentScores: allDevelopmentScores,
                allLiveObservations: allLiveObservations,
                runningRecords: runningRecords,
                computation: computation
            )
        }
    }

    private static func makeResultSnapshots(_ allResults: [StudentResult]) -> [StudentProgressResultSnapshot] {
        allResults.enumerated().map { index, result in
            let subject = result.assessment?.unit?.subject
            let unit = result.assessment?.unit
            return StudentProgressResultSnapshot(
                index: index,
                studentIDKey: result.student.map { String(describing: $0.id) },
                isScored: result.isScored,
                normalizedScoreOutOfTen: normalizedScoreOutOfTen(
                    score: result.score,
                    maxScore: result.assessment?.safeMaxScore ?? Assessment.defaultMaxScore,
                    isScored: result.isScored
                ),
                assessmentSortOrder: result.assessment?.sortOrder ?? 0,
                subjectID: subject?.id,
                subjectName: subject?.name ?? "",
                unitID: unit?.id,
                unitName: unit?.name ?? "",
                unitSortOrder: unit?.sortOrder ?? 0
            )
        }
    }

    private static func makeAttendanceSnapshots(_ sessions: [AttendanceSession]) -> [StudentProgressAttendanceSnapshot] {
        var snapshots: [StudentProgressAttendanceSnapshot] = []
        snapshots.reserveCapacity(sessions.reduce(0) { $0 + $1.records.count })

        for (sessionIndex, session) in sessions.enumerated() {
            for (recordIndex, record) in session.records.enumerated() {
                snapshots.append(
                    StudentProgressAttendanceSnapshot(
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
    ) -> [StudentProgressScoreSnapshot] {
        scores.enumerated().map { index, score in
            StudentProgressScoreSnapshot(
                index: index,
                matchesStudent: score.matchesStudent(student),
                criterionID: score.criterion?.id,
                date: score.date,
                criterionSortOrder: score.criterion?.sortOrder ?? 0,
                categoryName: score.criterion?.category?.name ?? "Other"
            )
        }
    }

    private static func makeRunningRecordSnapshots(_ records: [RunningRecord]) -> [StudentProgressRunningRecordSnapshot] {
        records.enumerated().map { index, record in
            StudentProgressRunningRecordSnapshot(
                index: index,
                date: record.date,
                accuracy: record.accuracy
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
        resultSnapshots: [StudentProgressResultSnapshot],
        attendanceSnapshots: [StudentProgressAttendanceSnapshot],
        scoreSnapshots: [StudentProgressScoreSnapshot],
        runningRecordSnapshots: [StudentProgressRunningRecordSnapshot]
    ) -> StudentProgressComputation {
        let resultsForStudent = resultSnapshots.filter { $0.studentIDKey == studentIDKey }
        let resultIndices = resultsForStudent.map(\.index)
        let scoredResultIndices = resultsForStudent.filter(\.isScored).map(\.index)
        let recentResultIndices = Array(
            resultsForStudent
                .sorted { lhs, rhs in
                    if lhs.assessmentSortOrder == rhs.assessmentSortOrder {
                        return lhs.index < rhs.index
                    }
                    return lhs.assessmentSortOrder > rhs.assessmentSortOrder
                }
                .prefix(5)
                .map(\.index)
        )

        var subjectByID: [UUID: StudentProgressSubjectWorkingSet] = [:]
        for snapshot in resultsForStudent {
            guard let subjectID = snapshot.subjectID else { continue }
            var workingSet = subjectByID[subjectID] ?? StudentProgressSubjectWorkingSet(
                id: subjectID,
                name: snapshot.subjectName,
                resultIndices: [],
                unitsByID: [:]
            )
            workingSet.resultIndices.append(snapshot.index)
            if let unitID = snapshot.unitID {
                var unitSet = workingSet.unitsByID[unitID] ?? StudentProgressUnitWorkingSet(
                    id: unitID,
                    name: snapshot.unitName,
                    sortOrder: snapshot.unitSortOrder,
                    resultIndices: []
                )
                unitSet.resultIndices.append(snapshot.index)
                workingSet.unitsByID[unitID] = unitSet
            }
            subjectByID[subjectID] = workingSet
        }

        let subjectComputations = subjectByID.values
            .map { subjectSet in
                let subjectAverage = averageFor(indices: subjectSet.resultIndices, snapshots: resultSnapshots)
                let units = subjectSet.unitsByID.values
                    .sorted { lhs, rhs in
                        if lhs.sortOrder == rhs.sortOrder {
                            let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                            if order == .orderedSame {
                                return lhs.id.uuidString < rhs.id.uuidString
                            }
                            return order == .orderedAscending
                        }
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    .map { unitSet in
                        StudentProgressUnitComputation(
                            unitID: unitSet.id,
                            resultIndices: unitSet.resultIndices,
                            averageScore: averageFor(indices: unitSet.resultIndices, snapshots: resultSnapshots)
                        )
                    }

                return StudentProgressSubjectComputation(
                    subjectID: subjectSet.id,
                    subjectName: subjectSet.name,
                    resultIndices: subjectSet.resultIndices,
                    averageScore: subjectAverage,
                    units: units
                )
            }
            .sorted { lhs, rhs in
                let order = lhs.subjectName.localizedCaseInsensitiveCompare(rhs.subjectName)
                if order == .orderedSame {
                    return lhs.subjectID.uuidString < rhs.subjectID.uuidString
                }
                return order == .orderedAscending
            }

        let attendanceForStudent = attendanceSnapshots.filter { $0.studentIDKey == studentIDKey }
        let attendanceCoordinates = attendanceForStudent.map { snapshot in
            StudentProgressAttendanceCoordinate(
                sessionIndex: snapshot.sessionIndex,
                recordIndex: snapshot.recordIndex
            )
        }
        let attendanceSummary = attendanceForStudent.reduce(
            into: StudentProgressAttendanceCounts(total: 0, present: 0, absent: 0, late: 0, leftEarly: 0)
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

        let runningDescending = runningRecordSnapshots.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.index < rhs.index
            }
            return lhs.date > rhs.date
        }
        let runningRecordIndicesDescending = runningDescending.map(\.index)
        let runningRecordIndicesAscending = Array(runningDescending.reversed().map(\.index))
        let runningRecordAverageAccuracy: Double
        if runningDescending.isEmpty {
            runningRecordAverageAccuracy = 0
        } else {
            let total = runningDescending.reduce(0.0) { $0 + $1.accuracy }
            runningRecordAverageAccuracy = total / Double(runningDescending.count)
        }

        let matchingScores = scoreSnapshots.filter(\.matchesStudent)
        let studentScoreIndices = matchingScores.map(\.index)
        var latestByCriterionID: [UUID: StudentProgressScoreSnapshot] = [:]
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
            .map { StudentProgressCategoryComputation(category: $0.key, scoreIndices: $0.value) }
            .sorted {
                $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
            }

        return StudentProgressComputation(
            overallAverageScore: averageFor(indices: resultIndices, snapshots: resultSnapshots),
            resultIndices: resultIndices,
            scoredResultIndices: scoredResultIndices,
            recentResultIndices: recentResultIndices,
            attendanceCoordinates: attendanceCoordinates,
            attendanceSummary: attendanceSummary,
            subjectComputations: subjectComputations,
            runningRecordIndicesDescending: runningRecordIndicesDescending,
            runningRecordIndicesAscending: runningRecordIndicesAscending,
            runningRecordAverageAccuracy: runningRecordAverageAccuracy,
            latestRunningRecordIndex: runningRecordIndicesDescending.first,
            studentScoreIndices: studentScoreIndices,
            latestScoreIndices: latestScoreIndices,
            groupedCategoryScores: groupedCategoryScores
        )
    }

    nonisolated private static func averageFor(
        indices: [Int],
        snapshots: [StudentProgressResultSnapshot]
    ) -> Double {
        let values: [Double] = indices.compactMap { index in
            guard snapshots.indices.contains(index) else { return nil }
            return snapshots[index].normalizedScoreOutOfTen
        }
        if values.isEmpty {
            return 0
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func makeDerivedData(
        student: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore],
        allLiveObservations: [LiveObservation],
        runningRecords: [RunningRecord],
        computation: StudentProgressComputation
    ) -> StudentProgressDerivedData {
        let resultsForStudent = computation.resultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }
        let scoredResultsForStudent = computation.scoredResultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }
        let recentResults = computation.recentResultIndices.compactMap { index in
            allResults.indices.contains(index) ? allResults[index] : nil
        }
        let attendanceRecordsForStudent: [AttendanceRecord] = computation.attendanceCoordinates.compactMap { coordinate in
            guard allAttendanceSessions.indices.contains(coordinate.sessionIndex) else { return nil }
            let session = allAttendanceSessions[coordinate.sessionIndex]
            guard session.records.indices.contains(coordinate.recordIndex) else { return nil }
            return session.records[coordinate.recordIndex]
        }

        var subjectByID: [UUID: Subject] = [:]
        var unitByID: [UUID: Unit] = [:]
        for result in allResults {
            if let subject = result.assessment?.unit?.subject {
                subjectByID[subject.id] = subject
            }
            if let unit = result.assessment?.unit {
                unitByID[unit.id] = unit
            }
        }

        let subjectSummaries: [StudentProgressSubjectSummary] = computation.subjectComputations.compactMap { subjectComputation in
            guard let subject = subjectByID[subjectComputation.subjectID] else { return nil }
            let subjectResults = subjectComputation.resultIndices.compactMap { index in
                allResults.indices.contains(index) ? allResults[index] : nil
            }
            let units: [StudentProgressUnitSummary] = subjectComputation.units.compactMap { unitComputation in
                guard let unit = unitByID[unitComputation.unitID] else { return nil }
                let unitResults = unitComputation.resultIndices.compactMap { index in
                    allResults.indices.contains(index) ? allResults[index] : nil
                }
                return StudentProgressUnitSummary(
                    unit: unit,
                    results: unitResults,
                    averageScore: unitComputation.averageScore
                )
            }

            return StudentProgressSubjectSummary(
                subject: subject,
                results: subjectResults,
                averageScore: subjectComputation.averageScore,
                units: units
            )
        }
        let subjectOverviewViewModels = subjectSummaries.map { summary in
            StudentProgressSubjectOverviewViewModel(
                id: summary.subject.id,
                subjectName: summary.subject.name,
                assessmentCount: summary.results.count,
                averageScore: summary.averageScore
            )
        }
        let subjectSectionViewModels = subjectSummaries.map { summary in
            StudentProgressSubjectSectionViewModel(
                id: summary.subject.id,
                subjectName: summary.subject.name,
                assessmentCount: summary.results.count,
                averageScore: summary.averageScore,
                units: summary.units.map { unit in
                    StudentProgressUnitRowViewModel(
                        id: unit.unit.id,
                        unitName: unit.unit.name,
                        criteriaCount: unit.results.count,
                        averageScore: unit.averageScore
                    )
                }
            )
        }
        let subjectSummariesByID = Dictionary(uniqueKeysWithValues: subjectSummaries.map { ($0.subject.id, $0) })

        let runningRecordsDescending = computation.runningRecordIndicesDescending.compactMap { index in
            runningRecords.indices.contains(index) ? runningRecords[index] : nil
        }
        let runningRecordsAscending = computation.runningRecordIndicesAscending.compactMap { index in
            runningRecords.indices.contains(index) ? runningRecords[index] : nil
        }
        let runningRecordViewModelsDescending = runningRecordsDescending.map { record in
            StudentProgressRunningRecordViewModel(
                id: String(describing: record.id),
                title: record.textTitle,
                date: record.date,
                accuracy: record.accuracy,
                readingLevel: record.readingLevel,
                notes: record.notes
            )
        }
        let runningRecordViewModelsAscending = runningRecordsAscending.map { record in
            StudentProgressRunningRecordViewModel(
                id: String(describing: record.id),
                title: record.textTitle,
                date: record.date,
                accuracy: record.accuracy,
                readingLevel: record.readingLevel,
                notes: record.notes
            )
        }
        let latestRunningRecord = computation.latestRunningRecordIndex.flatMap { index in
            runningRecords.indices.contains(index) ? runningRecords[index] : nil
        }
        let latestRunningRecordViewModel = latestRunningRecord.map { record in
            StudentProgressRunningRecordViewModel(
                id: String(describing: record.id),
                title: record.textTitle,
                date: record.date,
                accuracy: record.accuracy,
                readingLevel: record.readingLevel,
                notes: record.notes
            )
        }

        let studentDevelopmentScores = computation.studentScoreIndices.compactMap { index in
            allDevelopmentScores.indices.contains(index) ? allDevelopmentScores[index] : nil
        }
        let latestDevelopmentScores = computation.latestScoreIndices.compactMap { index in
            allDevelopmentScores.indices.contains(index) ? allDevelopmentScores[index] : nil
        }
        let groupedLatestDevelopmentScores = computation.groupedCategoryScores.map { group in
            StudentProgressDevelopmentCategory(
                category: group.category,
                scores: group.scoreIndices.compactMap { index in
                    allDevelopmentScores.indices.contains(index) ? allDevelopmentScores[index] : nil
                }
            )
        }
        let developmentCategoryViewModels = computation.groupedCategoryScores.map { group in
            StudentProgressDevelopmentCategoryViewModel(
                id: group.category,
                category: group.category,
                scores: group.scoreIndices.compactMap { index in
                    guard allDevelopmentScores.indices.contains(index) else { return nil }
                    let score = allDevelopmentScores[index]
                    return StudentProgressDevelopmentScoreViewModel(
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

        let liveObservationsForStudent = allLiveObservations
            .filter { observation in
                observation.studentUUID == student.uuid
            }
            .sorted { $0.createdAt > $1.createdAt }

        let latestObservation = liveObservationsForStudent.first.map { observation in
            StudentProgressLatestObservationViewModel(
                createdAt: observation.createdAt,
                understandingLevel: observation.understandingLevel,
                engagementLevel: observation.engagementLevel,
                supportLevel: observation.supportLevel,
                note: observation.note,
                checklistItems: observation.checklistResponses
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map {
                        StudentProgressObservationChecklistItemViewModel(
                            id: $0.id.uuidString,
                            title: $0.criterionTitle,
                            level: $0.level
                        )
                    }
            )
        }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let observationsTodayCount = liveObservationsForStudent.filter {
            $0.createdAt >= startOfToday && $0.createdAt < startOfTomorrow
        }.count

        let recentSupportCounts = LiveObservationLevel.allCases.map { level in
            StudentProgressObservationLevelCountViewModel(
                id: level.rawValue,
                level: level,
                count: liveObservationsForStudent.prefix(8).filter { $0.supportLevel == level }.count
            )
        }

        let assessmentActivities = recentResults.compactMap { result -> StudentProgressRecentActivityViewModel? in
            guard let assessmentDate = result.assessment?.date else { return nil }
            return StudentProgressRecentActivityViewModel(
                id: "assessment-\(result.id)",
                kind: .assessment,
                title: result.assessment?.title ?? "Assessment".localized,
                subtitle: result.assessment?.unit?.subject?.name,
                detailText: String(format: "Score: %.1f".localized, result.score),
                date: assessmentDate,
                score: result.score,
                observationSupportLevel: nil
            )
        }

        let observationActivities = liveObservationsForStudent.prefix(5).map { observation in
            StudentProgressRecentActivityViewModel(
                id: "live-\(observation.id.uuidString)",
                kind: .liveCheckIn,
                title: "Live Check-In".localized,
                subtitle: observation.source.title,
                detailText: "U: \(observation.understandingLevel.title) • E: \(observation.engagementLevel.title) • S: \(observation.supportLevel.title)",
                date: observation.createdAt,
                score: nil,
                observationSupportLevel: observation.supportLevel
            )
        }

        let recentActivityViewModels = (assessmentActivities + observationActivities)
            .sorted { $0.date > $1.date }
            .prefix(6)
            .map { $0 }

        return StudentProgressDerivedData(
            overallAverageScore: computation.overallAverageScore,
            resultsForStudent: resultsForStudent,
            scoredResultsForStudent: scoredResultsForStudent,
            recentActivityViewModels: recentActivityViewModels,
            attendanceRecordsForStudent: attendanceRecordsForStudent,
            subjectOverviewViewModels: subjectOverviewViewModels,
            subjectSectionViewModels: subjectSectionViewModels,
            subjectsForStudent: subjectSummaries.map(\.subject),
            studentDevelopmentScores: studentDevelopmentScores,
            attendanceSummary: StudentProgressAttendanceSummary(
                totalSessions: computation.attendanceSummary.total,
                present: computation.attendanceSummary.present,
                absent: computation.attendanceSummary.absent,
                late: computation.attendanceSummary.late,
                leftEarly: computation.attendanceSummary.leftEarly
            ),
            recentResults: recentResults,
            liveObservationsForStudent: liveObservationsForStudent,
            observationSummary: StudentProgressObservationSummaryViewModel(
                totalObservationCount: liveObservationsForStudent.count,
                observationsTodayCount: observationsTodayCount,
                latestObservation: latestObservation,
                recentSupportCounts: recentSupportCounts
            ),
            subjectSummaries: subjectSummaries,
            subjectSummariesByID: subjectSummariesByID,
            runningRecordsDescending: runningRecordsDescending,
            runningRecordsAscending: runningRecordsAscending,
            runningRecordViewModelsDescending: runningRecordViewModelsDescending,
            runningRecordViewModelsAscending: runningRecordViewModelsAscending,
            runningRecordAverageAccuracy: computation.runningRecordAverageAccuracy,
            latestRunningRecord: latestRunningRecord,
            latestRunningRecordViewModel: latestRunningRecordViewModel,
            latestDevelopmentScores: latestDevelopmentScores,
            groupedLatestDevelopmentScores: groupedLatestDevelopmentScores,
            developmentCategoryViewModels: developmentCategoryViewModels
        )
    }
}

private struct StudentProgressResultSnapshot: Sendable {
    let index: Int
    let studentIDKey: String?
    let isScored: Bool
    let normalizedScoreOutOfTen: Double?
    let assessmentSortOrder: Int
    let subjectID: UUID?
    let subjectName: String
    let unitID: UUID?
    let unitName: String
    let unitSortOrder: Int
}

private struct StudentProgressAttendanceSnapshot: Sendable {
    let sessionIndex: Int
    let recordIndex: Int
    let studentIDKey: String?
    let statusRaw: String
}

private struct StudentProgressAttendanceCoordinate: Sendable {
    let sessionIndex: Int
    let recordIndex: Int
}

private struct StudentProgressRunningRecordSnapshot: Sendable {
    let index: Int
    let date: Date
    let accuracy: Double
}

private struct StudentProgressScoreSnapshot: Sendable {
    let index: Int
    let matchesStudent: Bool
    let criterionID: UUID?
    let date: Date
    let criterionSortOrder: Int
    let categoryName: String
}

private struct StudentProgressAttendanceCounts: Sendable {
    var total: Int
    var present: Int
    var absent: Int
    var late: Int
    var leftEarly: Int
}

private struct StudentProgressUnitWorkingSet: Sendable {
    let id: UUID
    let name: String
    let sortOrder: Int
    var resultIndices: [Int]
}

private struct StudentProgressSubjectWorkingSet: Sendable {
    let id: UUID
    let name: String
    var resultIndices: [Int]
    var unitsByID: [UUID: StudentProgressUnitWorkingSet]
}

private struct StudentProgressUnitComputation: Sendable {
    let unitID: UUID
    let resultIndices: [Int]
    let averageScore: Double
}

private struct StudentProgressSubjectComputation: Sendable {
    let subjectID: UUID
    let subjectName: String
    let resultIndices: [Int]
    let averageScore: Double
    let units: [StudentProgressUnitComputation]
}

private struct StudentProgressCategoryComputation: Sendable {
    let category: String
    let scoreIndices: [Int]
}

private struct StudentProgressComputation: Sendable {
    let overallAverageScore: Double
    let resultIndices: [Int]
    let scoredResultIndices: [Int]
    let recentResultIndices: [Int]
    let attendanceCoordinates: [StudentProgressAttendanceCoordinate]
    let attendanceSummary: StudentProgressAttendanceCounts
    let subjectComputations: [StudentProgressSubjectComputation]
    let runningRecordIndicesDescending: [Int]
    let runningRecordIndicesAscending: [Int]
    let runningRecordAverageAccuracy: Double
    let latestRunningRecordIndex: Int?
    let studentScoreIndices: [Int]
    let latestScoreIndices: [Int]
    let groupedCategoryScores: [StudentProgressCategoryComputation]
}
