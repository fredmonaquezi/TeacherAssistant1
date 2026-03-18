import Foundation
import SwiftData

struct AttentionSummaryAssignmentItem: Identifiable {
    let assignment: Assignment
    let outstandingCount: Int
    let missingCount: Int

    var id: PersistentIdentifier {
        assignment.persistentModelID
    }
}

struct AttentionSummaryInterventionItem: Identifiable {
    let intervention: Intervention
    let followUpDate: Date

    var id: PersistentIdentifier {
        intervention.persistentModelID
    }
}

struct AttentionSummaryDerivedData {
    let overdueInterventions: [AttentionSummaryInterventionItem]
    let todayInterventions: [AttentionSummaryInterventionItem]
    let overdueAssignments: [AttentionSummaryAssignmentItem]
    let todayAssignments: [AttentionSummaryAssignmentItem]
    let backlogAssessments: [Assessment]
    let overdueInterventionCount: Int
    let todayInterventionCount: Int
    let overdueAssignmentsCount: Int
    let todayAssignmentsCount: Int
    let pendingGradesCount: Int

    static let empty = AttentionSummaryDerivedData(
        overdueInterventions: [],
        todayInterventions: [],
        overdueAssignments: [],
        todayAssignments: [],
        backlogAssessments: [],
        overdueInterventionCount: 0,
        todayInterventionCount: 0,
        overdueAssignmentsCount: 0,
        todayAssignmentsCount: 0,
        pendingGradesCount: 0
    )
}

