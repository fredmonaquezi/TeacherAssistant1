import SwiftUI
import SwiftUI
import SwiftData

struct StudentUnitEvaluationView: View {
    
    @Environment(\.modelContext) private var context
    
    let student: Student
    @Bindable var unit: Unit
    
    @State private var selectedResult: StudentResult?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - Header
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(student.name)
                        .font(.largeTitle)
                        .bold()
                    
                    Text(String(format: "Unit: %@".localized, unit.name))
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // MARK: - Rubric
                
                VStack(spacing: 16) {
                    ForEach(unit.assessments, id: \.id) { assessment in
                        rubricRow(for: assessment)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Evaluation".localized)
        .sheet(
            isPresented: Binding(
                get: { selectedResult != nil },
                set: { if !$0 { selectedResult = nil } }
            )
        ) {
            if let result = selectedResult {
                ScorePickerSheet(studentResult: result)
            }
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    func rubricRow(for assessment: Assessment) -> some View {
        
        let result = findResult(assessment: assessment)
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text(assessment.title)
                .font(.title3)
                .bold()
            
            HStack(alignment: .top, spacing: 16) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Level (1–5)".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        let finalResult = result ?? createResult(assessment: assessment)
                        selectedResult = finalResult
                    } label: {
                        HStack {
                            if let result, result.score > 0 {
                                Text("\(Int(result.score))")
                                    .font(.title)
                                    .bold()
                                
                                Text("– \(labelForScore(Int(result.score)))")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not evaluated".localized)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: 280)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Evidence & Notes".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: Binding(
                        get: { result?.notes ?? "" },
                        set: { newValue in
                            let finalResult = result ?? createResult(assessment: assessment)
                            finalResult.notes = newValue
                        }
                    ))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Helpers
    
    func findResult(assessment: Assessment) -> StudentResult? {
        assessment.results.first { $0.student?.id == student.id }
    }
    
    func createResult(assessment: Assessment) -> StudentResult {
        let newResult = StudentResult(student: student, score: 0, notes: "")
        newResult.assessment = assessment
        context.insert(newResult)
        return newResult
    }
    
    func labelForScore(_ value: Int) -> String {
        switch value {
        case 1: return "Needs significant support".localized
        case 2: return "Beginning".localized
        case 3: return "Developing".localized
        case 4: return "Proficient".localized
        case 5: return "Mastering".localized
        default: return ""
        }
    }
}
