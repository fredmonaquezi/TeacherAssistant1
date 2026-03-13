import SwiftUI
import SwiftData

struct StudentInterventionsSheet: View {
    @Bindable var student: Student

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showingEditor = false
    @State private var editingIntervention: Intervention?
    @State private var interventionToDelete: Intervention?
    @State private var showingDeleteAlert = false

    private var orderedInterventions: [Intervention] {
        student.interventions.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status != .resolved && rhs.status == .resolved
            }
            if lhs.followUpDate != rhs.followUpDate {
                return (lhs.followUpDate ?? .distantFuture) < (rhs.followUpDate ?? .distantFuture)
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var activeInterventions: [Intervention] {
        orderedInterventions.filter { $0.status != .resolved }
    }

    private var resolvedInterventions: [Intervention] {
        orderedInterventions.filter { $0.status == .resolved }
    }

    private var overdueFollowUpsCount: Int {
        activeInterventions.filter(\.needsFollowUp).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection
                    activeSection

                    if !resolvedInterventions.isEmpty {
                        resolvedSection
                    }
                }
                .padding()
            }
            .navigationTitle("Interventions".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingIntervention = nil
                        showingEditor = true
                    } label: {
                        Label("Add".localized, systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                InterventionEditorSheet(
                    student: student,
                    intervention: editingIntervention
                )
            }
            .alert("Delete Intervention?".localized, isPresented: $showingDeleteAlert) {
                Button("Cancel".localized, role: .cancel) {
                    interventionToDelete = nil
                }
                Button("Delete".localized, role: .destructive) {
                    guard let interventionToDelete else { return }
                    Task {
                        await PersistenceWriteCoordinator.shared.perform(
                            context: context,
                            reason: "Delete intervention"
                        ) {
                            context.delete(interventionToDelete)
                        }
                    }
                    self.interventionToDelete = nil
                }
            } message: {
                Text("This support record will be removed permanently.".localized)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(student.name)
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                summaryCard(
                    title: "Active".localized,
                    value: "\(activeInterventions.count)",
                    color: .orange
                )
                summaryCard(
                    title: "Follow-Up Due".localized,
                    value: "\(overdueFollowUpsCount)",
                    color: overdueFollowUpsCount > 0 ? .red : .green
                )
                summaryCard(
                    title: "Resolved".localized,
                    value: "\(resolvedInterventions.count)",
                    color: .green
                )
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.orange.opacity(0.12),
            tint: .orange
        )
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Support".localized)
                .font(AppTypography.cardTitle)

            if activeInterventions.isEmpty {
                emptyState("No active interventions yet.".localized)
            } else {
                VStack(spacing: 10) {
                    ForEach(activeInterventions, id: \.id) { intervention in
                        interventionRow(intervention)
                    }
                }
            }
        }
    }

    private var resolvedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolved".localized)
                .font(AppTypography.cardTitle)

            VStack(spacing: 10) {
                ForEach(resolvedInterventions, id: \.id) { intervention in
                    interventionRow(intervention)
                }
            }
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
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
            tint: color
        )
    }

    private func interventionRow(_ intervention: Intervention) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(intervention.title)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 6) {
                        pill(intervention.category.title, color: categoryColor(intervention.category))
                        pill(intervention.status.title, color: statusColor(intervention.status))
                        if intervention.needsFollowUp {
                            pill("Follow-Up Due".localized, color: .red)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button("Edit".localized) {
                        editingIntervention = intervention
                        showingEditor = true
                    }

                    if intervention.status != .resolved {
                        Button("Mark Resolved".localized) {
                            intervention.status = .resolved
                            intervention.updatedAt = Date()
                        }
                    }

                    Button("Delete".localized, role: .destructive) {
                        interventionToDelete = intervention
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            if let followUpDate = intervention.followUpDate {
                Text(
                    String(
                        format: "%@ %@".localized,
                        "Follow-Up".localized,
                        followUpDate.appDateString(systemStyle: .medium)
                    )
                )
                .font(.caption)
                .foregroundColor(intervention.needsFollowUp ? .red : .secondary)
            }

            if !intervention.notes.isEmpty {
                Text(intervention.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: statusColor(intervention.status).opacity(0.12),
            tint: statusColor(intervention.status)
        )
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .appCardStyle(
                cornerRadius: 14,
                borderColor: Color.gray.opacity(0.08),
                tint: .gray
            )
    }

    private func categoryColor(_ category: InterventionCategory) -> Color {
        switch category {
        case .academics:
            return .blue
        case .attendance:
            return .green
        case .homework:
            return .orange
        case .behavior:
            return .pink
        case .wellbeing:
            return .teal
        case .other:
            return .gray
        }
    }

    private func statusColor(_ status: InterventionStatus) -> Color {
        switch status {
        case .open:
            return .orange
        case .inProgress:
            return .blue
        case .resolved:
            return .green
        }
    }
}

private struct InterventionEditorSheet: View {
    @Bindable var student: Student
    let intervention: Intervention?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var notes = ""
    @State private var category: InterventionCategory = .academics
    @State private var status: InterventionStatus = .open
    @State private var hasFollowUpDate = false
    @State private var followUpDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Support Plan".localized) {
                    TextField("Title".localized, text: $title)

                    Picker("Category".localized, selection: $category) {
                        ForEach(InterventionCategory.allCases, id: \.rawValue) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    Picker("Status".localized, selection: $status) {
                        ForEach(InterventionStatus.allCases, id: \.rawValue) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section("Follow-Up".localized) {
                    Toggle("Set Follow-Up Date".localized, isOn: $hasFollowUpDate)
                    if hasFollowUpDate {
                        DatePicker("Date".localized, selection: $followUpDate, displayedComponents: .date)
                    }
                }

                Section("Notes".localized) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle(intervention == nil ? "New Intervention".localized : "Edit Intervention".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let intervention else { return }
                title = intervention.title
                notes = intervention.notes
                category = intervention.category
                status = intervention.status
                hasFollowUpDate = intervention.followUpDate != nil
                followUpDate = intervention.followUpDate ?? Date()
            }
        }
    }

    private func save() {
        let sanitizedTitle = SecurityHelpers.sanitizeName(title) ?? ""
        let sanitizedNotes = SecurityHelpers.sanitizeNotes(notes)
        let resolvedFollowUpDate = hasFollowUpDate ? Calendar.current.startOfDay(for: followUpDate) : nil

        guard !sanitizedTitle.isEmpty else { return }

        if let intervention {
            intervention.title = sanitizedTitle
            intervention.notes = sanitizedNotes
            intervention.category = category
            intervention.status = status
            intervention.followUpDate = resolvedFollowUpDate
            intervention.updatedAt = Date()
        } else {
            let newIntervention = Intervention(
                title: sanitizedTitle,
                notes: sanitizedNotes,
                category: category,
                status: status,
                followUpDate: resolvedFollowUpDate,
                student: student
            )
            student.interventions.append(newIntervention)
            context.insert(newIntervention)
        }

        dismiss()
    }
}
