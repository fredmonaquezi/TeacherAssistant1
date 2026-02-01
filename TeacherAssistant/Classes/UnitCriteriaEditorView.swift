import SwiftUI
import SwiftData

struct UnitCriteriaEditorView: View {
    
    @Bindable var unit: Unit
    
    @State private var showingAddAlert = false
    @State private var newCriterionName = ""
    
    var body: some View {
        List {
            if unit.assessments.isEmpty {
                Text("No criteria yet.".localized)
                    .foregroundColor(.secondary)
            } else {
                ForEach($unit.assessments) { $assessment in
                    HStack {
                        TextField(
                            "Criterion name",
                            text: $assessment.title
                        )
                    }
                }
                .onDelete(perform: deleteCriteria)
            }
            
            Button {
                newCriterionName = ""
                showingAddAlert = true
            } label: {
                Label("Add Criterion".localized, systemImage: "plus")
            }
        }
        .navigationTitle("Edit Criteria")
        .alert("New Criterion".localized, isPresented: $showingAddAlert) {
            TextField("Name", text: $newCriterionName)
            
            Button("Cancel".localized, role: .cancel) {}
            
            Button("Add".localized) {
                addCriterion()
            }
        } message: {
            Text("Enter the name of the new criterion.".localized)
        }
    }
    
    // MARK: - Actions
    
    func addCriterion() {
        let name = newCriterionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let newAssessment = Assessment(title: name)
        newAssessment.unit = unit
        
        // Put at the end
        newAssessment.sortOrder = unit.assessments.count
        
        unit.assessments.append(newAssessment)
    }
    
    func deleteCriteria(at offsets: IndexSet) {
        unit.assessments.remove(atOffsets: offsets)
    }
}
