import SwiftUI
import SwiftData

struct TodayDashboardCard: View {
    @Environment(\.appMotionContext) private var motion
    @ObservedObject var timerManager: ClassroomTimerManager
    @Binding var selectedSection: AppSection?

    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    @Query private var assessments: [Assessment]
    @Query private var assignments: [Assignment]
    @Query private var interventions: [Intervention]
    @Query private var calendarEvents: [CalendarEvent]
    @Query private var diaryEntries: [ClassDiaryEntry]
    @State private var derivedData: TodayDashboardDerivedData = .empty
    @State private var saveRefreshRevision = 0

    private let calendar = Calendar.current

    private var scheduleItems: [TodayScheduleItem] {
        derivedData.scheduleItems.map {
            TodayScheduleItem(
                title: $0.title,
                detail: $0.detail,
                timeLabel: $0.timeLabel,
                sortDate: $0.sortDate,
                icon: $0.icon,
                tint: $0.isAllDay ? .teal : color(for: $0.icon)
            )
        }
    }

    private var classesNeedingAttendance: [SchoolClass] {
        derivedData.classesNeedingAttendance
    }

    private var backlogItems: [TodayBacklogItem] {
        derivedData.backlogItems.map {
            TodayBacklogItem(
                assessment: $0.assessment,
                remainingCount: $0.remainingCount,
                className: $0.className,
                unitName: $0.unitName
            )
        }
    }

    private var upcomingAssessments: [Assessment] {
        derivedData.upcomingAssessments
    }

    private var pendingGradesCount: Int {
        derivedData.pendingGradesCount
    }

    private var assignmentItems: [TodayAssignmentItem] {
        derivedData.assignmentItems.map {
            TodayAssignmentItem(
                assignment: $0.assignment,
                pendingCount: $0.pendingCount,
                missingCount: $0.missingCount,
                className: $0.className,
                unitName: $0.unitName,
                isOverdue: $0.isOverdue,
                dueLabel: $0.dueLabel
            )
        }
    }

    private var dueSoonAssignmentsCount: Int {
        derivedData.dueSoonAssignmentsCount
    }

    private var missingAssignmentsCount: Int {
        derivedData.missingAssignmentsCount
    }

    private var interventionItems: [TodayInterventionItem] {
        derivedData.interventionItems.map {
            TodayInterventionItem(
                intervention: $0.intervention,
                student: $0.student,
                followUpDate: $0.followUpDate,
                className: $0.className,
                isOverdue: $0.isOverdue,
                dueLabel: $0.dueLabel
            )
        }
    }

    private var followUpsCount: Int {
        derivedData.followUpsCount
    }

    private var overdueFollowUpsCount: Int {
        derivedData.overdueFollowUpsCount
    }

    private var refreshToken: String {
        [
            String(classes.count),
            String(assessments.count),
            String(assignments.count),
            String(interventions.count),
            String(calendarEvents.count),
            String(diaryEntries.count),
            String(saveRefreshRevision),
        ].joined(separator: "|")
    }

    private var focusActions: [TodayQuickActionItem] {
        var actions: [TodayQuickActionItem] = []

        if !classesNeedingAttendance.isEmpty {
            actions.append(
                TodayQuickActionItem(
                    title: "Take Attendance".localized,
                    subtitle: String(
                        format: "%d classes pending".localized,
                        classesNeedingAttendance.count
                    ),
                    icon: "checklist",
                    tint: .green
                ) {
                    selectedSection = .attendance
                }
            )
        }

        if pendingGradesCount > 0 {
            actions.append(
                TodayQuickActionItem(
                    title: "Review Gradebook".localized,
                    subtitle: String(
                        format: "%d grades pending".localized,
                        pendingGradesCount
                    ),
                    icon: "tablecells",
                    tint: .orange
                ) {
                    selectedSection = .gradebook
                }
            )
        }

        if missingAssignmentsCount > 0 {
            actions.append(
                TodayQuickActionItem(
                    title: "Check Missing Work".localized,
                    subtitle: String(
                        format: "%d overdue submissions".localized,
                        missingAssignmentsCount
                    ),
                    icon: "list.clipboard.fill",
                    tint: .red
                ) {
                    selectedSection = .classes
                }
            )
        } else if !assignmentItems.isEmpty {
            actions.append(
                TodayQuickActionItem(
                    title: "Review Assignments".localized,
                    subtitle: String(
                        format: "%d due this week".localized,
                        dueSoonAssignmentsCount
                    ),
                    icon: "list.clipboard.fill",
                    tint: .teal
                ) {
                    selectedSection = .classes
                }
            )
        }

        if overdueFollowUpsCount > 0 {
            actions.append(
                TodayQuickActionItem(
                    title: "Follow Up Students".localized,
                    subtitle: String(
                        format: "%d overdue plans".localized,
                        overdueFollowUpsCount
                    ),
                    icon: "cross.case.fill",
                    tint: .indigo
                ) {
                    selectedSection = .classes
                }
            )
        } else if followUpsCount > 0 {
            actions.append(
                TodayQuickActionItem(
                    title: "Review Follow Ups".localized,
                    subtitle: String(
                        format: "%d plans this week".localized,
                        followUpsCount
                    ),
                    icon: "cross.case.fill",
                    tint: .indigo
                ) {
                    selectedSection = .classes
                }
            )
        }

        actions.append(
            TodayQuickActionItem(
                title: timerManager.isRunning ? "Resume Timer".localized : "Start 10 min".localized,
                subtitle: timerManager.isRunning ? "continue the live timer".localized : "quick lesson pacing".localized,
                icon: "timer",
                tint: .red
            ) {
                if timerManager.isRunning {
                    timerManager.isExpanded = true
                } else {
                    timerManager.start(minutes: 10)
                }
            }
        )

        if actions.isEmpty {
            actions.append(
                TodayQuickActionItem(
                    title: "Open Calendar".localized,
                    subtitle: "check today's plan".localized,
                    icon: "calendar",
                    tint: .teal
                ) {
                    selectedSection = .calendar
                }
            )
        }

        return Array(actions.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statsRow
            focusActionsSection
            scheduleSection
            attentionSection
        }
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.teal.opacity(0.12),
            tint: .teal
        )
        .padding(.horizontal)
        .onReceive(NotificationCenter.default.publisher(for: .persistenceDidSave)) { _ in
            saveRefreshRevision &+= 1
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

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.teal)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Today".localized)
                    .font(.title2.weight(.semibold))

