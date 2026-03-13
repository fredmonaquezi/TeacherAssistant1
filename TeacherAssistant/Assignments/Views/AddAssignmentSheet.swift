import SwiftUI
import SwiftData

struct AddAssignmentSheet: View {
    let schoolClass: SchoolClass
    let presetUnit: Unit?
    var onCreated: ((Assignment) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var title = ""
    @State private var details = ""
    @State private var dueDate = Date()
    @State private var selectedUnitID: UUID?

    private var availableUnits: [Unit] {
        schoolClass.subjects
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { subject in
                subject.units.sorted { $0.sortOrder < $1.sortOrder }
            }
    }

    private var resolvedUnit: Unit? {
        if let presetUnit {
            return presetUnit
        }
        guard let selectedUnitID else { return nil }
        return availableUnits.first(where: { $0.id == selectedUnitID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment".localized) {
                    TextField("Title".localized, text: $title)
                    DatePicker("Due Date".localized, selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Unit".localized) {
                    if let presetUnit {
                        LabeledContent("Unit".localized, value: presetUnit.name)
                        if let subjectName = presetUnit.subject?.name {
                            LabeledContent("Subject".localized, value: subjectName)
                        }
                    } else {
                        Picker("Unit".localized, selection: $selectedUnitID) {
                            Text("Select Unit".localized).tag(Optional<UUID>.none)
                            ForEach(availableUnits, id: \.id) { unit in
                                Text(unitLabel(for: unit)).tag(Optional.some(unit.id))
                            }
                        }
                    }
                }

                Section("Details".localized) {
                    TextField("Assignment details".localized, text: $details, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("New Assignment".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create".localized) {
                        createAssignment()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || resolvedUnit == nil)
                }
            }
            .onAppear {
                if let presetUnit {
                    selectedUnitID = presetUnit.id
                }
            }
        }
    }

    private func createAssignment() {
        guard let unit = resolvedUnit else { return }

        let assignment = Assignment(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            createdAt: Date(),
            sortOrder: unit.assignments.count
        )
        assignment.unit = unit
        context.insert(assignment)
        unit.assignments.append(assignment)

        if let classStudents = unit.subject?.schoolClass?.students {
            assignment.ensureEntries(for: classStudents, context: context)
        }

        onCreated?(assignment)
        dismiss()
    }

    private func unitLabel(for unit: Unit) -> String {
        let subjectName = unit.subject?.name ?? ""
        return [subjectName, unit.name].filter { !$0.isEmpty }.joined(separator: " • ")
    }
}
