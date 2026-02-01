import SwiftUI
import SwiftUI
import SwiftData

struct ClassOverviewView: View {
    let schoolClass: SchoolClass
    @EnvironmentObject var languageManager: LanguageManager
    
    @Query private var allResults: [StudentResult]
    @Query private var allAttendanceSessions: [AttendanceSession]
    @Query private var allScores: [DevelopmentScore]
    
    @State private var selectedSubject: Subject?
    
    var students: [Student] {
        schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var subjects: [Subject] {
        schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // Filtered results
    var filteredResults: [StudentResult] {
        let classResults = allResults.filter { result in
            guard let student = result.student else { return false }
            return schoolClass.students.contains(where: { $0.id == student.id })
        }
        
        if let subject = selectedSubject {
            return classResults.filter { result in
                result.assessment?.unit?.subject?.id == subject.id
            }
        }
        
        return classResults
    }
    
    // MARK: - Computed Stats
    
    var classAverage: Double {
        filteredResults.averageScore
    }
    
    var attendanceRate: Double {
        let allRecords = allAttendanceSessions
            .filter { session in
                session.records.contains(where: { record in
                    schoolClass.students.contains(where: { $0.id == record.student.id })
                })
            }
            .flatMap { $0.records }
            .filter { record in
                schoolClass.students.contains(where: { $0.id == record.student.id })
            }
        
        guard !allRecords.isEmpty else { return 0 }
        
        let presentCount = allRecords.filter { $0.status == .present }.count
        return (Double(presentCount) / Double(allRecords.count)) * 100
    }
    
    var averageDevelopmentRating: Double {
        let classScores = allScores.filter { score in
            guard let student = score.student else { return false }
            return schoolClass.students.contains(where: { $0.id == student.id })
        }
        
        guard !classScores.isEmpty else { return 0 }
        
        let sum = classScores.reduce(0.0) { $0 + Double($1.rating) }
        return sum / Double(classScores.count)
    }
    
    var topPerformers: [(student: Student, average: Double)] {
        students.compactMap { student in
            let studentResults = filteredResults.filter { $0.student?.id == student.id }
            guard !studentResults.isEmpty else { return nil }
            let avg = studentResults.averageScore
            return (student, avg)
        }
        .sorted { $0.average > $1.average }
        .prefix(3)
        .map { $0 }
    }
    
    var studentsNeedingAttention: [(student: Student, average: Double, flags: [String])] {
        students.compactMap { student in
            let studentResults = filteredResults.filter { $0.student?.id == student.id }
            guard !studentResults.isEmpty else { return nil }
            let avg = studentResults.averageScore
            
            guard avg < 6.0 else { return nil }
            
            var flags: [String] = []
            if student.needsHelp { flags.append("Needs Help".localized) }
            if student.missingHomework { flags.append("Missing HW".localized) }
            
            let studentAttendance = allAttendanceSessions
                .flatMap { $0.records }
                .filter { $0.student.id == student.id }
            
            let absentCount = studentAttendance.filter { $0.status == .absent }.count
            if absentCount > 3 { flags.append("Absent often".localized) }
            
            return (student, avg, flags)
        }
        .sorted { $0.average < $1.average }
    }
    
    var gradeDistribution: (excellent: Int, good: Int, needsWork: Int) {
        let studentAverages = students.compactMap { student -> Double? in
            let studentResults = filteredResults.filter { $0.student?.id == student.id }
            guard !studentResults.isEmpty else { return nil }
            return studentResults.averageScore
        }
        
        let excellent = studentAverages.filter { $0 >= 8.0 }.count
        let good = studentAverages.filter { $0 >= 6.0 && $0 < 8.0 }.count
        let needsWork = studentAverages.filter { $0 < 6.0 }.count
        
        return (excellent, good, needsWork)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Filter Section
                filterSection
                
                // Key Stats Cards
                keyStatsSection
                
                // Performance Distribution
                distributionSection
                
                // Top Performers
                topPerformersSection
                
                // Needs Attention
                if !studentsNeedingAttention.isEmpty {
                    needsAttentionSection
                }
                
                // Subject Performance
                if subjects.count > 1 {
                    subjectPerformanceSection
                }
                
            }
            .padding()
        }
        .navigationTitle(String(format: "Gradebook - %@".localized, schoolClass.name))
    }
    