enum AttentionSummaryStore {
    static func derive(
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        reviewedAssignmentIDsToday: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AttentionSummaryDerivedData {
        let assessmentSnapshots = makeAssessmentSnapshots(assessments: assessments)
        let assignmentSnapshots = makeAssignmentSnapshots(
            assignments: assignments,
            reviewedAssignmentIDsToday: reviewedAssignmentIDsToday,
            now: now,
            calendar: calendar
        )
        let interventionSnapshots = makeInterventionSnapshots(
            interventions: interventions,
            now: now,
            calendar: calendar
        )
        let computation = compute(
            assessmentSnapshots: assessmentSnapshots,
            assignmentSnapshots: assignmentSnapshots,
            interventionSnapshots: interventionSnapshots
        )

        return makeDerivedData(
            assessments: assessments,
            assignments: assignments,
            interventions: interventions,
            assignmentSnapshots: assignmentSnapshots,
            interventionSnapshots: interventionSnapshots,
            computation: computation
        )
    }

    static func deriveAsync(
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        reviewedAssignmentIDsToday: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> AttentionSummaryDerivedData {
        let assessmentSnapshots = makeAssessmentSnapshots(assessments: assessments)
        let assignmentSnapshots = makeAssignmentSnapshots(
            assignments: assignments,
            reviewedAssignmentIDsToday: reviewedAssignmentIDsToday,
            now: now,
            calendar: calendar
        )
        let interventionSnapshots = makeInterventionSnapshots(
            interventions: interventions,
            now: now,
            calendar: calendar
        )

        return await DerivationRunner.runAsync(
            compute: {
                compute(
                    assessmentSnapshots: assessmentSnapshots,
                    assignmentSnapshots: assignmentSnapshots,
                    interventionSnapshots: interventionSnapshots
                )
            },
            cancelledResult: .empty
        ) { computation in
            makeDerivedData(
                assessments: assessments,
                assignments: assignments,
                interventions: interventions,
                assignmentSnapshots: assignmentSnapshots,
                interventionSnapshots: interventionSnapshots,
                computation: computation
            )
        }
    }

    private static func makeAssessmentSnapshots(assessments: [Assessment]) -> [AttentionAssessmentSnapshot] {
        assessments.enumerated().map { index, assessment in
            AttentionAssessmentSnapshot(
                index: index,
                title: assessment.title,
                date: assessment.date,
                remainingCount: assessment.results.count - assessment.results.filter(\.isResolved).count
            )
        }
    }

    private static func makeAssignmentSnapshots(
        assignments: [Assignment],
        reviewedAssignmentIDsToday: Set<UUID>,
        now: Date,
        calendar: Calendar
    ) -> [AttentionAssignmentSnapshot] {
        let startOfToday = calendar.startOfDay(for: now)
        return assignments.enumerated().map { index, assignment in
            let progress = assignment.progressSummary(now: now)
            return AttentionAssignmentSnapshot(
                index: index,
                title: assignment.title,
                dueDate: assignment.dueDate,
                reviewedToday: reviewedAssignmentIDsToday.contains(assignment.id),
                outstandingCount: progress.pendingCount + progress.missingCount,
                missingCount: progress.missingCount,
                startOfToday: startOfToday
            )
        }
    }

    private static func makeInterventionSnapshots(
        interventions: [Intervention],
        now: Date,
        calendar: Calendar
    ) -> [AttentionInterventionSnapshot] {
        let startOfToday = calendar.startOfDay(for: now)
        return interventions.enumerated().compactMap { index, intervention in
            guard intervention.status != .resolved,
                  let followUpDate = intervention.followUpDate,
                  intervention.student != nil else {
                return nil
            }

            return AttentionInterventionSnapshot(
                index: index,
                title: intervention.title,
                followUpDate: followUpDate,
                studentName: intervention.student?.name ?? "",
                startOfToday: startOfToday
            )
        }
    }

    nonisolated private static func compute(
        assessmentSnapshots: [AttentionAssessmentSnapshot],
        assignmentSnapshots: [AttentionAssignmentSnapshot],
        interventionSnapshots: [AttentionInterventionSnapshot]
    ) -> AttentionSummaryComputation {
        let overdueInterventionIndices = interventionSnapshots
            .filter(\.isOverdue)
            .sorted { lhs, rhs in
                if lhs.followUpDate != rhs.followUpDate {
                    return lhs.followUpDate < rhs.followUpDate
                }
                return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
            }
            .map(\.index)

        let todayInterventionIndices = interventionSnapshots
            .filter(\.isToday)
            .sorted { lhs, rhs in
                if lhs.followUpDate != rhs.followUpDate {
                    return lhs.followUpDate < rhs.followUpDate
                }
                return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
            }
            .map(\.index)

        let overdueAssignmentIndices = assignmentSnapshots
            .filter { !$0.reviewedToday && $0.isOverdue && $0.missingCount > 0 }
            .sorted { lhs, rhs in
                if lhs.missingCount != rhs.missingCount {
                    return lhs.missingCount > rhs.missingCount
                }
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        let todayAssignmentIndices = assignmentSnapshots
            .filter { !$0.reviewedToday && $0.isToday && $0.outstandingCount > 0 }
            .sorted { lhs, rhs in
                if lhs.outstandingCount != rhs.outstandingCount {
                    return lhs.outstandingCount > rhs.outstandingCount
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        let backlogAssessmentIndices = assessmentSnapshots
            .filter { $0.remainingCount > 0 }
            .sorted { lhs, rhs in
                if lhs.remainingCount != rhs.remainingCount {
                    return lhs.remainingCount > rhs.remainingCount
                }
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        return AttentionSummaryComputation(
            overdueInterventionIndices: overdueInterventionIndices,
            todayInterventionIndices: todayInterventionIndices,
            overdueAssignmentIndices: overdueAssignmentIndices,
            todayAssignmentIndices: todayAssignmentIndices,
            backlogAssessmentIndices: backlogAssessmentIndices,
            overdueInterventionCount: overdueInterventionIndices.count,
            todayInterventionCount: todayInterventionIndices.count,
            overdueAssignmentsCount: assignmentSnapshots.filter { !$0.reviewedToday && $0.isOverdue }.reduce(0) { $0 + $1.missingCount },
            todayAssignmentsCount: assignmentSnapshots.filter { !$0.reviewedToday && $0.isToday }.reduce(0) { $0 + $1.outstandingCount },
            pendingGradesCount: assessmentSnapshots.reduce(0) { $0 + max($1.remainingCount, 0) }
        )
    }

    private static func makeDerivedData(
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        assignmentSnapshots: [AttentionAssignmentSnapshot],
        interventionSnapshots: [AttentionInterventionSnapshot],
        computation: AttentionSummaryComputation
    ) -> AttentionSummaryDerivedData {
        let overdueInterventions = computation.overdueInterventionIndices.compactMap { index -> AttentionSummaryInterventionItem? in
            guard let intervention = interventions[safe: index],
                  let snapshot = interventionSnapshots.first(where: { $0.index == index }) else {
                return nil
            }
            return AttentionSummaryInterventionItem(intervention: intervention, followUpDate: snapshot.followUpDate)
        }

        let todayInterventions = computation.todayInterventionIndices.compactMap { index -> AttentionSummaryInterventionItem? in
            guard let intervention = interventions[safe: index],
                  let snapshot = interventionSnapshots.first(where: { $0.index == index }) else {
                return nil
            }
            return AttentionSummaryInterventionItem(intervention: intervention, followUpDate: snapshot.followUpDate)
        }

        let overdueAssignments = computation.overdueAssignmentIndices.compactMap { index -> AttentionSummaryAssignmentItem? in
            guard let assignment = assignments[safe: index],
                  let snapshot = assignmentSnapshots[safe: index] else {
                return nil
            }
            return AttentionSummaryAssignmentItem(
                assignment: assignment,
                outstandingCount: snapshot.outstandingCount,
                missingCount: snapshot.missingCount
            )
        }

        let todayAssignments = computation.todayAssignmentIndices.compactMap { index -> AttentionSummaryAssignmentItem? in
            guard let assignment = assignments[safe: index],
                  let snapshot = assignmentSnapshots[safe: index] else {
                return nil
            }
            return AttentionSummaryAssignmentItem(
                assignment: assignment,
                outstandingCount: snapshot.outstandingCount,
                missingCount: snapshot.missingCount
            )
        }

        let backlogAssessments = computation.backlogAssessmentIndices.compactMap { assessments[safe: $0] }

        return AttentionSummaryDerivedData(
            overdueInterventions: overdueInterventions,
            todayInterventions: todayInterventions,
            overdueAssignments: overdueAssignments,
            todayAssignments: todayAssignments,
            backlogAssessments: backlogAssessments,
            overdueInterventionCount: computation.overdueInterventionCount,
            todayInterventionCount: computation.todayInterventionCount,
            overdueAssignmentsCount: computation.overdueAssignmentsCount,
            todayAssignmentsCount: computation.todayAssignmentsCount,
            pendingGradesCount: computation.pendingGradesCount
        )
    }
}

private struct AttentionAssessmentSnapshot: Sendable {
    let index: Int
    let title: String
    let date: Date
    let remainingCount: Int
}

private struct AttentionAssignmentSnapshot: Sendable {
    let index: Int
    let title: String
    let dueDate: Date
    let reviewedToday: Bool
    let outstandingCount: Int
    let missingCount: Int
    let startOfToday: Date

    nonisolated var isOverdue: Bool {
        dueDate < startOfToday
    }

    nonisolated var isToday: Bool {
        Calendar.current.isDate(dueDate, inSameDayAs: startOfToday)
    }
}

private struct AttentionInterventionSnapshot: Sendable {
    let index: Int
    let title: String
    let followUpDate: Date
    let studentName: String
    let startOfToday: Date

    nonisolated var isOverdue: Bool {
        followUpDate < startOfToday
    }

    nonisolated var isToday: Bool {
        Calendar.current.isDate(followUpDate, inSameDayAs: startOfToday)
    }
}

private struct AttentionSummaryComputation: Sendable {
    let overdueInterventionIndices: [Int]
    let todayInterventionIndices: [Int]
    let overdueAssignmentIndices: [Int]
    let todayAssignmentIndices: [Int]
    let backlogAssessmentIndices: [Int]
    let overdueInterventionCount: Int
    let todayInterventionCount: Int
    let overdueAssignmentsCount: Int
    let todayAssignmentsCount: Int
    let pendingGradesCount: Int
}
