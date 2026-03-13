import SwiftUI
import SwiftData

struct AssignmentDetailView: View {
    @Bindable var assignment: Assignment
    let showsDismissButton: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var selectedFilter: AssignmentEntryFilter = .all
    @State private var reviewRefreshRevision = 0

    init(assignment: Assignment, showsDismissButton: Bool = false) {
        self.assignment = assignment
        self.showsDismissButton = showsDismissButton
    }

    enum AssignmentEntryFilter: String, CaseIterable, Identifiable {
        case all
        case pending
        case missing
        case completed
        case excused

        var id: String { rawValue }
    }

    private var sortedEntries: [StudentAssignment] {
        assignment.entries.sorted {
            let lhsOrder = $0.student?.sortOrder ?? 0
            let rhsOrder = $1.student?.sortOrder ?? 0
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return ($0.student?.name ?? "").localizedCaseInsensitiveCompare($1.student?.name ?? "") == .orderedAscending
        }
    }

    private var progress: AssignmentProgressSummary {
        assignment.progressSummary()
    }

    private var filteredEntries: [StudentAssignment] {
        sortedEntries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .pending:
                return entry.trackingState(relativeTo: assignment.dueDate) == .pending
            case .missing:
                return entry.trackingState(relativeTo: assignment.dueDate) == .missing
            case .completed:
                let state = entry.trackingState(relativeTo: assignment.dueDate)
                return state == .completedOnTime || state == .completedLate
            case .excused:
                return entry.trackingState(relativeTo: assignment.dueDate) == .excused
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                summaryCard
                filtersCard
                entriesSection
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(assignment.title)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let classStudents = assignment.unit?.subject?.schoolClass?.students {
                assignment.ensureEntries(for: classStudents, context: context)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .attentionAssignmentReviewStateChanged)) { _ in
            reviewRefreshRevision += 1
        }
        .macNavigationDepth()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(assignment.title)
                        .font(.title3.weight(.semibold))

                    Text(contextLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(String(format: "Due %@".localized, assignment.dueDate.appDateString(systemStyle: .medium)))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Button("Mark Pending Complete".localized) {
                        markPendingEntriesCompleted()
                    }
                    .font(.caption.weight(.semibold))

                    Button(isReminderReviewedToday ? "Clear Reminder Review".localized : "Mark Reminder Reviewed".localized) {
                        toggleReminderReview()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundColor(isReminderReviewedToday ? .secondary : .indigo)
                }
            }

            Label(
                isReminderReviewedToday ? "Reminder reviewed for today".localized : "Reminder still active today".localized,
                systemImage: isReminderReviewedToday ? "bell.badge.slash.fill" : "bell.badge.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundColor(isReminderReviewedToday ? .indigo : .orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((isReminderReviewedToday ? Color.indigo : Color.orange).opacity(0.12))
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                summaryStat(title: "Completed".localized, value: "\(progress.completedCount)", color: .green)
                summaryStat(title: "Late".localized, value: "\(progress.lateCount)", color: .yellow)
                summaryStat(title: "Missing".localized, value: "\(progress.missingCount)", color: .red)
                summaryStat(title: "Pending".localized, value: "\(progress.pendingCount)", color: .orange)
                summaryStat(title: "Excused".localized, value: "\(progress.excusedCount)", color: .teal)
            }

            if !assignment.details.isEmpty {
                Text(assignment.details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AssignmentEntryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filterTitle(filter))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.orange : Color.gray.opacity(0.14))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Students".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(filteredEntries.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if filteredEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No students match the current filter.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.orange.opacity(0.08),
                    tint: .orange
                )
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredEntries, id: \.persistentModelID) { entry in
                        entryRow(entry)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func summaryStat(title: String, value: String, color: Color) -> some View {
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

    private func entryRow(_ entry: StudentAssignment) -> some View {
        let trackingState = entry.trackingState(relativeTo: assignment.dueDate)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.student?.name ?? "Unknown".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Label(trackingState.title, systemImage: trackingState.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(trackingState.color.opacity(0.12))
                        )
                        .foregroundColor(trackingState.color)

                    if let submittedAt = entry.submittedAt {
                        Text(submittedAt.appDateString(systemStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Menu {
                Button("Mark Completed".localized) {
                    entry.markCompleted()
                }

                Button("Mark Pending".localized) {
                    entry.markPending()
                }

                Button("Excuse".localized) {
                    entry.markExcused()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
        .appCardStyle(
            cornerRadius: 12,
            borderColor: trackingState.color.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 4,
            shadowY: 2,
            tint: trackingState.color
        )
    }

    private var contextLine: String {
        [
            assignment.unit?.subject?.schoolClass?.name,
            assignment.unit?.subject?.name,
            assignment.unit?.name,
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " • ")
    }

    private var isReminderReviewedToday: Bool {
        _ = reviewRefreshRevision
        return AttentionAssignmentReviewStore.isReviewedToday(assignmentID: assignment.id)
    }

    private func markPendingEntriesCompleted() {
        for entry in assignment.entries where entry.status == .pending {
            entry.markCompleted()
        }
    }

    private func toggleReminderReview() {
        if isReminderReviewedToday {
            AttentionAssignmentReviewStore.clearReviewedToday(assignmentID: assignment.id)
        } else {
            AttentionAssignmentReviewStore.markReviewedToday(assignmentID: assignment.id)
        }
    }

    private func filterTitle(_ filter: AssignmentEntryFilter) -> String {
        switch filter {
        case .all:
            return "All".localized
        case .pending:
            return "Pending".localized
        case .missing:
            return "Missing".localized
        case .completed:
            return "Completed".localized
        case .excused:
            return "Excused".localized
        }
    }
}