                Text(Date().appDateString(systemStyle: .full))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("See today's schedule, attendance still to take, grading backlog, assignments, and intervention follow-ups from one place.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if timerManager.isRunning {
                Button {
                    timerManager.isExpanded = true
                } label: {
                    Label(timerManager.formattedTime, systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .transition(motion.transition(.inlineChange))
            }
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            statCard(
                title: "Schedule".localized,
                value: "\(scheduleItems.count)",
                subtitle: "items today".localized,
                icon: "calendar.badge.clock",
                color: .teal
            )
            .appMotionReveal(index: 0)

            statCard(
                title: "Attendance".localized,
                value: "\(classesNeedingAttendance.count)",
                subtitle: "classes pending".localized,
                icon: "checklist",
                color: classesNeedingAttendance.isEmpty ? .green : .orange
            )
            .appMotionReveal(index: 1)

            statCard(
                title: "Backlog".localized,
                value: "\(pendingGradesCount)",
                subtitle: "grades pending".localized,
                icon: "tray.full.fill",
                color: pendingGradesCount > 0 ? .orange : .green
            )
            .appMotionReveal(index: 2)

            statCard(
                title: "Assessments".localized,
                value: "\(upcomingAssessments.count)",
                subtitle: "next 7 days".localized,
                icon: "doc.text.fill",
                color: upcomingAssessments.isEmpty ? .secondary : .blue
            )
            .appMotionReveal(index: 3)

            statCard(
                title: "Homework".localized,
                value: "\(dueSoonAssignmentsCount)",
                subtitle: "due this week".localized,
                icon: "list.clipboard.fill",
                color: dueSoonAssignmentsCount > 0 ? .teal : .secondary
            )
            .appMotionReveal(index: 4)

            statCard(
                title: "Missing Work".localized,
                value: "\(missingAssignmentsCount)",
                subtitle: "overdue submissions".localized,
                icon: "exclamationmark.bubble.fill",
                color: missingAssignmentsCount > 0 ? .red : .green
            )
            .appMotionReveal(index: 5)

            statCard(
                title: "Follow Ups".localized,
                value: "\(followUpsCount)",
                subtitle: "next 7 days".localized,
                icon: "cross.case.fill",
                color: followUpsCount > 0 ? .indigo : .secondary
            )
            .appMotionReveal(index: 6)

            statCard(
                title: "Overdue Plans".localized,
                value: "\(overdueFollowUpsCount)",
                subtitle: "need follow-up".localized,
                icon: "exclamationmark.circle.fill",
                color: overdueFollowUpsCount > 0 ? .red : .green
            )
            .appMotionReveal(index: 7)
        }
    }

