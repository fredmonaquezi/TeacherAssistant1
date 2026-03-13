import SwiftUI
import SwiftData

struct ClassOverviewView: View {
    let schoolClass: SchoolClass
    @EnvironmentObject var languageManager: LanguageManager
    
    @Query private var allResults: [StudentResult]
    @Query private var allAttendanceSessions: [AttendanceSession]
    @Query private var allScores: [DevelopmentScore]
    
    @State private var selectedSubject: Subject?
    @State private var exportURL: URL?
    @State private var showingEmptyExportAlert = false
    @State private var showingExportFailedAlert = false
    
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
        filteredResults.averagePercent
    }

    var scoredFilteredResults: [StudentResult] {
        filteredResults.filter(\.isScored)
    }
    
    var attendanceRate: Double {
        let allRecords = allAttendanceSessions
            .filter { session in
                session.records.contains(where: { record in
                    schoolClass.students.contains(where: { $0.id == record.student?.id })
                })
            }
            .flatMap { $0.records }
            .filter { record in
                schoolClass.students.contains(where: { $0.id == record.student?.id })
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

    var gradingStatusSummary: ClassGradingStatusSummary {
        ClassGradingStatusSummary(
            totalCount: filteredResults.count,
            scoredCount: filteredResults.filter(\.isScored).count,
            resolvedCount: filteredResults.filter(\.isResolved).count,
            absentCount: filteredResults.filter { $0.status == .absent }.count,
            excusedCount: filteredResults.filter { $0.status == .excused }.count
        )
    }
    
    var topPerformers: [(student: Student, average: Double)] {
        students.compactMap { student in
            let studentResults = scoredFilteredResults.filter { $0.student?.id == student.id }
            guard !studentResults.isEmpty else { return nil }
            let avg = studentResults.averagePercent
            return (student, avg)
        }
        .sorted { $0.average > $1.average }
        .prefix(3)
        .map { $0 }
    }
    
    var studentsNeedingAttention: [ClassWatchlistItem] {
        students.compactMap { student in
            let studentResults = scoredFilteredResults.filter { $0.student?.id == student.id }
            var flags: [String] = []
            let average = studentResults.isEmpty ? nil : studentResults.averagePercent

            if let average, average < AssessmentPercentMetrics.satisfactoryThresholdPercent {
                flags.append("Low Average".localized)
            }
            if student.needsHelp { flags.append("Needs Help".localized) }
            if student.missingHomework { flags.append("Missing HW".localized) }

            let studentAttendance = allAttendanceSessions
                .flatMap { $0.records }
                .filter { $0.student?.id == student.id }
            if !studentAttendance.isEmpty {
                let presentCount = studentAttendance.filter { $0.status == .present }.count
                let attendanceRate = (Double(presentCount) / Double(studentAttendance.count)) * 100
                if attendanceRate < 90 {
                    flags.append("Low Attendance".localized)
                }
            }

            let missingAssignments = student.assignmentEntries.filter { entry in
                guard let assignment = entry.assignment else { return false }
                return entry.trackingState(relativeTo: assignment.dueDate) == .missing
            }.count
            if missingAssignments > 0 {
                flags.append(String(format: "%d missing work".localized, missingAssignments))
            }

            let activeInterventions = student.interventions.filter { $0.status != .resolved }.count
            if activeInterventions > 0 {
                flags.append(String(format: "%d active plans".localized, activeInterventions))
            }

            guard !flags.isEmpty else { return nil }

            return ClassWatchlistItem(
                student: student,
                average: average,
                flags: flags,
                activeInterventions: activeInterventions,
                missingAssignments: missingAssignments
            )
        }
        .sorted { lhs, rhs in
            if lhs.activeInterventions != rhs.activeInterventions {
                return lhs.activeInterventions > rhs.activeInterventions
            }
            if lhs.missingAssignments != rhs.missingAssignments {
                return lhs.missingAssignments > rhs.missingAssignments
            }
            switch (lhs.average, rhs.average) {
            case let (lhsAverage?, rhsAverage?):
                return lhsAverage < rhsAverage
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.student.name.localizedCaseInsensitiveCompare(rhs.student.name) == .orderedAscending
            }
        }
    }
    
    var gradeDistribution: (excellent: Int, good: Int, needsWork: Int) {
        let studentAverages = students.compactMap { student -> Double? in
            let studentResults = scoredFilteredResults.filter { $0.student?.id == student.id }
            guard !studentResults.isEmpty else { return nil }
            return studentResults.averagePercent
        }
        
        let excellent = studentAverages.filter { $0 >= AssessmentPercentMetrics.excellentThresholdPercent }.count
        let good = studentAverages.filter {
            $0 >= AssessmentPercentMetrics.satisfactoryThresholdPercent &&
            $0 < AssessmentPercentMetrics.excellentThresholdPercent
        }.count
        let needsWork = studentAverages.filter { $0 < AssessmentPercentMetrics.satisfactoryThresholdPercent }.count
        
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

                // Grading Status
                gradingStatusSection
                
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
        #if !os(macOS)
        .navigationTitle(String(format: "Gradebook - %@".localized, schoolClass.name))
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            )
        ) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Nothing to Export", isPresented: $showingEmptyExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There are no students available for this export.")
        }
        .alert("Export Failed", isPresented: $showingExportFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The export file could not be created. Please try again.")
        }
        .macNavigationDepth()
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
                value: String(format: "%.1f%%", classAverage),
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

    var gradingStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grading Status".localized)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                statusCard(
                    title: "Scored".localized,
                    value: "\(gradingStatusSummary.scoredCount)",
                    icon: "number.circle.fill",
                    color: .blue
                )

                statusCard(
                    title: "Pending".localized,
                    value: "\(gradingStatusSummary.pendingCount)",
                    icon: "tray.full.fill",
                    color: gradingStatusSummary.pendingCount > 0 ? .orange : .green
                )

                statusCard(
                    title: "Absent".localized,
                    value: "\(gradingStatusSummary.absentCount)",
                    icon: "person.crop.circle.badge.xmark",
                    color: gradingStatusSummary.absentCount > 0 ? .red : .secondary
                )

                statusCard(
                    title: "Excused".localized,
                    value: "\(gradingStatusSummary.excusedCount)",
                    icon: "checkmark.seal.fill",
                    color: gradingStatusSummary.excusedCount > 0 ? .teal : .secondary
                )
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(12)
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

    func statusCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        label: "Excellent (70%+)".localized,
                        count: dist.excellent,
                        total: total,
                        color: .green
                    )
                    
                    distributionBar(
                        label: "Good (50%-69%)".localized,
                        count: dist.good,
                        total: total,
                        color: .orange
                    )
                    
                    distributionBar(
                        label: "Needs Work (<50%)".localized,
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
                            
                            Text(String(format: "%.1f%%", performer.average))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(averageColor(performer.average))
                            
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
                Text("Watchlist".localized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(studentsNeedingAttention.count) \(studentsNeedingAttention.count == 1 ? "student".localized : "students".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(studentsNeedingAttention, id: \.student.id) { item in
                    NavigationLink {
                        StudentProgressView(student: item.student)
                    } label: {
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
                            
                            Text(item.average.map { String(format: "%.1f%%", $0) } ?? "—")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(item.average.map(averageColor(_:)) ?? .secondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
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
        }.filter(\.isScored)
        let avg = subjectResults.averagePercent
        let hasScores = !subjectResults.isEmpty
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subject.name)
                    .font(.subheadline)
                
                Spacer()
                
                Text(hasScores ? String(format: "%.1f%%", avg) : "—")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(hasScores ? averageColor(avg) : .secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasScores ? averageColor(avg) : Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width * (avg / 100.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Helpers
    
    func averageColor(_ average: Double) -> Color {
        AssessmentPercentMetrics.color(for: average)
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

    func exportCSV() {
        guard !students.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        guard let url = GradebookExportUtility.exportClassSummaryCSV(
            schoolClass: schoolClass,
            students: students,
            selectedSubject: selectedSubject,
            filteredResults: filteredResults,
            allAttendanceSessions: allAttendanceSessions
        ) else {
            showingExportFailedAlert = true
            return
        }

        exportURL = url
    }
}

struct ClassWatchlistItem {
    let student: Student
    let average: Double?
    let flags: [String]
    let activeInterventions: Int
    let missingAssignments: Int
}

struct ClassGradingStatusSummary {
    let totalCount: Int
    let scoredCount: Int
    let resolvedCount: Int
    let absentCount: Int
    let excusedCount: Int

    var pendingCount: Int {
        max(totalCount - resolvedCount, 0)
    }
}
