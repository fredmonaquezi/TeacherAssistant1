import SwiftUI
import SwiftData

struct UnitGradebookView: View {
    
    @Environment(\.modelContext) private var context
    
    @Bindable var unit: Unit
    
    @Query private var allResults: [StudentResult]
    
    @State private var selectedResult: StudentResult?
    
    // MARK: - Data
    
    var studentsInThisUnit: [Student] {
        unit.subject?.schoolClass?.students
            .sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
    
    var assessments: [Assessment] {
        unit.assessments.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Layout Constants
    
    let studentColumnWidth: CGFloat = 240
    let gradeColumnWidth: CGFloat = 140
    let cellHeight: CGFloat = 56
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics bar
            statisticsBar
            
            Divider()
            
            // Gradebook table
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Header row
                    HStack(spacing: 0) {
                        Text("Student".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(width: studentColumnWidth, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: cellHeight)
                        
                        ForEach(assessments, id: \.id) { assessment in
                            Text(assessment.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: gradeColumnWidth, alignment: .center)
                                .frame(height: cellHeight)
                        }
                        
                        // Average column
                        Text("Average".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(width: gradeColumnWidth, alignment: .center)
                            .frame(height: cellHeight)
                    }
                    .background(headerBackgroundColor)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Color.gray.opacity(0.3)),
                        alignment: .bottom
                    )
                    
                    Divider()
                    
                    // Student rows
                    ForEach(studentsInThisUnit, id: \.id) { student in
                        HStack(spacing: 0) {
                            // Student name cell
                            Text(student.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .frame(width: studentColumnWidth, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(height: cellHeight)
                                .background(rowBackgroundColor.opacity(0.5))
                            
                            // Grade cells
                            ForEach(assessments, id: \.id) { assessment in
                                gradeCell(student: student, assessment: assessment)
                            }
                            
                            // Average cell
                            studentAverageCell(student: student)
                        }
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.gray.opacity(0.1)),
                            alignment: .bottom
                        )
                    }
                }
                .background(tableBackground)
            }
        }
        #if !os(macOS)
        .navigationTitle("Gradebook".localized + ": \(unit.name)")
        #endif
        .sheet(
            isPresented: Binding(
                get: { selectedResult != nil },
                set: { if !$0 { selectedResult = nil } }
            )
        ) {
            if let result = selectedResult {
                ScoreEntrySheet(
                    studentResult: result,
                    maxScore: result.assessment?.safeMaxScore ?? Assessment.defaultMaxScore
                )
            }
        }
        .onAppear {
            ensureResultsExist()
        }
        .macNavigationDepth()
    }
    
    // MARK: - Statistics Bar
    
    var statisticsBar: some View {
        HStack(spacing: 24) {
            statItem(
                icon: "person.3.fill",
                label: "Students".localized,
                value: "\(studentsInThisUnit.count)",
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                icon: "doc.text.fill",
                label: "Assessments".localized,
                value: "\(assessments.count)",
                color: .purple
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                icon: "chart.bar.fill",
                label: "Unit Average".localized,
                value: String(format: "%.1f%%", unitAveragePercent),
                color: AssessmentPercentMetrics.color(for: unitAveragePercent)
            )
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
    }
    
    // MARK: - Grade Cell
    
    @ViewBuilder
    func gradeCell(student: Student, assessment: Assessment) -> some View {
        let result = findResult(student: student, assessment: assessment)
        let hasScore = (result?.score ?? 0) > 0
        
        Button {
            let finalResult = result ?? createResult(student: student, assessment: assessment)
            selectedResult = finalResult
        } label: {
            Text(displayText(for: result, assessment: assessment))
                .font(.body)
                .fontWeight(hasScore ? .semibold : .regular)
                .foregroundColor(hasScore ? gradeColor(result?.score ?? 0, assessment: assessment) : .secondary)
                .frame(width: gradeColumnWidth, height: cellHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(gradeCellBackground(for: result, assessment: assessment))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Student Average Cell
    
    func studentAverageCell(student: Student) -> some View {
        let studentResults = assessments.compactMap { assessment in
            findResult(student: student, assessment: assessment)
        }
        let averagePercent = studentResults.averagePercent
        
        return Text(String(format: "%.1f%%", averagePercent))
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(AssessmentPercentMetrics.color(for: averagePercent))
            .frame(width: gradeColumnWidth, height: cellHeight)
            .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Helpers
    
    func findResult(student: Student, assessment: Assessment) -> StudentResult? {
        allResults.first {
            $0.student?.id == student.id &&
            $0.assessment?.id == assessment.id
        }
    }
    
    func createResult(student: Student, assessment: Assessment) -> StudentResult {
        let newResult = StudentResult(student: student, score: 0, notes: "")
        newResult.assessment = assessment
        context.insert(newResult)
        return newResult
    }
    
    func displayText(for result: StudentResult?, assessment: Assessment) -> String {
        guard let result else { return "—" }
        if result.score == 0 {
            return "—"
        } else {
            let scoreText = formatScore(result.score)
            if assessment.safeMaxScore == Assessment.defaultMaxScore {
                return scoreText
            }
            return "\(scoreText)/\(formatScore(assessment.safeMaxScore))"
        }
    }
    
    func gradeColor(_ score: Double, assessment: Assessment) -> Color {
        AssessmentPercentMetrics.color(for: assessment.scorePercent(score))
    }
    
    func gradeCellBackground(for result: StudentResult?, assessment: Assessment) -> Color {
        guard let result, result.score > 0 else {
            return AssessmentPercentMetrics.tintColor(for: nil)
        }
        return AssessmentPercentMetrics.tintColor(for: assessment.scorePercent(result.score))
    }

    func formatScore(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
    
    var unitAveragePercent: Double {
        let allResults = assessments.flatMap { $0.results }
        return allResults.averagePercent
    }

    func ensureResultsExist() {
        let students = studentsInThisUnit
        guard !students.isEmpty else { return }

        for assessment in assessments {
            let existingStudentIDs = Set(assessment.results.compactMap { $0.student?.id })
            for student in students where !existingStudentIDs.contains(student.id) {
                assessment.results.append(StudentResult(student: student, assessment: assessment))
            }
        }
    }
    
    var headerBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    var rowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    var tableBackground: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
}
