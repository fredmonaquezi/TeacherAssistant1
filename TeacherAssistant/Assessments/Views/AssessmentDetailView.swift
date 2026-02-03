import SwiftUI
import SwiftUI
import SwiftData

struct AssessmentDetailView: View {
    @Bindable var assessment: Assessment
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - Statistics Card
                statisticsCard
                
                // MARK: - Assessment Info Card
                assessmentInfoCard
                
                // MARK: - Description Section
                descriptionSection
                
                // MARK: - Student Grades Section
                studentGradesSection
                
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(assessment.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Assessment title".localized, text: $assessment.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    #if os(macOS)
                    .textFieldStyle(.plain)
                    #endif
            }
        }
        .onAppear {
            ensureResultsExist()
        }
    }
    
    // MARK: - Statistics Card
    
    var statisticsCard: some View {
        HStack(spacing: 16) {
            statBox(
                title: "Class Average".localized,
                value: String(format: "%.1f", assessment.results.averageScore),
                icon: "chart.bar.fill",
                color: averageColor(assessment.results.averageScore)
            )
            
            statBox(
                title: "Highest".localized,
                value: String(format: "%.1f", highestScore),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            
            statBox(
                title: "Lowest".localized,
                value: String(format: "%.1f", lowestScore),
                icon: "arrow.down.circle.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }
    
    func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))  // ← Bigger icon
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 40, weight: .bold))  // ← Bigger value
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)  // ← Bigger label
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
    
    var highestScore: Double {
        assessment.results.map { $0.score }.max() ?? 0
    }
    
    var lowestScore: Double {
        let scores = assessment.results.filter { $0.score > 0 }.map { $0.score }
        return scores.min() ?? 0
    }
    
    // MARK: - Assessment Info Card
    
    var assessmentInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assessment Info".localized)
                .font(.headline)
            
            if let unit = assessment.unit,
               let subject = unit.subject,
               let schoolClass = subject.schoolClass {
                
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "building.2", label: "Class".localized, value: schoolClass.name)
                    infoRow(icon: "book", label: "Subject".localized, value: subject.name)
                    infoRow(icon: "folder", label: "Unit".localized, value: unit.name)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 28)  // ← Bigger icon
            
            Text(label)
                .font(.body)  // ← Changed from .subheadline
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)  // ← Wider
            
            Text(value)
                .font(.body)  // ← Changed from .subheadline
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Description Section
    
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description".localized)
                .font(.title3)  // ← Bigger heading
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            TextEditor(text: $assessment.details)
                .frame(minHeight: 150)  // ← Taller editor
                .padding(12)  // ← More padding
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                .font(.body)  // ← Add this line to make the text bigger inside TextEditor
        }
    }
    
    // MARK: - Student Grades Section
    
    var studentGradesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Student Grades".localized)
                    .font(.title3)  // ← Bigger heading
                    .fontWeight(.semibold)
                
                Spacer()
                
                let gradedCount = assessment.results.filter { $0.score > 0 }.count
                let totalCount = assessment.results.count
                
                Text("\(gradedCount) / \(totalCount) " + "graded".localized)
                    .font(.body)  // ← Changed from .subheadline
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if sortedResults.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sortedResults) { result in
                        StudentGradeCard(result: result)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No students yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Students will appear here once they're added to the class".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Sorted Results
    
    var sortedResults: [StudentResult] {
        assessment.results.sorted { result1, result2 in
            let name1 = result1.student?.name ?? ""
            let name2 = result2.student?.name ?? ""
            return name1 < name2
        }
    }

    // MARK: - Data bootstrap

    func ensureResultsExist() {
        guard let unit = assessment.unit,
              let subject = unit.subject,
              let schoolClass = subject.schoolClass
        else { return }

        let existingStudentIDs = Set(assessment.results.compactMap { $0.student?.id })

        for student in schoolClass.students.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if existingStudentIDs.contains(student.id) { continue }
            let result = StudentResult(student: student)
            result.assessment = assessment
            assessment.results.append(result)
        }
    }
}

// MARK: - Student Grade Card

struct StudentGradeCard: View {
    @Bindable var result: StudentResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Student name and score
            HStack {
                Text(result.student?.name ?? "Unknown")
                    .font(.title3)  // ← Bigger student name
                    .fontWeight(.semibold)
                
                Spacer()
                
                scoreField
            }
            
            // Notes field
            HStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.body)  // ← Bigger icon
                    .foregroundColor(.secondary)
                
                TextField("Add notes".localized, text: $result.notes)
                    .textFieldStyle(.plain)
                    .font(.body)  // ← Bigger notes text
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
        }
        .padding(18)  // ← More padding
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(scoreColor.opacity(0.3), lineWidth: result.score > 0 ? 2 : 1)
        )
    }
    
    @ViewBuilder
    var scoreField: some View {
        HStack(spacing: 10) {
            Text("Score:".localized)
                .font(.body)  // ← Bigger label
                .foregroundColor(.secondary)
            
            #if os(iOS)
            TextField("0", value: $result.score, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)  // ← Wider field
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .font(.system(size: 24, weight: .bold))  // ← Much bigger score
                .foregroundColor(scoreColor)
            #else
            TextField("0", value: $result.score, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)  // ← Wider field
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .font(.system(size: 24, weight: .bold))  // ← Much bigger score
                .foregroundColor(scoreColor)
            #endif
        }
    }
    
    var scoreColor: Color {
        if result.score >= 7.0 { return .green }
        if result.score >= 5.0 { return .orange }
        if result.score > 0 { return .red }
        return .gray
    }
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
