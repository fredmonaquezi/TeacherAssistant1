import SwiftUI
import SwiftData

struct UnitGradebookView: View {
    
    @Environment(\.modelContext) private var context
    
    @Bindable var unit: Unit
    
    @State private var selectedResult: StudentResult?
    @State private var selectedBulkAssessmentID: PersistentIdentifier?
    @State private var bulkAction: BulkGradeAction?
    @State private var assessmentPendingClear: Assessment?
    @State private var bulkActionMessage: String?
    @State private var exportURL: URL?
    @State private var showingEmptyExportAlert = false
    @State private var showingExportFailedAlert = false
    @State private var isAssessmentTableCollapsed = true
    
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

    enum BulkGradeAction: Identifiable {
        case fillAll(Assessment)
        case fillUngraded(Assessment)

        var id: String {
            switch self {
            case .fillAll(let assessment):
                return "fillAll-\(assessment.persistentModelID)"
            case .fillUngraded(let assessment):
                return "fillUngraded-\(assessment.persistentModelID)"
            }
        }

        var assessment: Assessment {
            switch self {
            case .fillAll(let assessment), .fillUngraded(let assessment):
                return assessment
            }
        }

        var onlyUngraded: Bool {
            switch self {
            case .fillAll:
                return false
            case .fillUngraded:
                return true
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Statistics bar
            statisticsBar

            if !assessments.isEmpty {
                Divider()
                bulkActionsBar
            }
            
            Divider()
            assessmentTableSection
        }
        #if !os(macOS)
        .navigationTitle("Gradebook".localized + ": \(unit.name)")
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
        .sheet(item: $bulkAction) { action in
            BulkScoreSheet(
                assessmentTitle: action.assessment.title,
                maxScore: action.assessment.safeMaxScore,
                onlyUngraded: action.onlyUngraded
            ) { score in
                applyBulkScore(
                    score,
                    to: action.assessment,
                    onlyUngraded: action.onlyUngraded
                )
            }
        }
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
        .alert(
            "Reset Results?".localized,
            isPresented: Binding(
                get: { assessmentPendingClear != nil },
                set: { if !$0 { assessmentPendingClear = nil } }
            )
        ) {
            Button("Cancel".localized, role: .cancel) {
                assessmentPendingClear = nil
            }

            Button("Clear".localized, role: .destructive) {
                if let assessmentPendingClear {
                    clearScores(for: assessmentPendingClear)
                }
                assessmentPendingClear = nil
            }
        } message: {
            Text(
                String(
                    format: "This will reset every student in %@ back to ungraded.".localized,
                    assessmentPendingClear?.title ?? ""
                )
            )
        }
        .alert(
            "Bulk Grading".localized,
            isPresented: Binding(
                get: { bulkActionMessage != nil },
                set: { if !$0 { bulkActionMessage = nil } }
            )
        ) {
            Button("OK".localized, role: .cancel) { }
        } message: {
            Text(bulkActionMessage ?? "")
        }
        .alert("Nothing to Export", isPresented: $showingEmptyExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There are no students or assessments available for this export.")
        }
        .alert("Export Failed", isPresented: $showingExportFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The export file could not be created. Please try again.")
        }
        .onAppear {
            ensureResultsExist()
            synchronizeBulkAssessmentSelection()
        }
        .onChange(of: assessments.map(\.persistentModelID)) { _, _ in
            synchronizeBulkAssessmentSelection()
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

    var assessmentTableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isAssessmentTableCollapsed.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("All Assessments".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(
                            String(
                                format: "%d students - %d assessments".localized,
                                studentsInThisUnit.count,
                                assessments.count
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !assessments.isEmpty {
                        Text(selectedBulkAssessment?.title ?? assessments.first?.title ?? "")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: isAssessmentTableCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.03))

            if isAssessmentTableCollapsed {
                collapsedAssessmentSummary
            } else {
                Divider()
                assessmentTable
            }
        }
    }

    var collapsedAssessmentSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Expand to review the full gradebook grid, compare assessments, and jump into score entry.".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                summaryPill(
                    title: "Students".localized,
                    value: "\(studentsInThisUnit.count)",
                    color: .blue
                )
                summaryPill(
                    title: "Assessments".localized,
                    value: "\(assessments.count)",
                    color: .purple
                )
                summaryPill(
                    title: "Average".localized,
                    value: String(format: "%.1f%%", unitAveragePercent),
                    color: AssessmentPercentMetrics.color(for: unitAveragePercent)
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.02))
    }

