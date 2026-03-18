import SwiftUI
import SwiftData

struct StudentDetailView: View {
    
    @Bindable var student: Student
    let showsDismissButton: Bool
    
    @State private var showingSubjectPicker = false
    @State private var selectedSubject: Subject?
    @State private var selectedUnitForEvaluation: Unit?
    @State private var isEditingInfo = false
    @State private var showingDevelopmentTracker = false  // ← ADD THIS
    @State private var showingInterventions = false
    @State private var derivedData: StudentDetailDerivedData = .empty
    @State private var saveRefreshRevision = 0
    
    @Query var allResults: [StudentResult]
    @Query var allAttendanceSessions: [AttendanceSession]
    @Query var allScores: [DevelopmentScore]
    
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appMotionContext) private var motion
    @Environment(\.dismiss) private var dismiss

    init(
        student: Student,
        initiallyShowingInterventions: Bool = false,
        showsDismissButton: Bool = false
    ) {
        self.student = student
        self.showsDismissButton = showsDismissButton
        _showingInterventions = State(initialValue: initiallyShowingInterventions)
    }
    
    // MARK: - Computed Data
    
    var subjectsForStudentClass: [Subject] {
        derivedData.subjectsForStudentClass
    }
    
    var scoredResultsForThisStudent: [StudentResult] {
        derivedData.scoredResultsForStudent
    }
    
    var studentAverage: Double {
        derivedData.studentAverage
    }
    
    var attendanceRecords: [AttendanceRecord] {
        derivedData.attendanceRecords
    }
    
    var attendanceSummary: (present: Int, absent: Int, late: Int, leftEarly: Int) {
        (
            present: derivedData.attendanceSummary.present,
            absent: derivedData.attendanceSummary.absent,
            late: derivedData.attendanceSummary.late,
            leftEarly: derivedData.attendanceSummary.leftEarly
        )
    }

    private var refreshToken: String {
        [
            String(allResults.count),
            String(allAttendanceSessions.count),
            String(allScores.count),
            String(describing: student.id),
            String(saveRefreshRevision),
        ].joined(separator: "|")
    }

    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Quick Status Bar
                quickStatusBar
                    .appMotionReveal(index: 0)
                
                // MARK: - Statistics Cards
                HStack(spacing: 16) {
                    statCard(
                        title: "Overall Average",
                        value: String(format: "%.1f", studentAverage),
                        icon: "chart.bar.fill",
                        color: averageColor(studentAverage)
                    )
                    
                    statCard(
                        title: "Total Assessments",
                        value: "\(scoredResultsForThisStudent.count)",
                        icon: "list.bullet.clipboard",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                .appMotionReveal(index: 1)
                
                // MARK: - Attendance Summary
                attendanceSummaryCard
                    .appMotionReveal(index: 2)
                
                // 👉 ADD THIS LINE RIGHT HERE:
                StudentRunningRecordsSection(student: student)
                    .appMotionReveal(index: 3)
                
                // MARK: - Subject Breakdown
                subjectBreakdownSection
                    .appMotionReveal(index: 4)

                // MARK: - Actions
                actionsSection
                    .appMotionReveal(index: 5)

                interventionSummarySection
                    .appMotionReveal(index: 6)

                // MARK: - Development Tracking
                developmentTrackingSection
                    .appMotionReveal(index: 7)

                // MARK: - Recent Grades
                recentGradesSection
                    .appMotionReveal(index: 8)
                
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(student.name)
        .toolbar {
            #if os(macOS)
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit Info".localized) {
                        isEditingInfo = true
                    }
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Info".localized) {
                    isEditingInfo = true
                }
            }
            #endif
        }
        .sheet(isPresented: $isEditingInfo) {
            studentInfoSheet
                .appSheetMotion()
        }
        .navigationDestination(item: $selectedUnitForEvaluation) { unit in
            StudentUnitEvaluationView(student: student, unit: unit)
        }
        .sheet(isPresented: $showingSubjectPicker) {
            subjectPickerSheet
                .appSheetMotion()
        }
        .sheet(isPresented: $showingInterventions) {
            StudentInterventionsSheet(student: student)
                .appSheetMotion()
        }
        .sheet(item: $selectedSubject) { subject in
            unitPickerSheet(for: subject)
                .appSheetMotion()
        }
        .onReceive(NotificationCenter.default.publisher(for: .persistenceDidSave)) { _ in
            saveRefreshRevision &+= 1
        }
        .task(id: refreshToken) {
            do {
                try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
            } catch {
                return
            }
            await refreshDerivedData()
        }
        .macNavigationDepth()
    }
    
    // MARK: - Quick Status Bar
    
    var quickStatusBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Status".localized)
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                statusToggle(
                    isOn: $student.isParticipatingWell,
                    icon: "⭐",
                    label: "Participating Well".localized,
                    activeColor: .green
                )
                
                statusToggle(
                    isOn: $student.needsHelp,
                    icon: "⚠️",
                    label: "Needs Help".localized,
                    activeColor: .orange
                )
                
                statusToggle(
                    isOn: $student.missingHomework,
                    icon: "📚",
                    label: "Missing Homework".localized,
                    activeColor: .red
                )
            }
            .padding(.horizontal)
        }
    }
    
    func statusToggle(isOn: Binding<Bool>, icon: String, label: String, activeColor: Color) -> some View {
        Button(action: {
            withAnimation(motion.animation(.quick, interactive: true)) {
                isOn.wrappedValue.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Text(isOn.wrappedValue ? "Active".localized : "Inactive".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark or empty circle
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isOn.wrappedValue ? activeColor : .gray.opacity(0.3))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                isOn.wrappedValue
                ? activeColor.opacity(0.15)
                : Color.gray.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isOn.wrappedValue ? activeColor : Color.gray.opacity(0.2),
                        lineWidth: isOn.wrappedValue ? 2 : 1
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(AppPressableButtonStyle())
    }
    
    func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    // MARK: - Stat Card
    
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText())
            
            Text(title.localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    
    // MARK: - Attendance Summary Card
    
    var attendanceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance Summary".localized)
                .font(.headline)
            
            if attendanceRecords.isEmpty {
                Text("No attendance records yet".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let summary = attendanceSummary
                let total = summary.present + summary.absent + summary.late + summary.leftEarly
                
                HStack(spacing: 20) {
                    attendanceStat(label: "Present".localized, value: summary.present, total: total, color: .green)
                    attendanceStat(label: "Absent".localized, value: summary.absent, total: total, color: .red)
                    attendanceStat(label: "Late".localized, value: summary.late, total: total, color: .orange)
                    attendanceStat(label: "Left Early".localized, value: summary.leftEarly, total: total, color: .yellow)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func attendanceStat(label: String, value: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if total > 0 {
                Text("\(Int((Double(value) / Double(total)) * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Subject Breakdown
    
    var subjectBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Subject".localized)
                .font(.headline)
                .padding(.horizontal)
            
            if derivedData.subjectCardViewModels.isEmpty {
                Text("No subjects in this class yet".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(derivedData.subjectCardViewModels) { model in
                    StudentDetailSubjectCardView(model: model)
                }
            }
        }
    }
    
    // MARK: - Recent Grades
    
    var recentGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assessments".localized)
                .font(.headline)
                .padding(.horizontal)
            
            if derivedData.recentGradeViewModels.isEmpty {
                Text("No assessments yet".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(derivedData.recentGradeViewModels) { model in
                    StudentDetailRecentGradeRowView(model: model)
                }
            }
        }
    }
    
   
    // MARK: - Development Tracking Section

    var developmentTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Development Tracking".localized)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingDevelopmentTracker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                        Text("Update".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .buttonStyle(AppPressableButtonStyle())
            }
            .padding(.horizontal)
            
            if !derivedData.latestDevelopmentScores.isEmpty {
                // Show latest ratings
                VStack(spacing: 8) {
                    ForEach(derivedData.developmentCategoryViewModels) { group in
                        developmentCategoryCard(category: group.category, scores: group.scores)
                    }
                }
                .padding(.horizontal)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No development tracking yet".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showingDevelopmentTracker = true
                    } label: {
                        Text("Start Tracking".localized)
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingDevelopmentTracker) {
            DevelopmentTrackerSheet(student: student)
                .appSheetMotion()
        }
    }

    func developmentCategoryCard(category: String, scores: [StudentDetailDevelopmentScoreViewModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayRubricText(category))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            ForEach(scores) { score in
                HStack {
                    Text(displayRubricText(score.criterionName))
                        .font(.caption)
                    
                    Spacer()
                    
                    // Star rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= score.rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= score.rating ? ratingColor(for: score.rating) : .gray.opacity(0.3))
                        }
                    }
                    
                    // Rating label
                    Text(ratingLabel(score.rating))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 150, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }

    func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 5: return .green
        case 4: return .blue
        case 3: return .orange
        case 2: return .yellow
        case 1: return .red
        default: return .gray
        }
    }

    func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return languageManager.localized("Needs Significant Support")
        case 2: return languageManager.localized("Beginning to Develop")
        case 3: return languageManager.localized("Developing")
        case 4: return languageManager.localized("Proficient")
        case 5: return languageManager.localized("Mastering / Exceeding")
        default: return languageManager.localized("Not Rated")
        }
    }

    func displayRubricText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = languageManager.localized(trimmed)
        if localized != trimmed { return localized }
        return RubricLocalization.localized(trimmed, languageCode: languageManager.currentLanguage.rawValue)
    }

    func localizedGenderLabel(_ gender: StudentGender) -> String {
        languageManager.localized(gender.rawValue)
    }

    @MainActor
    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.studentDetailDerive)
        let derived = await StudentDetailStore.deriveAsync(
            student: student,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allScores: allScores
        )
        if Task.isCancelled {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }

        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
    }
    
    // MARK: - Actions Section
    
    var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingSubjectPicker = true
            } label: {
                Label("Evaluate in Unit".localized, systemImage: "pencil.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(AppPressableButtonStyle())
            
            NavigationLink {
                StudentProgressView(student: student)
            } label: {
                Label("View Detailed Progress".localized, systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .buttonStyle(AppPressableButtonStyle())

            Button {
                showingInterventions = true
            } label: {
                Label("Manage Interventions".localized, systemImage: "cross.case.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.16))
                    .foregroundColor(.orange)
                    .cornerRadius(10)
            }
            .buttonStyle(AppPressableButtonStyle())
        }
        .padding(.horizontal)
    }

    var interventionSummarySection: some View {
        let orderedInterventions = student.interventions.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
        let activeCount = orderedInterventions.filter { $0.status != .resolved }.count
        let resolvedCount = orderedInterventions.filter { $0.status == .resolved }.count
        let overdueCount = orderedInterventions.filter(\.needsFollowUp).count

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundColor(.orange)
                Text("Support Tracking".localized)
                    .font(.headline)

                Spacer()

                Button("Open".localized) {
                    showingInterventions = true
                }
                .font(.caption.weight(.semibold))
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Active".localized,
                    value: "\(activeCount)",
                    icon: "exclamationmark.circle.fill",
                    color: activeCount > 0 ? .orange : .green
                )

                statCard(
                    title: "Follow-Up".localized,
                    value: "\(overdueCount)",
                    icon: "calendar.badge.exclamationmark",
                    color: overdueCount > 0 ? .red : .green
                )

                statCard(
                    title: "Resolved".localized,
                    value: "\(resolvedCount)",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Student Info Sheet
    
    var studentInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Profile Header
                    profileHeader
                    
                    // MARK: - Name Section
                    nameSection

                    // MARK: - Gender Section
                    genderSection
                    
                    // MARK: - Status Indicators
                    statusIndicatorsSection
                    
                    // MARK: - Notes Section
                    notesSection
                    
                }
                .padding()
            }
            .navigationTitle("Edit Student".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized) {
                        isEditingInfo = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
    }
    
    // MARK: - Profile Header
    
    var profileHeader: some View {
        VStack(spacing: 12) {
            // Profile Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(student.name.prefix(1).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(student.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let className = student.schoolClass?.name {
                Text(className)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - Name Section
    
    var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                Text("Student Name".localized)
                    .font(.headline)
            }
            
            TextField("Enter student name".localized, text: $student.name)
                .textFieldStyle(.plain)
                .font(.body)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Gender Section

    var genderSection: some View {
        let genderBinding = Binding<StudentGender>(
            get: { StudentGender(rawValue: student.gender) ?? .preferNotToSay },
            set: { student.gender = $0.rawValue }
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.indigo)
                Text("Gender (Optional)".localized)
                    .font(.headline)
            }

            Picker("Gender".localized, selection: genderBinding) {
                ForEach(StudentGender.allCases, id: \.self) { genderOption in
                    Text(localizedGenderLabel(genderOption)).tag(genderOption)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Text("Used for group balancing in group generator".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Status Indicators Section
    
    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
                Text("Status Indicators".localized)
                    .font(.headline)
            }
            
            Text("Tap any indicator to toggle it on or off".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                statusCard(
                    isOn: $student.isParticipatingWell,
                    icon: "⭐",
                    title: "Participating Well".localized,
                    description: "Student actively engages in class".localized,
                    color: .green
                )
                
                statusCard(
                    isOn: $student.needsHelp,
                    icon: "⚠️",
                    title: "Needs Help".localized,
                    description: "Student requires additional support".localized,
                    color: .orange
                )
                
                statusCard(
                    isOn: $student.missingHomework,
                    icon: "📚",
                    title: "Missing Homework".localized,
                    description: "Student has incomplete assignments".localized,
                    color: .red
                )
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func statusCard(isOn: Binding<Bool>, icon: String, title: String, description: String, color: Color) -> some View {
        Button(action: {
            withAnimation(motion.animation(.quick, interactive: true)) {
                isOn.wrappedValue.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Icon
                Text(icon)
                    .font(.title)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Toggle indicator
                ZStack {
                    Circle()
                        .fill(isOn.wrappedValue ? color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isOn.wrappedValue ? color : .gray.opacity(0.4))
                }
            }
            .padding()
            .background(
                isOn.wrappedValue
                ? color.opacity(0.1)
                : Color.gray.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isOn.wrappedValue ? color.opacity(0.5) : Color.gray.opacity(0.2),
                        lineWidth: isOn.wrappedValue ? 2 : 1
                    )
            )
            .cornerRadius(10)
        }
        .buttonStyle(AppPressableButtonStyle())
    }
    
    // MARK: - Notes Section
    
    var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.purple)
                Text("Teacher Notes".localized)
                    .font(.headline)
            }
            
            Text("Add any observations, concerns, or important information".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                
                // Placeholder text
                if student.notes.isEmpty {
                    Text("Enter notes here...".localized)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                // Text editor
                TextEditor(text: $student.notes)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 120)
            
            // Character count helper
            HStack {
                Spacer()
                Text("\(student.notes.count) " + "characters".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Subject Picker Sheet
    
    var subjectPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Choose Subject".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(format: "Select a subject to evaluate %@".localized, student.name))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Subjects List
                    let subjects = subjectsForStudentClass
                    
                    if subjects.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Subjects Yet".localized)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add subjects to this class first".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subjects, id: \.id) { subject in
                                subjectPickerCard(subject: subject)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Evaluate Unit".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        showingSubjectPicker = false
                    }
                    .foregroundColor(.red)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 550, minHeight: 450)
#endif
    }
    
    func subjectPickerCard(subject: Subject) -> some View {
        Button {
            selectedSubject = subject
            showingSubjectPicker = false
        } label: {
            HStack(spacing: 16) {
                // Subject Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                // Subject Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    let unitCount = subject.units.count
                    Text("\(unitCount) \(unitCount == 1 ? "unit".localized : "units".localized)")                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(AppPressableButtonStyle())
    }
    
    // MARK: - Unit Picker Sheet
    
    func unitPickerSheet(for subject: Subject) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Section
                    VStack(spacing: 12) {
                        // Subject Icon with gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        
                        Text("Choose Unit".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(format: "in %@".localized, subject.name))
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text(String(format: "Select a unit to evaluate %@".localized, student.name))                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Units List
                    let units = subject.units.sorted { $0.sortOrder < $1.sortOrder }
                    
                    if units.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Units Yet".localized)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "Add units to %@ first".localized, subject.name))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(units, id: \.id) { unit in
                                unitPickerCard(unit: unit)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Choose Unit".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back".localized) {
                        selectedSubject = nil
                    }
                    .foregroundColor(.red)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 550, minHeight: 450)
#endif
    }
    
    func unitPickerCard(unit: Unit) -> some View {
        Button {
            selectedSubject = nil
            selectedUnitForEvaluation = unit
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Unit Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    
                    // Unit Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(unit.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 12) {
                            // Assessment count
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption)
                                let assessmentCount = unit.assessments.count
                                Text("\(assessmentCount) \(assessmentCount == 1 ? "assessment".localized : "assessments".localized)")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Arrow with circle background
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.right")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                }
                .padding()
            }
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }
    
    // MARK: - Dark Mode Support
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
