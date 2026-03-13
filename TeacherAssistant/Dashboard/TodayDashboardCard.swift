import SwiftUI
import SwiftData

struct TodayDashboardCard: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var timerManager: ClassroomTimerManager
    @Binding var selectedSection: AppSection?

    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    @Query private var assessments: [Assessment]
    @Query private var assignments: [Assignment]
    @Query private var interventions: [Intervention]
    @Query private var calendarEvents: [CalendarEvent]
    @Query private var diaryEntries: [ClassDiaryEntry]

    private let calendar = Calendar.current

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var startOfTomorrow: Date {
        calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    private var nextWeekBoundary: Date {
        calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfTomorrow
    }

    private var orderedClasses: [SchoolClass] {
        classes.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var scheduleItems: [TodayScheduleItem] {
        let eventItems = calendarEvents
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .map { event in
                TodayScheduleItem(
                    title: event.title,
                    detail: contextLine(
                        className: event.schoolClass?.name,
                        secondary: contextualDetail(
                            primary: event.assignment?.title,
                            secondary: event.details
                        )
                    ),
                    timeLabel: formattedTimeRange(
                        date: event.date,
                        startTime: event.startTime,
                        endTime: event.endTime,
                        isAllDay: event.isAllDay
                    ),
                    sortDate: combinedDate(for: event.date, time: event.startTime),
                    icon: event.isAllDay ? "calendar" : "clock",
                    tint: .teal
                )
            }

        let diaryItems = diaryEntries
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .map { entry in
                TodayScheduleItem(
                    title: firstNonEmpty(entry.plan, fallback: "Class Diary".localized),
                    detail: contextLine(
                        className: entry.schoolClass?.name,
                        secondary: contextualDetail(
                            primary: entry.assignment?.title,
                            secondary: entry.subject?.name ?? entry.unit?.name ?? entry.notes
                        )
                    ),
                    timeLabel: formattedTimeRange(
                        date: entry.date,
                        startTime: entry.startTime,
                        endTime: entry.endTime,
                        isAllDay: false,
                        fallback: "Planned class".localized
                    ),
                    sortDate: combinedDate(for: entry.date, time: entry.startTime),
                    icon: "text.book.closed",
                    tint: .orange
                )
            }

        return (eventItems + diaryItems).sorted { lhs, rhs in
            if lhs.sortDate != rhs.sortDate {
                return lhs.sortDate < rhs.sortDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var classesNeedingAttendance: [SchoolClass] {
        orderedClasses.filter { schoolClass in
            !schoolClass.attendanceSessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: startOfToday)
            }
        }
    }

    private var backlogItems: [TodayBacklogItem] {
        assessments
            .compactMap { assessment in
                let remainingCount = assessment.results.count - assessment.results.filter(\.isResolved).count
                guard remainingCount > 0 else { return nil }

                return TodayBacklogItem(
                    assessment: assessment,
                    remainingCount: remainingCount,
                    className: assessment.unit?.subject?.schoolClass?.name ?? "",
                    unitName: assessment.unit?.name ?? ""
                )
            }
            .sorted { lhs, rhs in
                if lhs.remainingCount != rhs.remainingCount {
                    return lhs.remainingCount > rhs.remainingCount
                }
                if lhs.assessment.date != rhs.assessment.date {
                    return lhs.assessment.date < rhs.assessment.date
                }
                return lhs.assessment.title.localizedCaseInsensitiveCompare(rhs.assessment.title) == .orderedAscending
            }
    }

    private var upcomingAssessments: [Assessment] {
        assessments
            .filter { $0.date >= startOfToday && $0.date < nextWeekBoundary }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var pendingGradesCount: Int {
        assessments.reduce(0) { partialResult, assessment in
            partialResult + max(assessment.results.count - assessment.results.filter(\.isResolved).count, 0)
        }
    }

    private var assignmentItems: [TodayAssignmentItem] {
        assignments
            .compactMap { assignment in
                let progress = assignment.progressSummary()
                let outstandingCount = progress.pendingCount + progress.missingCount

                guard outstandingCount > 0 else { return nil }
                guard assignment.dueDate < nextWeekBoundary else { return nil }

                return TodayAssignmentItem(
                    assignment: assignment,
                    pendingCount: progress.pendingCount,
                    missingCount: progress.missingCount,
                    className: assignment.unit?.subject?.schoolClass?.name ?? "",
                    unitName: assignment.unit?.name ?? "",
                    isOverdue: assignment.dueDate < startOfToday,
                    dueLabel: assignmentDueLabel(for: assignment.dueDate)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue && !rhs.isOverdue
                }
                if lhs.missingCount != rhs.missingCount {
                    return lhs.missingCount > rhs.missingCount
                }
                if lhs.assignment.dueDate != rhs.assignment.dueDate {
                    return lhs.assignment.dueDate < rhs.assignment.dueDate
                }
                return lhs.assignment.title.localizedCaseInsensitiveCompare(rhs.assignment.title) == .orderedAscending
            }
    }

    private var dueSoonAssignmentsCount: Int {
        assignmentItems.filter { !$0.isOverdue }.count
    }

    private var missingAssignmentsCount: Int {
        assignmentItems.reduce(0) { partialResult, item in
            partialResult + item.missingCount
        }
    }

    private var interventionItems: [TodayInterventionItem] {
        interventions
            .compactMap { intervention in
                guard intervention.status != .resolved else { return nil }
                guard let followUpDate = intervention.followUpDate else { return nil }
                guard followUpDate < nextWeekBoundary else { return nil }
                guard let student = intervention.student else { return nil }

                return TodayInterventionItem(
                    intervention: intervention,
                    student: student,
                    followUpDate: followUpDate,
                    className: student.schoolClass?.name ?? "",
                    isOverdue: followUpDate < startOfToday,
                    dueLabel: interventionFollowUpLabel(for: followUpDate)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue && !rhs.isOverdue
                }
                if lhs.followUpDate != rhs.followUpDate {
                    return lhs.followUpDate < rhs.followUpDate
                }
                if lhs.intervention.status != rhs.intervention.status {
                    return lhs.intervention.status == .open
                }
                return lhs.student.name.localizedCaseInsensitiveCompare(rhs.student.name) == .orderedAscending
            }
    }

    private var followUpsCount: Int {
        interventionItems.count
    }

    private var overdueFollowUpsCount: Int {
        interventionItems.filter { $0.isOverdue }.count
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
        .onAppear {
            syncAssignmentEntries()
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

            statCard(
                title: "Attendance".localized,
                value: "\(classesNeedingAttendance.count)",
                subtitle: "classes pending".localized,
                icon: "checklist",
                color: classesNeedingAttendance.isEmpty ? .green : .orange
            )

            statCard(
                title: "Backlog".localized,
                value: "\(pendingGradesCount)",
                subtitle: "grades pending".localized,
                icon: "tray.full.fill",
                color: pendingGradesCount > 0 ? .orange : .green
            )

            statCard(
                title: "Assessments".localized,
                value: "\(upcomingAssessments.count)",
                subtitle: "next 7 days".localized,
                icon: "doc.text.fill",
                color: upcomingAssessments.isEmpty ? .secondary : .blue
            )

            statCard(
                title: "Homework".localized,
                value: "\(dueSoonAssignmentsCount)",
                subtitle: "due this week".localized,
                icon: "list.clipboard.fill",
                color: dueSoonAssignmentsCount > 0 ? .teal : .secondary
            )

            statCard(
                title: "Missing Work".localized,
                value: "\(missingAssignmentsCount)",
                subtitle: "overdue submissions".localized,
                icon: "exclamationmark.bubble.fill",
                color: missingAssignmentsCount > 0 ? .red : .green
            )

            statCard(
                title: "Follow Ups".localized,
                value: "\(followUpsCount)",
                subtitle: "next 7 days".localized,
                icon: "cross.case.fill",
                color: followUpsCount > 0 ? .indigo : .secondary
            )

            statCard(
                title: "Overdue Plans".localized,
                value: "\(overdueFollowUpsCount)",
                subtitle: "need follow-up".localized,
                icon: "exclamationmark.circle.fill",
                color: overdueFollowUpsCount > 0 ? .red : .green
            )
        }
    }

    private var focusActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Focus Actions".localized)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(focusActions) { item in
                    focusActionCard(item: item)
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
                    ForEach(scheduleItems.prefix(4)) { item in
                        scheduleRow(item: item)
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
                            .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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

    private func combinedDate(for date: Date, time: Date?) -> Date {
        guard let time else { return date }
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private func formattedTimeRange(
        date: Date,
        startTime: Date?,
        endTime: Date?,
        isAllDay: Bool,
        fallback: String = "Any time".localized
    ) -> String {
        if isAllDay {
            return "All day".localized
        }
        if let startTime, let endTime {
            let start = combinedDate(for: date, time: startTime)
            let end = combinedDate(for: date, time: endTime)
            return "\(start.appTimeString(systemStyle: .short)) - \(end.appTimeString(systemStyle: .short))"
        }
        if let startTime {
            return combinedDate(for: date, time: startTime).appTimeString(systemStyle: .short)
        }
        return fallback
    }

    private func contextLine(className: String?, secondary: String?) -> String {
        [className, cleanedSnippet(secondary)]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    private func cleanedSnippet(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= 48 {
            return trimmed
        }
        return String(trimmed.prefix(45)) + "..."
    }

    private func contextualDetail(primary: String?, secondary: String?) -> String? {
        [cleanedSnippet(primary), cleanedSnippet(secondary)]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    private func firstNonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func assignmentDueLabel(for dueDate: Date) -> String {
        if dueDate < startOfToday {
            return "Overdue".localized
        }
        if calendar.isDate(dueDate, inSameDayAs: startOfToday) {
            return "Due Today".localized
        }
        if calendar.isDate(dueDate, inSameDayAs: startOfTomorrow) {
            return "Due Tomorrow".localized
        }
        return "Due Soon".localized
    }

    private func interventionFollowUpLabel(for followUpDate: Date) -> String {
        if followUpDate < startOfToday {
            return "Overdue".localized
        }
        if calendar.isDate(followUpDate, inSameDayAs: startOfToday) {
            return "Today".localized
        }
        if calendar.isDate(followUpDate, inSameDayAs: startOfTomorrow) {
            return "Tomorrow".localized
        }
        return "This Week".localized
    }

    private func syncAssignmentEntries() {
        for assignment in assignments {
            guard let classStudents = assignment.unit?.subject?.schoolClass?.students else { continue }
            assignment.ensureEntries(for: classStudents, context: context)
        }
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
