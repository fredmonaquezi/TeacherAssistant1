import SwiftUI
import SwiftData

struct ClassAssignmentsView: View {
    @Bindable var schoolClass: SchoolClass
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var selectedFilter: AssignmentBoardFilter = .all
    @State private var selectedUnitID: UUID?
    @State private var searchText = ""
    @State private var showingAddAssignment = false
    @State private var reviewRefreshRevision = 0

    enum AssignmentBoardFilter: String, CaseIterable, Identifiable {
        case all
        case dueSoon
        case missing
        case completed

        var id: String { rawValue }
    }

    private let calendar = Calendar.current

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var nextWeekBoundary: Date {
        calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
    }

    private var units: [Unit] {
        schoolClass.subjects
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { subject in
                subject.units.sorted { $0.sortOrder < $1.sortOrder }
            }
    }

    private var assignments: [Assignment] {
        units
            .flatMap { $0.assignments }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var filteredAssignments: [Assignment] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return assignments.filter { assignment in
            if let selectedUnitID, assignment.unit?.id != selectedUnitID {
                return false
            }

            let progress = assignment.progressSummary()
            switch selectedFilter {
            case .all:
                break
            case .dueSoon:
                guard assignment.dueDate >= startOfToday && assignment.dueDate < nextWeekBoundary else { return false }
            case .missing:
                guard progress.missingCount > 0 else { return false }
            case .completed:
                guard progress.pendingCount == 0 && progress.missingCount == 0 else { return false }
            }

            guard !trimmedSearch.isEmpty else { return true }
            let haystacks = [
                assignment.title,
                assignment.details,
                assignment.unit?.name ?? "",
                assignment.unit?.subject?.name ?? "",
            ]
            return haystacks.contains { $0.localizedCaseInsensitiveContains(trimmedSearch) }
        }
    }

    private var overview: ClassAssignmentOverview {
        let summaries = assignments.map { $0.progressSummary() }
        return ClassAssignmentOverview(
            assignmentCount: assignments.count,
            dueTodayCount: assignments.filter { calendar.isDate($0.dueDate, inSameDayAs: Date()) }.count,
            outstandingCount: summaries.reduce(0) { $0 + $1.pendingCount + $1.missingCount },
            missingCount: summaries.reduce(0) { $0 + $1.missingCount },
            completedCount: summaries.reduce(0) { $0 + $1.completedCount + $1.lateCount },
            reviewedReminderCount: assignments.filter { isReminderReviewedToday(for: $0) }.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                heroCard
                filtersCard
                assignmentsSection
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Assignments".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAssignment = true
                } label: {
                    Label("Add Assignment".localized, systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddAssignment) {
            AddAssignmentSheet(schoolClass: schoolClass, presetUnit: nil)
        }
        .onAppear {
            syncAssignmentEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .attentionAssignmentReviewStateChanged)) { _ in
            reviewRefreshRevision += 1
        }
        .macNavigationDepth()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assignments".localized)
                        .font(.title3.weight(.semibold))
                    Text("Track homework, due dates, and student completion across the whole class.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Add Assignment".localized) {
                    showingAddAssignment = true
                }
                .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                overviewStat(title: "Assignments".localized, value: "\(overview.assignmentCount)", color: .blue)
                overviewStat(title: "Due Today".localized, value: "\(overview.dueTodayCount)", color: .teal)
                overviewStat(title: "Outstanding".localized, value: "\(overview.outstandingCount)", color: overview.outstandingCount > 0 ? .orange : .green)
                overviewStat(title: "Missing".localized, value: "\(overview.missingCount)", color: overview.missingCount > 0 ? .red : .green)
                overviewStat(title: "Reviewed Today".localized, value: "\(overview.reviewedReminderCount)", color: overview.reviewedReminderCount > 0 ? .indigo : .secondary)
                overviewStat(title: "Completed".localized, value: "\(overview.completedCount)", color: .green)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.orange.opacity(0.12),
            tint: .orange
        )
        .padding(.horizontal)
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(title: "All Units".localized, selected: selectedUnitID == nil) {
                        selectedUnitID = nil
                    }

