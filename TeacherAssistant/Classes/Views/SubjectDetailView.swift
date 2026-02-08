import SwiftUI
import SwiftData

struct SubjectDetailView: View {
    @Bindable var subject: Subject
    @EnvironmentObject var languageManager: LanguageManager
    
    // ✅ Delete confirmation state for units
    @State private var unitToDelete: Unit?
    @State private var showingDeleteUnitAlert = false
    
    // Add unit dialog
    @State private var showingAddUnitDialog = false
    @State private var newUnitName = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Statistics Card
                statisticsCard
                
                // MARK: - Units Section
                unitsSection
                
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle(subject.name)
        .toolbar {
            // Center: editable subject name
            ToolbarItem(placement: .principal) {
                TextField(languageManager.localized("Subject name"), text: $subject.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    #if os(macOS)
                    .textFieldStyle(.plain)
                    #endif
            }
        }
        #endif
        .alert(languageManager.localized("Delete Unit?"), isPresented: $showingDeleteUnitAlert) {
            Button(languageManager.localized("Cancel"), role: .cancel) {
                unitToDelete = nil
            }
            
            Button(languageManager.localized("Delete"), role: .destructive) {
                if let unitToDelete {
                    if let index = subject.units.firstIndex(where: { $0.id == unitToDelete.id }) {
                        subject.units.remove(at: index)
                    }
                }
                unitToDelete = nil
            }
        } message: {
            if let unitToDelete {
                Text(String(format: languageManager.localized("Are you sure you want to delete \"%@\"? All assessments and grades inside this unit will be lost."), unitToDelete.name))
            }
        }
        .sheet(isPresented: $showingAddUnitDialog) {
            AddUnitDialog(unitName: $newUnitName, onAdd: {
                addUnit()
            })
            .environmentObject(languageManager)
        }
        .macNavigationDepth()
    }
    
    // MARK: - Statistics Card
    
    var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statBox(
                    title: languageManager.localized("Subject Average"),
                    value: String(format: "%.1f", subjectAverage),
                    icon: "chart.bar.fill",
                    color: averageColor(subjectAverage)
                )
                
                statBox(
                    title: languageManager.localized("Total Units"),
                    value: "\(subject.units.count)",
                    icon: "folder.fill",
                    color: .blue
                )
                
                statBox(
                    title: languageManager.localized("Total Assessments"),
                    value: "\(totalAssessments)",
                    icon: "list.bullet.clipboard",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
    
    func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
    
    // MARK: - Units Section
    
    var unitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(languageManager.localized("Units"))
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if subject.units.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
                ], spacing: 20) {
                    ForEach(subject.units.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { unit in
                        NavigationLink {
                            UnitDetailView(unit: unit)
                        } label: {
                            UnitCardView(unit: unit, onDelete: {
                                unitToDelete = unit
                                showingDeleteUnitAlert = true
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // Add Unit Button
            Button {
                showingAddUnitDialog = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text(languageManager.localized("Add Unit"))
                }
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(languageManager.localized("No units yet"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(languageManager.localized("Create your first unit to start adding assessments"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Actions
    
    func addUnit() {
        let newUnit = Unit(name: newUnitName)
        newUnit.subject = subject
        
        // ✅ Put at the end
        newUnit.sortOrder = subject.units.count
        
        subject.units.append(newUnit)
        
        // Reset the text field for next time
        newUnitName = ""
    }
    
    // MARK: - Stats
    
    var subjectAverage: Double {
        let allResults = subject.units
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { $0.assessments }
            .flatMap { $0.results }
        
        return allResults.averageScore
    }
    
    var totalAssessments: Int {
        subject.units.flatMap { $0.assessments }.count
    }
}
// MARK: - Add Unit Dialog

struct AddUnitDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var unitName: String
    let onAdd: () -> Void
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text(languageManager.localized("Add New Unit"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(languageManager.localized("Give your unit a name"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localized("Unit Name"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField(languageManager.localized("e.g., Chapter 1, Ancient Rome, Fractions"), text: $unitName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if !unitName.isEmpty {
                    VStack(spacing: 8) {
                        Text(languageManager.localized("Preview"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text(unitName)
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle(languageManager.localized("New Unit"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.localized("Cancel")) {
                        unitName = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Add")) {
                        onAdd()
                        dismiss()
                    }
                    .disabled(unitName.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
}