    // MARK: - Filter Section
    
    var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Subject".localized)
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // All subjects button
                    Button {
                        selectedSubject = nil
                    } label: {
                        Text("All Subjects".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedSubject == nil ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedSubject == nil ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    
                    // Subject filters
                    ForEach(subjects, id: \.id) { subject in
                        Button {
                            selectedSubject = subject
                        } label: {
                            Text(subject.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedSubject?.id == subject.id ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedSubject?.id == subject.id ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Key Stats Section
    
    var keyStatsSection: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Class Average".localized,
                value: String(format: "%.1f", classAverage),
                icon: "chart.bar.fill",
                color: averageColor(classAverage)
            )
            
            statCard(
                title: "Attendance".localized,
                value: String(format: "%.0f%%", attendanceRate),
                icon: "checkmark.circle.fill",
                color: attendanceColor(attendanceRate)
            )
            
            if averageDevelopmentRating > 0 {
                statCard(
                    title: "Development".localized,
                    value: String(format: "%.1f", averageDevelopmentRating),
                    icon: "star.fill",
                    color: .purple
                )
            }
        }
    }
    
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Distribution Section
    
    var distributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Distribution".localized)
                .font(.headline)
            
            let dist = gradeDistribution
            let total = dist.excellent + dist.good + dist.needsWork
            
            if total > 0 {
                VStack(spacing: 12) {
                    distributionBar(
                        label: "Excellent (8.0+)".localized,
                        count: dist.excellent,
                        total: total,
                        color: .green
                    )
                    
                    distributionBar(
                        label: "Good (6.0-7.9)".localized,
                        count: dist.good,
                        total: total,
                        color: .orange
                    )
                    
                    distributionBar(
                        label: "Needs Work (<6.0)".localized,
                        count: dist.needsWork,
                        total: total,
                        color: .red
                    )
                }
            } else {
                Text("No assessment data available".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
    }
    
    func distributionBar(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(count) \(count == 1 ? "student".localized : "students".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.0f%%", (Double(count) / Double(total)) * 100))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (Double(count) / Double(total)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Top Performers Section
    
    var topPerformersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("Top Performers".localized)
                    .font(.headline)
            }
            
            if topPerformers.isEmpty {
                Text("No assessment data available".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topPerformers.enumerated()), id: \.element.student.id) { index, performer in
                        HStack {
                            Text("\(index + 1).")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .frame(width: 30)
                            
                            Text(performer.student.name)
                                .font(.body)
                            
                            Spacer()
                            
                            Text(String(format: "%.1f", performer.average))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Needs Attention Section
    
    var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Needs Attention".localized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(studentsNeedingAttention.count) \(studentsNeedingAttention.count == 1 ? "student".localized : "students".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(studentsNeedingAttention, id: \.student.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.student.name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            if !item.flags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(item.flags, id: \.self) { flag in
                                        Text(flag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", item.average))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Subject Performance Section
    
    var subjectPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance by Subject".localized)
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(subjects, id: \.id) { subject in
                    subjectPerformanceBar(subject)
                }
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
    }
    
    func subjectPerformanceBar(_ subject: Subject) -> some View {
        let subjectResults = allResults.filter { result in
            result.assessment?.unit?.subject?.id == subject.id &&
            schoolClass.students.contains(where: { $0.id == result.student?.id })
        }
        let avg = subjectResults.averageScore
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subject.name)
                    .font(.subheadline)
                
                Spacer()
                
                Text(String(format: "%.1f", avg))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(averageColor(avg))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(averageColor(avg))
                        .frame(width: geometry.size.width * (avg / 10.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Helpers
    
    func averageColor(_ average: Double) -> Color {
        if average >= 8.0 { return .green }
        if average >= 6.0 { return .orange }
        return .red
    }
    
    func attendanceColor(_ rate: Double) -> Color {
        if rate >= 90 { return .green }
        if rate >= 75 { return .orange }
        return .red
    }
    
    // MARK: - Dark Mode Support
    
    var sectionBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemGroupedBackground)
        #endif
    }
}