                    ForEach(units, id: \.id) { unit in
                        filterChip(title: unit.name, selected: selectedUnitID == unit.id) {
                            selectedUnitID = unit.id
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AssignmentBoardFilter.allCases) { filter in
                        filterChip(title: filterTitle(filter), selected: selectedFilter == filter) {
                            selectedFilter = filter
                        }
                    }
                }
            }

            TextField("Search assignments".localized, text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.1),
            tint: .orange
        )
        .padding(.horizontal)
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Assignments".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(filteredAssignments.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if filteredAssignments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("No assignments found".localized)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.secondary)
                    Text("Add an assignment or adjust the current filters.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.orange.opacity(0.08),
                    tint: .orange
                )
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAssignments, id: \.persistentModelID) { assignment in
                        assignmentRow(assignment)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func overviewStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: color.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 4,
            shadowY: 2,
            tint: color
        )
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        let progress = assignment.progressSummary()
        let isReviewedToday = isReminderReviewedToday(for: assignment)

        return HStack(alignment: .top, spacing: 12) {
            NavigationLink {
                AssignmentDetailView(assignment: assignment)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(assignment.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(contextLine(for: assignment))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Text(assignment.dueDate.appDateString)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        if isReviewedToday {
                            progressPill(icon: "bell.badge.slash.fill", title: "reviewed today".localized, color: .indigo)
                        }
                        progressPill(icon: "clock", title: "\(progress.pendingCount) " + "pending".localized, color: .orange)
                        if progress.missingCount > 0 {
                            progressPill(icon: "xmark.circle.fill", title: "\(progress.missingCount) " + "missing".localized, color: .red)
                        }
                        if progress.lateCount > 0 {
                            progressPill(icon: "exclamationmark.circle.fill", title: "\(progress.lateCount) " + "late".localized, color: .yellow)
                        }
                        progressPill(icon: "checkmark.circle.fill", title: "\(progress.completedCount + progress.lateCount) " + "done".localized, color: .green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button(isReviewedToday ? "Clear Reminder Review".localized : "Mark Reminder Reviewed".localized) {
                    toggleReminderReview(for: assignment)
                }

                if progress.pendingCount > 0 {
                    Button("Mark Pending Complete".localized) {
                        markPendingEntriesCompleted(for: assignment)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: rowTint(for: progress).opacity(0.12),
            tint: rowTint(for: progress)
        )
    }

    private func progressPill(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.orange : Color.gray.opacity(0.14))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func rowTint(for progress: AssignmentProgressSummary) -> Color {
        if progress.missingCount > 0 {
            return .red
        }
        if progress.pendingCount > 0 {
            return .orange
        }
        return .green
    }

    private func contextLine(for assignment: Assignment) -> String {
        [assignment.unit?.subject?.name, assignment.unit?.name]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    private func filterTitle(_ filter: AssignmentBoardFilter) -> String {
        switch filter {
        case .all:
            return "All".localized
        case .dueSoon:
            return "Due Soon".localized
        case .missing:
            return "Missing".localized
        case .completed:
            return "Completed".localized
        }
    }

    private func syncAssignmentEntries() {
        for assignment in assignments {
            assignment.ensureEntries(for: schoolClass.students, context: context)
        }
    }

    private func isReminderReviewedToday(for assignment: Assignment) -> Bool {
        _ = reviewRefreshRevision
        return AttentionAssignmentReviewStore.isReviewedToday(assignmentID: assignment.id)
    }

    private func toggleReminderReview(for assignment: Assignment) {
        if isReminderReviewedToday(for: assignment) {
            AttentionAssignmentReviewStore.clearReviewedToday(assignmentID: assignment.id)
        } else {
            AttentionAssignmentReviewStore.markReviewedToday(assignmentID: assignment.id)
        }
    }

    private func markPendingEntriesCompleted(for assignment: Assignment) {
        for entry in assignment.entries where entry.status == .pending {
            entry.markCompleted()
        }
    }
}

private struct ClassAssignmentOverview {
    let assignmentCount: Int
    let dueTodayCount: Int
    let outstandingCount: Int
    let missingCount: Int
    let completedCount: Int
    let reviewedReminderCount: Int
}
