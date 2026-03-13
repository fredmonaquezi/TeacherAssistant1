import SwiftUI
import SwiftData

struct AttentionNotificationScheduler: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var notificationManager: AttentionNotificationManager

    @AppStorage(AppPreferencesKeys.attentionNotificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppPreferencesKeys.attentionNotificationHour) private var notificationHour = 7
    @AppStorage(AppPreferencesKeys.attentionNotificationMinute) private var notificationMinute = 30

    @Query private var assessments: [Assessment]
    @Query private var assignments: [Assignment]
    @Query private var interventions: [Intervention]

    private let calendar = Calendar.current

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var reviewedAssignmentIDsToday: Set<UUID> {
        AttentionAssignmentReviewStore.reviewedAssignmentIDsForToday()
    }

    private var overdueInterventions: [Intervention] {
        interventions
            .filter { intervention in
                guard intervention.status != .resolved, let followUpDate = intervention.followUpDate else { return false }
                return followUpDate < startOfToday && intervention.student != nil
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.followUpDate ?? .distantFuture
                let rhsDate = rhs.followUpDate ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return (lhs.student?.name ?? "").localizedCaseInsensitiveCompare(rhs.student?.name ?? "") == .orderedAscending
            }
    }

    private var todayInterventions: [Intervention] {
        interventions
            .filter { intervention in
                guard intervention.status != .resolved, let followUpDate = intervention.followUpDate else { return false }
                return calendar.isDate(followUpDate, inSameDayAs: startOfToday) && intervention.student != nil
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.followUpDate ?? .distantFuture
                let rhsDate = rhs.followUpDate ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return (lhs.student?.name ?? "").localizedCaseInsensitiveCompare(rhs.student?.name ?? "") == .orderedAscending
            }
    }

    private var overdueAssignmentItems: [AttentionAssignmentItem] {
        assignments
            .compactMap { assignment in
                let progress = assignment.progressSummary()
                guard !reviewedAssignmentIDsToday.contains(assignment.id),
                      assignment.dueDate < startOfToday,
                      progress.missingCount > 0 else { return nil }
                return AttentionAssignmentItem(assignment: assignment, outstandingCount: progress.pendingCount + progress.missingCount, missingCount: progress.missingCount)
            }
            .sorted { lhs, rhs in
                if lhs.missingCount != rhs.missingCount {
                    return lhs.missingCount > rhs.missingCount
                }
                if lhs.assignment.dueDate != rhs.assignment.dueDate {
                    return lhs.assignment.dueDate < rhs.assignment.dueDate
                }
                return lhs.assignment.title.localizedCaseInsensitiveCompare(rhs.assignment.title) == .orderedAscending
            }
    }

    private var todayAssignmentItems: [AttentionAssignmentItem] {
        assignments
            .compactMap { assignment in
                guard !reviewedAssignmentIDsToday.contains(assignment.id),
                      calendar.isDate(assignment.dueDate, inSameDayAs: startOfToday) else { return nil }
                let progress = assignment.progressSummary()
                let outstandingCount = progress.pendingCount + progress.missingCount
                guard outstandingCount > 0 else { return nil }
                return AttentionAssignmentItem(assignment: assignment, outstandingCount: outstandingCount, missingCount: progress.missingCount)
            }
            .sorted { lhs, rhs in
                if lhs.outstandingCount != rhs.outstandingCount {
                    return lhs.outstandingCount > rhs.outstandingCount
                }
                return lhs.assignment.title.localizedCaseInsensitiveCompare(rhs.assignment.title) == .orderedAscending
            }
    }

    private var backlogAssessments: [Assessment] {
        assessments
            .filter { assessment in
                assessment.results.count - assessment.results.filter(\.isResolved).count > 0
            }
            .sorted { lhs, rhs in
                let lhsRemaining = lhs.results.count - lhs.results.filter(\.isResolved).count
                let rhsRemaining = rhs.results.count - rhs.results.filter(\.isResolved).count
                if lhsRemaining != rhsRemaining {
                    return lhsRemaining > rhsRemaining
                }
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var summary: AttentionNotificationSummary? {
        if let leadingIntervention = overdueInterventions.first {
            if todayInterventionCount > 0 {
                return AttentionNotificationSummary(
                    title: "Follow-Ups Need Attention".localized,
                    body: String(
                        format: "%d follow-ups are overdue and %d more are due today.".localized,
                        overdueInterventionCount,
                        todayInterventionCount
                    ),
                    route: studentFollowUpRoute(for: leadingIntervention)
                )
            }

            return AttentionNotificationSummary(
                title: "Follow-Ups Need Attention".localized,
                body: String(format: "%d follow-ups are overdue and need attention.".localized, overdueInterventionCount),
                route: studentFollowUpRoute(for: leadingIntervention)
            )
        }

        if let leadingAssignment = overdueAssignmentItems.first {
            if todayAssignmentsCount > 0 {
                return AttentionNotificationSummary(
                    title: "Missing Work Needs Review".localized,
                    body: String(
                        format: "%d submissions are overdue and %d more are due today.".localized,
                        overdueAssignmentsCount,
                        todayAssignmentsCount
                    ),
                    route: assignmentRoute(for: leadingAssignment.assignment)
                )
            }

            return AttentionNotificationSummary(
                title: "Missing Work Needs Review".localized,
                body: String(format: "%d submissions are overdue across current assignments.".localized, overdueAssignmentsCount),
                route: assignmentRoute(for: leadingAssignment.assignment)
            )
        }

        if todayInterventionCount > 0 || todayAssignmentsCount > 0 {
            let segments = [
                todayInterventionCount > 0 ? String(format: "%d follow-ups due today".localized, todayInterventionCount) : nil,
                todayAssignmentsCount > 0 ? String(format: "%d assignment items due today".localized, todayAssignmentsCount) : nil,
            ]
            .compactMap { $0 }
            .joined(separator: " • ")

            return AttentionNotificationSummary(
                title: "Today's Follow-Through".localized,
                body: segments,
                route: todayFollowThroughRoute
            )
        }

        if let leadingAssessment = backlogAssessments.first {
            return AttentionNotificationSummary(
                title: "Grading Backlog".localized,
                body: String(format: "%d results still need grading or a final status.".localized, pendingGradesCount),
                route: assessmentRoute(for: leadingAssessment)
            )
        }

        return nil
    }

    private var overdueInterventionCount: Int {
        overdueInterventions.count
    }

    private var todayInterventionCount: Int {
        todayInterventions.count
    }

    private var overdueAssignmentsCount: Int {
        overdueAssignmentItems.reduce(0) { partialResult, item in
            partialResult + item.missingCount
        }
    }

    private var todayAssignmentsCount: Int {
        todayAssignmentItems.reduce(0) { partialResult, item in
            partialResult + item.outstandingCount
        }
    }

    private var pendingGradesCount: Int {
        assessments.reduce(0) { partialResult, assessment in
            partialResult + max(assessment.results.count - assessment.results.filter(\.isResolved).count, 0)
        }
    }

    private var todayFollowThroughRoute: AttentionNotificationRoute {
        if let intervention = todayInterventions.first {
            return studentFollowUpRoute(for: intervention)
        }
        if let assignment = todayAssignmentItems.first?.assignment {
            return assignmentRoute(for: assignment)
        }
        return AttentionNotificationRoute(
            section: .dashboard,
            destinationKind: .studentOverview,
            assessmentTitle: nil,
            assessmentDate: nil,
            unitID: nil,
            assignmentID: nil,
            studentUUID: nil,
            interventionID: nil
        )
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task { await performInitialSchedule() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active || newPhase == .background else { return }
                scheduleAfterScenePhaseChange()
            }
            .onChange(of: notificationsEnabled) { _, _ in
                syncAssignmentsAndReschedule()
            }
            .onChange(of: notificationHour) { _, _ in
                triggerReschedule()
            }
            .onChange(of: notificationMinute) { _, _ in
                triggerReschedule()
            }
            .onChange(of: assessments.count) { _, _ in
                triggerReschedule()
            }
            .onChange(of: assignments.count) { _, _ in
                syncAssignmentsAndReschedule()
            }
            .onChange(of: interventions.count) { _, _ in
                triggerReschedule()
            }
            .onReceive(NotificationCenter.default.publisher(for: .attentionAssignmentReviewStateChanged)) { _ in
                triggerReschedule()
            }
    }

    private func performInitialSchedule() async {
        syncAssignmentEntries()
        await notificationManager.refreshAuthorizationStatus()
        await rescheduleNotifications()
    }

    private func scheduleAfterScenePhaseChange() {
        syncAssignmentEntries()
        Task {
            await notificationManager.refreshAuthorizationStatus()
            await rescheduleNotifications()
        }
    }

    private func syncAssignmentsAndReschedule() {
        syncAssignmentEntries()
        triggerReschedule()
    }

    private func triggerReschedule() {
        Task { await rescheduleNotifications() }
    }

    private func rescheduleNotifications() async {
        await notificationManager.configureNotifications(
            enabled: notificationsEnabled,
            summary: summary,
            hour: notificationHour,
            minute: notificationMinute
        )
    }

    private func syncAssignmentEntries() {
        for assignment in assignments {
            guard let classStudents = assignment.unit?.subject?.schoolClass?.students else { continue }
            assignment.ensureEntries(for: classStudents, context: context)
        }
    }

    private func studentFollowUpRoute(for intervention: Intervention) -> AttentionNotificationRoute {
        AttentionNotificationRoute(
            section: .dashboard,
            destinationKind: .studentFollowUp,
            assessmentTitle: nil,
            assessmentDate: nil,
            unitID: nil,
            assignmentID: nil,
            studentUUID: intervention.student?.uuid,
            interventionID: intervention.id
        )
    }

    private func assignmentRoute(for assignment: Assignment) -> AttentionNotificationRoute {
        AttentionNotificationRoute(
            section: .dashboard,
            destinationKind: .assignment,
            assessmentTitle: nil,
            assessmentDate: nil,
            unitID: nil,
            assignmentID: assignment.id,
            studentUUID: nil,
            interventionID: nil
        )
    }

    private func assessmentRoute(for assessment: Assessment) -> AttentionNotificationRoute {
        AttentionNotificationRoute(
            section: .gradebook,
            destinationKind: .assessment,
            assessmentTitle: assessment.title,
            assessmentDate: assessment.date,
            unitID: assessment.unit?.id,
            assignmentID: nil,
            studentUUID: nil,
            interventionID: nil
        )
    }
}

private struct AttentionAssignmentItem {
    let assignment: Assignment
    let outstandingCount: Int
    let missingCount: Int
}
