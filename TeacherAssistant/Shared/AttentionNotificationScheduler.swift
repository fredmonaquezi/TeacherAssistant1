import SwiftUI
import SwiftData

struct AttentionNotificationScheduler: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var notificationManager: AttentionNotificationManager

    @AppStorage(AppPreferencesKeys.attentionNotificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppPreferencesKeys.attentionNotificationHour) private var notificationHour = 7
    @AppStorage(AppPreferencesKeys.attentionNotificationMinute) private var notificationMinute = 30

    @Query private var assessments: [Assessment]
    @Query private var assignments: [Assignment]
    @Query private var interventions: [Intervention]
    @State private var derivedData: AttentionSummaryDerivedData = .empty
    @State private var reviewRefreshRevision = 0
    @State private var saveRefreshRevision = 0
    @State private var didRefreshAuthorization = false

    private let calendar = Calendar.current

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var reviewedAssignmentIDsToday: Set<UUID> {
        _ = reviewRefreshRevision
        return AttentionAssignmentReviewStore.reviewedAssignmentIDsForToday()
    }

    private var refreshToken: String {
        [
            String(assessments.count),
            String(assignments.count),
            String(interventions.count),
            String(reviewRefreshRevision),
            String(saveRefreshRevision),
        ].joined(separator: "|")
    }

    private var overdueInterventions: [Intervention] {
        derivedData.overdueInterventions.compactMap(\.intervention)
    }

    private var todayInterventions: [Intervention] {
        derivedData.todayInterventions.compactMap(\.intervention)
    }

    private var overdueAssignmentItems: [AttentionAssignmentItem] {
        derivedData.overdueAssignments.map {
            AttentionAssignmentItem(
                assignment: $0.assignment,
                outstandingCount: $0.outstandingCount,
                missingCount: $0.missingCount
            )
        }
    }

    private var todayAssignmentItems: [AttentionAssignmentItem] {
        derivedData.todayAssignments.map {
            AttentionAssignmentItem(
                assignment: $0.assignment,
                outstandingCount: $0.outstandingCount,
                missingCount: $0.missingCount
            )
        }
    }

    private var backlogAssessments: [Assessment] {
        derivedData.backlogAssessments
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
        derivedData.overdueInterventionCount
    }

    private var todayInterventionCount: Int {
        derivedData.todayInterventionCount
    }

    private var overdueAssignmentsCount: Int {
        derivedData.overdueAssignmentsCount
    }

    private var todayAssignmentsCount: Int {
        derivedData.todayAssignmentsCount
    }

    private var pendingGradesCount: Int {
        derivedData.pendingGradesCount
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
            .task {
                guard !didRefreshAuthorization else { return }
                didRefreshAuthorization = true
                await notificationManager.refreshAuthorizationStatus()
            }
            .task(id: refreshToken) {
                do {
                    try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
                } catch {
                    return
                }
                await refreshDerivedDataAndReschedule()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active || newPhase == .background else { return }
                scheduleAfterScenePhaseChange()
            }
            .onChange(of: notificationsEnabled) { _, _ in
                triggerReschedule()
            }
            .onChange(of: notificationHour) { _, _ in
                triggerReschedule()
            }
            .onChange(of: notificationMinute) { _, _ in
                triggerReschedule()
            }
            .onReceive(NotificationCenter.default.publisher(for: .persistenceDidSave)) { _ in
                saveRefreshRevision &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .attentionAssignmentReviewStateChanged)) { _ in
                reviewRefreshRevision &+= 1
            }
    }

    private func scheduleAfterScenePhaseChange() {
        Task {
            await notificationManager.refreshAuthorizationStatus()
            await rescheduleNotifications()
        }
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

    private func refreshDerivedDataAndReschedule() async {
        let token = await PerformanceMonitor.shared.beginInterval(.attentionDerive, metadata: "scheduler")
        let derived = await AttentionSummaryStore.deriveAsync(
            assessments: assessments,
            assignments: assignments,
            interventions: interventions,
            reviewedAssignmentIDsToday: reviewedAssignmentIDsToday
        )
        guard !Task.isCancelled else {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }
        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
        await rescheduleNotifications()
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
