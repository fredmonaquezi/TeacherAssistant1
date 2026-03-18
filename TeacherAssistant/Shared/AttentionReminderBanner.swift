import SwiftUI
import SwiftData

struct AttentionReminderBanner: View {
    @Environment(\.appMotionContext) private var motion
    @Binding var selectedSection: AppSection?

    @AppStorage(AppPreferencesKeys.attentionRemindersEnabled) private var remindersEnabled = true
    @AppStorage(AppPreferencesKeys.attentionRemindersLastDismissedDay) private var lastDismissedDay = ""
    @State private var reviewRefreshRevision = 0
    @State private var derivedData: AttentionSummaryDerivedData = .empty
    @State private var saveRefreshRevision = 0

    @Query private var assessments: [Assessment]
    @Query private var assignments: [Assignment]
    @Query private var interventions: [Intervention]

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

    private var dayKey: String {
        let components = calendar.dateComponents([.year, .month, .day], from: startOfToday)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var dismissedToday: Bool {
        lastDismissedDay == dayKey
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

    private var summary: AttentionReminderSummary? {
        if overdueInterventionCount > 0 {
            return AttentionReminderSummary(
                title: "Intervention Follow-Ups Overdue".localized,
                message: overdueInterventionMessage,
                actionTitle: "Open Dashboard".localized,
                actionSection: .dashboard,
                tint: .indigo,
                icon: "cross.case.fill"
            )
        }

        if overdueAssignmentsCount > 0 {
            return AttentionReminderSummary(
                title: "Missing Work Needs Review".localized,
                message: overdueAssignmentsMessage,
                actionTitle: "Open Dashboard".localized,
                actionSection: .dashboard,
                tint: .red,
                icon: "exclamationmark.bubble.fill"
            )
        }

        if todayInterventionCount > 0 || todayAssignmentsCount > 0 {
            return AttentionReminderSummary(
                title: "Today's Follow-Through".localized,
                message: todayActionMessage,
                actionTitle: "Open Dashboard".localized,
                actionSection: .dashboard,
                tint: .teal,
                icon: "calendar.badge.clock"
            )
        }

        if pendingGradesCount > 0 {
            return AttentionReminderSummary(
                title: "Grading Backlog".localized,
                message: String(format: "%d results still need grading or a final status.".localized, pendingGradesCount),
                actionTitle: "Open Gradebook".localized,
                actionSection: .gradebook,
                tint: .orange,
                icon: "tray.full.fill"
            )
        }

        return nil
    }

    private var overdueInterventionMessage: String {
        if todayInterventionCount > 0 {
            return String(
                format: "%d follow-ups are overdue and %d more are due today.".localized,
                overdueInterventionCount,
                todayInterventionCount
            )
        }

        return String(format: "%d follow-ups are overdue and need attention.".localized, overdueInterventionCount)
    }

    private var overdueAssignmentsMessage: String {
        if todayAssignmentsCount > 0 {
            return String(
                format: "%d submissions are overdue and %d more are due today.".localized,
                overdueAssignmentsCount,
                todayAssignmentsCount
            )
        }

        return String(format: "%d submissions are overdue across current assignments.".localized, overdueAssignmentsCount)
    }

    private var todayActionMessage: String {
        let segments = [
            todayInterventionCount > 0 ? String(format: "%d follow-ups due today".localized, todayInterventionCount) : nil,
            todayAssignmentsCount > 0 ? String(format: "%d assignment items due today".localized, todayAssignmentsCount) : nil,
        ].compactMap { $0 }

        return segments.joined(separator: " • ")
    }

    var body: some View {
        Group {
            if remindersEnabled, let summary, !dismissedToday {
                HStack(spacing: 14) {
                    Image(systemName: summary.icon)
                        .font(.title3)
                        .foregroundColor(summary.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(summary.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button("Later".localized) {
                            lastDismissedDay = dayKey
                        }
                        .buttonStyle(.bordered)

                        Button(summary.actionTitle) {
                            selectedSection = summary.actionSection
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(summary.tint)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(summary.tint.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(summary.tint.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .transition(motion.transition(.overlay))
            }
        }
        .animation(motion.animation(.quick), value: dismissedToday)
        .onReceive(NotificationCenter.default.publisher(for: .persistenceDidSave)) { _ in
            saveRefreshRevision &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .attentionAssignmentReviewStateChanged)) { _ in
            reviewRefreshRevision &+= 1
        }
        .task(id: refreshToken) {
            do {
                try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
            } catch {
                return
            }
            await refreshDerivedData()
        }
    }

    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.attentionDerive, metadata: "banner")
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
    }
}

private struct AttentionReminderSummary {
    let title: String
    let message: String
    let actionTitle: String
    let actionSection: AppSection
    let tint: Color
    let icon: String
}
