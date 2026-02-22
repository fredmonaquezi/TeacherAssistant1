import SwiftUI
import SwiftData

struct UnitDetailView: View {
    @Bindable var unit: Unit
    
    @Query private var allSubjectsInDB: [Subject]

    
    // MARK: - Copy Flow State
    
    enum CopyStep: Identifiable {
        case chooseSubject
        case chooseUnit
        case confirm
        
        var id: Int {
            switch self {
            case .chooseSubject: return 1
            case .chooseUnit: return 2
            case .confirm: return 3
            }
        }
    }
    
    @State private var copyStep: CopyStep? = nil
    @State private var selectedSubject: Subject?
    @State private var selectedSourceUnit: Unit?
    
    // MARK: - Delete confirmation state
    
    @State private var assessmentToDelete: Assessment?
    @State private var showingDeleteAssessmentAlert = false
    
    // Add assessment dialog
    @State private var showingAddAssessmentDialog = false
    @State private var newAssessmentName = ""
    @State private var newAssessmentMaxScore = "10"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Statistics Card
                statisticsCard
                
                // MARK: - Quick Actions
                quickActionsSection
                
                // MARK: - Assessments Section
                assessmentsSection
                
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle(unit.name)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Unit name".localized, text: $unit.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    #if os(macOS)
                    .textFieldStyle(.plain)
                    #endif
            }
        }
        #endif
        .alert("Delete Assessment?".localized, isPresented: $showingDeleteAssessmentAlert) {
            Button("Cancel".localized, role: .cancel) {
                assessmentToDelete = nil
            }
            
            Button("Delete".localized, role: .destructive) {
                if let assessmentToDelete {
                    if let index = unit.assessments.firstIndex(where: { $0.id == assessmentToDelete.id }) {
                        unit.assessments.remove(at: index)
                    }
                }
                assessmentToDelete = nil
            }
        } message: {
            if let assessmentToDelete {
                Text("Are you sure you want to delete \"\(assessmentToDelete.title)\"?".localized)
            }
        }
        .sheet(isPresented: $showingAddAssessmentDialog) {
            AddAssessmentDialog(
                assessmentName: $newAssessmentName,
                maxScoreText: $newAssessmentMaxScore,
                onAdd: {
                    addAssessment()
                }
            )
        }
        .sheet(item: $copyStep) { step in
            CopyCriteriaSheet(
                step: step,
                unit: unit,
                selectedSubject: $selectedSubject,
                selectedSourceUnit: $selectedSourceUnit,
                copyStep: $copyStep
            )
            .frame(width: 500, height: 500)
        }
        .macNavigationDepth()
    }
    
    // MARK: - Statistics Card
    
    var statisticsCard: some View {
        HStack(spacing: 16) {
            statBox(
                title: "Unit Average".localized,
                value: String(format: "%.1f%%", unitAveragePercent),
                icon: "chart.bar.fill",
                color: AssessmentPercentMetrics.color(for: unitAveragePercent)
            )
            
            statBox(
                title: "Assessments".localized,
                value: "\(unit.assessments.count)",
                icon: "doc.text.fill",
                color: .blue
            )
            
            statBox(
                title: "Total Grades".localized,
                value: "\(totalGrades)",
                icon: "checkmark.circle.fill",
                color: .purple
            )
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
    
    // MARK: - Quick Actions
    
    var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Open Gradebook Button
                NavigationLink {
                    UnitGradebookView(unit: unit)
                } label: {
                    actionCard(
                        icon: "tablecells",
                        title: "Gradebook".localized,
                        subtitle: "View all grades".localized,
                        color: .green
                    )
                }
                .buttonStyle(.plain)
                
                // View PDFs Button
                NavigationLink {
                    UnitPDFsView(unit: unit)
                } label: {
                    actionCard(
                        icon: "doc.text.fill",
                        title: "View PDFs".localized,
                        subtitle: "Linked materials".localized,
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Copy Criteria Button (full width)
            Button {
                copyStep = .chooseSubject
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy Criteria".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Import assessments from another unit".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    func actionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Assessments Section
    
    var assessmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assessments".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if unit.assessments.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16)
                ], spacing: 16) {
                    ForEach(unit.assessments.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { assessment in
                        NavigationLink {
                            AssessmentDetailView(assessment: assessment)
                        } label: {
                            AssessmentCardView(assessment: assessment, onDelete: {
                                assessmentToDelete = assessment
                                showingDeleteAssessmentAlert = true
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // Add Assessment Button
            Button {
                showingAddAssessmentDialog = true
            } label: {
                Label("Add Assessment".localized, systemImage: "plus.circle.fill")
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
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No assessments yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create your first assessment or copy criteria from another unit".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Actions
    
    func addAssessment() {
        let parsedMaxScore = parsedMaxScore(from: newAssessmentMaxScore)
        let newAssessment = Assessment(title: newAssessmentName, maxScore: parsedMaxScore)
        newAssessment.unit = unit
        newAssessment.sortOrder = unit.assessments.count
        unit.assessments.append(newAssessment)
        ensureResultsExist(for: newAssessment)
        
        // Reset the text field for next time
        newAssessmentName = ""
        newAssessmentMaxScore = "10"
    }
    
    func copyCriteria(from sourceUnit: Unit) {
        let existingCount = unit.assessments.count
        let sourceSorted = sourceUnit.assessments.sorted { $0.sortOrder < $1.sortOrder }
        
        for (index, old) in sourceSorted.enumerated() {
            let newAssessment = Assessment(title: old.title, maxScore: old.safeMaxScore)
            newAssessment.unit = unit
            newAssessment.sortOrder = existingCount + index
            unit.assessments.append(newAssessment)
            ensureResultsExist(for: newAssessment)
        }
    }
    
    func resetCopyFlow() {
        copyStep = nil
        selectedSubject = nil
        selectedSourceUnit = nil
    }
    
    // MARK: - Helpers
    
    var unitAveragePercent: Double {
        let allResults = unit.assessments.flatMap { $0.results }
        return allResults.averagePercent
    }
    
    var totalGrades: Int {
        unit.assessments.flatMap { $0.results }.filter { $0.score > 0 }.count
    }

    func parsedMaxScore(from text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else {
            return Assessment.defaultMaxScore
        }
        return Swift.min(Swift.max(value, 1), 1000)
    }

    func ensureResultsExist(for assessment: Assessment) {
        let students = studentsInCurrentClass()
        guard !students.isEmpty else { return }

        let existingStudentIDs = Set(assessment.results.compactMap { $0.student?.id })
        for student in students where !existingStudentIDs.contains(student.id) {
            assessment.results.append(StudentResult(student: student, assessment: assessment))
        }
    }
    
    func subjectsInCurrentClass() -> [Subject] {
        if let schoolClass = unit.subject?.schoolClass {
            return schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
        }
        return []
    }

    func studentsInCurrentClass() -> [Student] {
        unit.subject?.schoolClass?.students.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
}
// MARK: - Add Assessment Dialog

struct AddAssessmentDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var assessmentName: String
    @Binding var maxScoreText: String
    let onAdd: () -> Void

    var isMaxScoreValid: Bool {
        let cleaned = maxScoreText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return false }
        return value >= 1 && value <= 1000
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("Add New Assessment".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Give your assessment a name".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assessment Name".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("e.g., Quiz 1, Chapter Test, Midterm Exam".localized, text: $assessmentName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Maximum Score".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    #if os(iOS)
                    TextField("e.g., 10".localized, text: $maxScoreText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(isMaxScoreValid ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(10)
                    #else
                    TextField("e.g., 10".localized, text: $maxScoreText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(isMaxScoreValid ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(10)
                    #endif

                    if !isMaxScoreValid {
                        Text("Enter a value between 1 and 1000".localized)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                if !assessmentName.isEmpty {
                    VStack(spacing: 8) {
                        Text("Preview".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assessmentName)
                                    .font(.headline)
                                Text(String(format: "Max: %@".localized, maxScoreText))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("New Assessment".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        assessmentName = ""
                        maxScoreText = "10"
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add".localized) {
                        onAdd()
                        dismiss()
                    }
                    .disabled(assessmentName.isEmpty || !isMaxScoreValid)
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