    private var focusActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Focus Actions".localized)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(Array(focusActions.enumerated()), id: \.element.id) { index, item in
                    focusActionCard(item: item)
                        .appMotionReveal(index: index, axis: .horizontal)
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Today's Schedule".localized,
                    actionTitle: "Calendar".localized
                ) {
                    selectedSection = .calendar
                }

            if scheduleItems.isEmpty {
                emptyState(
                    icon: "calendar.badge.exclamationmark",
                    title: "Nothing scheduled yet".localized,
                    message: "Calendar events and class diary entries for today will appear here.".localized
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(scheduleItems.prefix(4).enumerated()), id: \.element.id) { index, item in
                        scheduleRow(item: item)
                            .appMotionReveal(index: index)
                    }
                }
            }
        }
    }

    private var attentionSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Attendance To Take".localized,
                    actionTitle: "Attendance".localized
                ) {
                    selectedSection = .attendance
                }

                if classesNeedingAttendance.isEmpty {
                    compactEmptyState("Attendance is up to date for today.".localized)
                } else {
                    VStack(spacing: 10) {
                        ForEach(classesNeedingAttendance.prefix(3), id: \.id) { schoolClass in
                            NavigationLink {
                                AttendanceListView(schoolClass: schoolClass)
                            } label: {
                                classAttendanceRow(for: schoolClass)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Needs Grading".localized,
                    actionTitle: "Gradebook".localized
                ) {
                    selectedSection = .gradebook
                }

                if backlogItems.isEmpty {
                    compactEmptyState("No grading backlog right now.".localized)
                } else {
                    VStack(spacing: 10) {
                        ForEach(backlogItems.prefix(3)) { item in
                            NavigationLink {
                                AssessmentDetailView(assessment: item.assessment)
                            } label: {
                                backlogRow(item: item)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Assignments Due".localized)

                if assignmentItems.isEmpty {
                    compactEmptyState("No due-soon or overdue assignments right now.".localized)
                } else {
                    VStack(spacing: 10) {
                        ForEach(assignmentItems.prefix(3)) { item in
                            NavigationLink {
                                AssignmentDetailView(assignment: item.assignment)
                            } label: {
                                assignmentRow(item: item)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Intervention Follow Ups".localized)

                if interventionItems.isEmpty {
                    compactEmptyState("No overdue or upcoming intervention follow-ups right now.".localized)
                } else {
                    VStack(spacing: 10) {
                        ForEach(interventionItems.prefix(3)) { item in
                            NavigationLink {
                                StudentDetailView(student: item.student)
                            } label: {
                                interventionRow(item: item)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(color)
                .contentTransition(.numericText())

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: color.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: color
        )
        .transition(motion.transition(.cardReveal))
    }

    private func focusActionCard(item: TodayQuickActionItem) -> some View {
        Button(action: item.action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.tint.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: item.icon)
                        .font(.headline)
                        .foregroundColor(item.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    private func sectionHeader(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.cardTitle)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private func scheduleRow(item: TodayScheduleItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundColor(item.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(item.timeLabel)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
        .transition(motion.transition(.inlineChange))
    }

    private func classAttendanceRow(for schoolClass: SchoolClass) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schoolClass.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("\(schoolClass.students.count) " + "students".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Label("Open".localized, systemImage: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
        .transition(motion.transition(.inlineChange))
    }

    private func backlogRow(item: TodayBacklogItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.assessment.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text([item.className, item.unitName].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%d left".localized, item.remainingCount))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)

                Text(item.assessment.date.appDateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
        .transition(motion.transition(.inlineChange))
    }

    private func assignmentRow(item: TodayAssignmentItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.assignment.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text([item.className, item.unitName].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    assignmentPill(
                        text: String(format: "%d pending".localized, item.pendingCount),
                        tint: .orange
                    )

                    if item.missingCount > 0 {
                        assignmentPill(
                            text: String(format: "%d missing".localized, item.missingCount),
                            tint: .red
                        )
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.dueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(item.isOverdue ? .red : .teal)

                Text(item.assignment.dueDate.appDateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
        .transition(motion.transition(.inlineChange))
    }

    private func interventionRow(item: TodayInterventionItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.intervention.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text([item.student.name, item.className].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    interventionPill(text: item.intervention.category.title, tint: .indigo)
                    interventionPill(
                        text: item.intervention.status.title,
                        tint: item.intervention.status == .open ? .orange : .teal
                    )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.dueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(item.isOverdue ? .red : .indigo)

                Text(item.followUpDate.appDateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
        .transition(motion.transition(.inlineChange))
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
    }

    private func compactEmptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
    }

    private func assignmentPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func interventionPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func color(for icon: String) -> Color {
        switch icon {
        case "text.book.closed":
            return .orange
        case "clock":
            return .teal
        default:
            return .teal
        }
    }

    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.dashboardDerive)
        let derived = await TodayDashboardStore.deriveAsync(
            classes: classes,
            assessments: assessments,
            assignments: assignments,
            interventions: interventions,
            calendarEvents: calendarEvents,
            diaryEntries: diaryEntries
        )
        guard !Task.isCancelled else {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }
        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
    }
}

private struct TodayScheduleItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let timeLabel: String
    let sortDate: Date
    let icon: String
    let tint: Color
}

private struct TodayBacklogItem: Identifiable {
    let assessment: Assessment
    let remainingCount: Int
    let className: String
    let unitName: String

    var id: PersistentIdentifier {
        assessment.persistentModelID
    }
}

private struct TodayAssignmentItem: Identifiable {
    let assignment: Assignment
    let pendingCount: Int
    let missingCount: Int
    let className: String
    let unitName: String
    let isOverdue: Bool
    let dueLabel: String

    var id: PersistentIdentifier {
        assignment.persistentModelID
    }
}

private struct TodayInterventionItem: Identifiable {
    let intervention: Intervention
    let student: Student
    let followUpDate: Date
    let className: String
    let isOverdue: Bool
    let dueLabel: String

    var id: PersistentIdentifier {
        intervention.persistentModelID
    }
}

private struct TodayQuickActionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void
}