    var assessmentTable: some View {
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
                        Button {
                            guard let quickAssessment = preferredAssessmentForQuickEntry(student: student) else { return }
                            openScoreEntry(student: student, assessment: quickAssessment)
                        } label: {
                            HStack(spacing: 8) {
                                Text(student.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "square.and.pencil")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: studentColumnWidth, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: cellHeight)
                            .background(rowBackgroundColor.opacity(0.5))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(assessments.isEmpty)

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

    var bulkActionsBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulk Actions".localized)
                        .font(.headline)
                    Text("Choose an assessment, then apply grading actions to the whole column.".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Assessment".localized, selection: bulkAssessmentSelectionBinding) {
                    ForEach(assessments, id: \.id) { assessment in
                        Text(assessment.title)
                            .tag(Optional.some(assessment.id))
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif

                Spacer(minLength: 0)
            }

            if let selectedBulkAssessment {
                HStack(spacing: 12) {
                    bulkActionButton(
                        title: "Next Pending".localized,
                        icon: "arrow.right.circle.fill",
                        color: .blue,
                        isDisabled: nextPendingResult(in: selectedBulkAssessment) == nil
                    ) {
                        openNextPending(for: selectedBulkAssessment)
                    }

                    bulkActionButton(
                        title: "Fill Ungraded".localized,
                        icon: "square.grid.2x2.fill",
                        color: .orange,
                        isDisabled: gradingSummary(for: selectedBulkAssessment).remaining == 0
                    ) {
                        bulkAction = .fillUngraded(selectedBulkAssessment)
                    }

                    bulkActionButton(
                        title: "Fill All".localized,
                        icon: "rectangle.3.group.fill",
                        color: .green,
                        isDisabled: studentsInThisUnit.isEmpty
                    ) {
                        bulkAction = .fillAll(selectedBulkAssessment)
                    }

                    bulkActionButton(
                        title: "Mark Absent".localized,
                        icon: "person.crop.circle.badge.xmark",
                        color: .orange,
                        isDisabled: studentsInThisUnit.isEmpty
                    ) {
                        applyBulkStatus(.absent, to: selectedBulkAssessment, onlyPending: false)
                    }

                    bulkActionButton(
                        title: "Excuse".localized,
                        icon: "checkmark.seal.fill",
                        color: .purple,
                        isDisabled: studentsInThisUnit.isEmpty
                    ) {
                        applyBulkStatus(.excused, to: selectedBulkAssessment, onlyPending: false)
                    }

                    bulkActionButton(
                        title: "Reset".localized,
                        icon: "arrow.uturn.backward.circle.fill",
                        color: .red,
                        isDisabled: gradingSummary(for: selectedBulkAssessment).resolved == 0
                    ) {
                        assessmentPendingClear = selectedBulkAssessment
                    }
                }

                let summary = gradingSummary(for: selectedBulkAssessment)
                HStack(spacing: 14) {
                    summaryPill(
                        title: "Resolved".localized,
                        value: "\(summary.resolved)/\(summary.total)",
                        color: summary.resolved == summary.total && summary.total > 0 ? .green : .blue
                    )

                    if summary.remaining > 0 {
                        summaryPill(
                            title: "Remaining".localized,
                            value: "\(summary.remaining)",
                            color: .orange
                        )
                    }

                    summaryPill(
                        title: "Max".localized,
                        value: formatScore(selectedBulkAssessment.safeMaxScore),
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.04))
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

    func bulkActionButton(
        title: String,
        icon: String,
        color: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(isDisabled ? .secondary : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.08) : color.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    func summaryPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(color.opacity(0.10))
        )
    }
    
    // MARK: - Grade Cell
    
    @ViewBuilder
    func gradeCell(student: Student, assessment: Assessment) -> some View {
        let result = findResult(student: student, assessment: assessment)
        let isResolved = result?.isResolved ?? false
        
        Button {
            openScoreEntry(student: student, assessment: assessment)
        } label: {
            Text(displayText(for: result, assessment: assessment))
                .font(.body)
                .fontWeight(isResolved ? .semibold : .regular)
                .foregroundColor(gradeForegroundColor(for: result, assessment: assessment))
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
        assessment.canonicalResult(for: student)
    }

    func openScoreEntry(student: Student, assessment: Assessment) {
        let result = assessment.ensureCanonicalResult(for: student, context: context)
        selectedResult = result
    }

    var selectedBulkAssessment: Assessment? {
        guard let selectedBulkAssessmentID else { return assessments.first }
        return assessments.first(where: { $0.id == selectedBulkAssessmentID }) ?? assessments.first
    }

    var bulkAssessmentSelectionBinding: Binding<PersistentIdentifier?> {
        Binding(
            get: { selectedBulkAssessment?.id },
            set: { selectedBulkAssessmentID = $0 }
        )
    }

    func gradingSummary(for assessment: Assessment) -> (resolved: Int, remaining: Int, total: Int) {
        let results = studentsInThisUnit.compactMap { student in
            assessment.canonicalResult(for: student)
        }
        let resolved = results.filter(\.isResolved).count
        let total = studentsInThisUnit.count
        return (resolved, max(total - resolved, 0), total)
    }

    func nextPendingResult(in assessment: Assessment) -> StudentResult? {
        studentsInThisUnit.compactMap { student -> StudentResult? in
            guard let result = assessment.canonicalResult(for: student) else {
                return nil
            }
            return result.isResolved ? nil : result
        }.first
    }

    func openNextPending(for assessment: Assessment) {
        selectedResult = nextPendingResult(in: assessment)
        if selectedResult == nil {
            bulkActionMessage = "Every student in this assessment already has a resolved status.".localized
        }
    }

    func applyBulkScore(_ score: Double, to assessment: Assessment, onlyUngraded: Bool) {
        let clampedScore = assessment.clampedScore(score)
        var updatedCount = 0

        for student in studentsInThisUnit {
            let result = assessment.ensureCanonicalResult(for: student, context: context)
            if onlyUngraded && result.isResolved {
                continue
            }

            if result.score != clampedScore || result.status != .scored {
                result.applyStatus(.scored, score: clampedScore)
                updatedCount += 1
            }
        }

        guard updatedCount > 0 else {
            bulkActionMessage = onlyUngraded
                ? "There were no pending students to update.".localized
                : "All students already had that score.".localized
            return
        }

        Task {
            let saveResult = await SaveCoordinator.perform(
                context: context,
                reason: onlyUngraded ? "Bulk fill ungraded scores" : "Bulk fill scores"
            )
            if saveResult.didSave {
                await MainActor.run {
                    bulkActionMessage = String(
                        format: onlyUngraded
                            ? "Updated %d pending students in %@.".localized
                            : "Updated %d students in %@.".localized,
                        updatedCount,
                        assessment.title
                    )
                }
            }
        }
    }

    func clearScores(for assessment: Assessment) {
        var clearedCount = 0

        for student in studentsInThisUnit {
            let result = assessment.ensureCanonicalResult(for: student, context: context)
            guard result.isResolved else { continue }
            result.applyStatus(.ungraded)
            clearedCount += 1
        }

        guard clearedCount > 0 else {
            bulkActionMessage = "There were no statuses to reset.".localized
            return
        }

        Task {
            let saveResult = await SaveCoordinator.perform(
                context: context,
                reason: "Reset assessment results"
            )
            if saveResult.didSave {
                await MainActor.run {
                    bulkActionMessage = String(
                        format: "Reset %d results in %@.".localized,
                        clearedCount,
                        assessment.title
                    )
                }
            }
        }
    }

    func applyBulkStatus(_ status: AssessmentResultStatus, to assessment: Assessment, onlyPending: Bool) {
        var updatedCount = 0

        for student in studentsInThisUnit {
            let result = assessment.ensureCanonicalResult(for: student, context: context)
            if onlyPending && result.isResolved {
                continue
            }
            guard result.status != status else { continue }
            result.applyStatus(status)
            updatedCount += 1
        }

        guard updatedCount > 0 else {
            bulkActionMessage = "All students already had that status.".localized
            return
        }

        Task {
            let saveResult = await SaveCoordinator.perform(
                context: context,
                reason: "Apply bulk assessment status"
            )
            if saveResult.didSave {
                await MainActor.run {
                    bulkActionMessage = String(
                        format: "Updated %d students to %@ in %@.".localized,
                        updatedCount,
                        localizedStatusLabel(status),
                        assessment.title
                    )
                }
            }
        }
    }

    func synchronizeBulkAssessmentSelection() {
        guard !assessments.isEmpty else {
            selectedBulkAssessmentID = nil
            return
        }

        if let selectedBulkAssessmentID,
           assessments.contains(where: { $0.id == selectedBulkAssessmentID }) {
            return
        }

        selectedBulkAssessmentID = assessments.first?.id
    }

    func preferredAssessmentForQuickEntry(student: Student) -> Assessment? {
        guard !assessments.isEmpty else { return nil }

        if let firstPending = assessments.first(where: { assessment in
            !(findResult(student: student, assessment: assessment)?.isResolved ?? false)
        }) {
            return firstPending
        }

        return assessments.first
    }
    
    func displayText(for result: StudentResult?, assessment: Assessment) -> String {
        guard let result else { return "—" }
        switch result.status {
        case .ungraded:
            return "—"
        case .scored:
            let scoreText = formatScore(result.score)
            if assessment.safeMaxScore == Assessment.defaultMaxScore {
                return scoreText
            }
            return "\(scoreText)/\(formatScore(assessment.safeMaxScore))"
        case .absent:
            return "Absent".localized
        case .excused:
            return "Excused".localized
        }
    }
    
    func gradeColor(_ score: Double, assessment: Assessment) -> Color {
        AssessmentPercentMetrics.color(for: assessment.scorePercent(score))
    }
    
    func gradeCellBackground(for result: StudentResult?, assessment: Assessment) -> Color {
        guard let result else {
            return AssessmentPercentMetrics.tintColor(for: nil)
        }
        switch result.status {
        case .ungraded:
            return AssessmentPercentMetrics.tintColor(for: nil)
        case .scored:
            return AssessmentPercentMetrics.tintColor(for: assessment.scorePercent(result.score))
        case .absent:
            return Color.orange.opacity(0.10)
        case .excused:
            return Color.purple.opacity(0.10)
        }
    }

    func gradeForegroundColor(for result: StudentResult?, assessment: Assessment) -> Color {
        guard let result else { return .secondary }
        switch result.status {
        case .ungraded:
            return .secondary
        case .scored:
            return gradeColor(result.score, assessment: assessment)
        case .absent:
            return .orange
        case .excused:
            return .purple
        }
    }

    func localizedStatusLabel(_ status: AssessmentResultStatus) -> String {
        switch status {
        case .ungraded:
            return "Ungraded".localized
        case .scored:
            return "Scored".localized
        case .absent:
            return "Absent".localized
        case .excused:
            return "Excused".localized
        }
    }

    func formatScore(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
    
    var unitAveragePercent: Double {
        let allResults = assessments.flatMap { assessment in
            studentsInThisUnit.compactMap { student in
                assessment.canonicalResult(for: student)
            }
        }
        return allResults.averagePercent
    }

    func ensureResultsExist() {
        let students = studentsInThisUnit
        guard !students.isEmpty else { return }

        for assessment in assessments {
            _ = assessment.collapseDuplicateResults(context: context)
            for student in students {
                _ = assessment.ensureCanonicalResult(for: student, context: context)
            }
        }

        if context.hasChanges {
            _ = SaveCoordinator.saveResult(
                context: context,
                reason: "Normalize unit gradebook results"
            )
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

    func exportCSV() {
        guard !studentsInThisUnit.isEmpty, !assessments.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        guard let url = GradebookExportUtility.exportUnitGradebookCSV(
            unit: unit,
            students: studentsInThisUnit,
            assessments: assessments
        ) else {
            showingExportFailedAlert = true
            return
        }

        exportURL = url
    }
}

private struct BulkScoreSheet: View {
    @Environment(\.dismiss) private var dismiss

    let assessmentTitle: String
    let maxScore: Double
    let onlyUngraded: Bool
    let onApply: (Double) -> Void

    @State private var scoreText = ""

    private var parsedScore: Double? {
        let cleaned = scoreText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        guard let value = Double(cleaned), value.isFinite, value >= 0 else {
            return nil
        }
        return min(value, maxScore)
    }

    private var actionTitle: String {
        onlyUngraded ? "Fill Ungraded".localized : "Fill All".localized
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(assessmentTitle)
                        .font(.headline)
                    Text(
                        onlyUngraded
                            ? "Apply the same score to every pending student in this assessment.".localized
                            : "Apply the same score to every student in this assessment.".localized
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.green.opacity(0.12),
                    tint: .green
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Score".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    SelectAllCommitTextField(
                        placeholder: "0",
                        text: $scoreText,
                        autoFocus: true,
                        onCommit: applyAndDismiss
                    )
                    .frame(height: 22)
                    .padding(.horizontal, 14)
                    .frame(width: 120, height: 52)
                    .appFieldStyle(tint: parsedScore == nil ? .red : .green, isInvalid: parsedScore == nil)

                    Text(String(format: "Maximum score: %@".localized, formatScore(maxScore)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.green.opacity(0.10),
                    tint: .green
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    quickButton("0%", value: 0)
                    quickButton("50%", value: maxScore * 0.5)
                    quickButton("70%", value: maxScore * 0.7)
                    quickButton("100%", value: maxScore)
                }
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .appSheetBackground(tint: .green)
            .navigationTitle(actionTitle)
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
                    Button("Apply".localized) {
                        applyAndDismiss()
                    }
                    .disabled(parsedScore == nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    private func quickButton(_ label: String, value: Double) -> some View {
        Button {
            scoreText = formatScore(value)
        } label: {
            Text(label.localized)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppChrome.elevatedBackground)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyAndDismiss() {
        guard let parsedScore else { return }
        onApply(parsedScore)
        dismiss()
    }

    private func formatScore(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
