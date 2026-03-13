import SwiftUI
import SwiftData

struct AssessmentsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.appMotionContext) private var motion

    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    @Query private var assessments: [Assessment]

    @State private var selectedClassID: PersistentIdentifier?
    @State private var selectedStatus: AssessmentStatusFilter = .all
    @State private var searchText = ""

    enum AssessmentStatusFilter: String, CaseIterable, Identifiable {
        case all
        case ungraded
        case upcoming
        case graded
        case absent
        case excused

        var id: String { rawValue }
    }

    private var orderedClasses: [SchoolClass] {
        classes.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var orderedAssessments: [Assessment] {
        assessments.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var filteredAssessments: [Assessment] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return orderedAssessments.filter { assessment in
            if let selectedClassID {
                guard assessment.unit?.subject?.schoolClass?.id == selectedClassID else {
                    return false
                }
            }

            switch selectedStatus {
            case .all:
                break
            case .ungraded:
                guard gradingProgress(for: assessment).remainingCount > 0 else { return false }
            case .upcoming:
                guard assessment.date >= Calendar.current.startOfDay(for: Date()) else { return false }
            case .graded:
                guard gradingProgress(for: assessment).resolvedCount > 0 else { return false }
            case .absent:
                guard gradingProgress(for: assessment).absentCount > 0 else { return false }
            case .excused:
                guard gradingProgress(for: assessment).excusedCount > 0 else { return false }
            }

            guard !trimmedSearch.isEmpty else { return true }
            let haystacks = [
                assessment.title,
                assessment.details,
                assessment.unit?.name ?? "",
                assessment.unit?.subject?.name ?? "",
                assessment.unit?.subject?.schoolClass?.name ?? ""
            ]
            return haystacks.contains { value in
                value.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }
    }

    private var upcomingAssessments: [Assessment] {
        filteredAssessments
            .filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.date < $1.date }
    }

    private var ungradedAssessments: [Assessment] {
        filteredAssessments
            .filter { gradingProgress(for: $0).remainingCount > 0 }
            .sorted { lhs, rhs in
                let lhsRemaining = gradingProgress(for: lhs).remainingCount
                let rhsRemaining = gradingProgress(for: rhs).remainingCount
                if lhsRemaining != rhsRemaining {
                    return lhsRemaining > rhsRemaining
                }
                return lhs.date < rhs.date
            }
    }

    private var classSummaries: [ClassAssessmentSummary] {
        orderedClasses.compactMap { schoolClass in
            let classAssessments = filteredAssessments.filter { $0.unit?.subject?.schoolClass?.id == schoolClass.id }
            guard !classAssessments.isEmpty else { return nil }

            let classResults = classAssessments.flatMap(\.results).filter(\.isScored)
            let pendingCount = classAssessments.reduce(0) { partialResult, assessment in
                partialResult + gradingProgress(for: assessment).remainingCount
            }
            let absentCount = classAssessments.reduce(0) { partialResult, assessment in
                partialResult + gradingProgress(for: assessment).absentCount
            }
            let excusedCount = classAssessments.reduce(0) { partialResult, assessment in
                partialResult + gradingProgress(for: assessment).excusedCount
            }

            return ClassAssessmentSummary(
                schoolClass: schoolClass,
                assessmentCount: classAssessments.count,
                pendingGrades: pendingCount,
                absentResults: absentCount,
                excusedResults: excusedCount,
                scoredResultsCount: classResults.count,
                averagePercent: classResults.averagePercent,
                nextAssessmentDate: classAssessments
                    .map(\.date)
                    .filter { $0 >= Calendar.current.startOfDay(for: Date()) }
                    .sorted()
                    .first
            )
        }
        .filter { summary in
            selectedClassID == nil || summary.schoolClass.id == selectedClassID
        }
    }

    private var overviewMetrics: AssessmentOverviewMetrics {
        let gradedResults = filteredAssessments.flatMap(\.results).filter(\.isScored)
        let pendingGrades = filteredAssessments.reduce(0) { partialResult, assessment in
            partialResult + gradingProgress(for: assessment).remainingCount
        }
        let absentResults = filteredAssessments.reduce(0) { partialResult, assessment in
            partialResult + gradingProgress(for: assessment).absentCount
        }
        let excusedResults = filteredAssessments.reduce(0) { partialResult, assessment in
            partialResult + gradingProgress(for: assessment).excusedCount
        }

        return AssessmentOverviewMetrics(
            totalAssessments: filteredAssessments.count,
            upcomingCount: upcomingAssessments.count,
            pendingGrades: pendingGrades,
            absentResults: absentResults,
            excusedResults: excusedResults,
            scoredResultsCount: gradedResults.count,
            averagePercent: gradedResults.averagePercent
        )
    }

    var body: some View {
        #if os(macOS)
        content
        #else
        NavigationStack {
            content
        }
        #endif
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                heroCard
                    .appMotionReveal(index: 0)
                filtersCard
                    .appMotionReveal(index: 1)
                metricsSection
                    .appMotionReveal(index: 2)
                focusSection
                    .appMotionReveal(index: 3)
                classesSection
                    .appMotionReveal(index: 4)
                allAssessmentsSection
                    .appMotionReveal(index: 5)
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle("Assessments".localized)
        #endif
        .animation(motion.animation(.standard), value: selectedClassID)
        .animation(motion.animation(.standard), value: selectedStatus)
        .animation(motion.animation(.standard), value: searchText)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 34))
                    .foregroundColor(.green)
                    .frame(width: 58, height: 58)
                    .appCardStyle(
                        cornerRadius: 12,
                        borderColor: Color.green.opacity(0.18),
                        shadowOpacity: 0.03,
                        shadowRadius: 5,
                        shadowY: 2,
                        tint: .green
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Assessment Hub".localized)
                        .font(.title3.weight(.semibold))

                    Text("Track upcoming assessments, grading backlog, and class performance from one place.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.green.opacity(0.12),
            tint: .green
        )
        .padding(.horizontal)
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filters".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
                if selectedClassID != nil || selectedStatus != .all || !searchText.isEmpty {
                    Button("Clear".localized) {
                        selectedClassID = nil
                        selectedStatus = .all
                        searchText = ""
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Class".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(
                            title: "All Classes".localized,
                            isSelected: selectedClassID == nil
                        ) {
                            selectedClassID = nil
                        }

                        ForEach(orderedClasses, id: \.id) { schoolClass in
                            filterChip(
                                title: schoolClass.name,
                                isSelected: selectedClassID == schoolClass.id
                            ) {
                                selectedClassID = schoolClass.id
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AssessmentStatusFilter.allCases) { filter in
                            filterChip(
                                title: localizedStatusTitle(filter),
                                isSelected: selectedStatus == filter
                            ) {
                                selectedStatus = filter
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Search".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Assessment, unit, subject, or class".localized, text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.green.opacity(0.1),
            tint: .green
        )
        .padding(.horizontal)
    }

    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)], spacing: 16) {
            metricsCard(
                title: "Assessments".localized,
                value: "\(overviewMetrics.totalAssessments)",
                subtitle: "In current view".localized,
                icon: "doc.text.fill",
                color: .blue
            )
            .appMotionReveal(index: 0)

            metricsCard(
                title: "Pending Grades".localized,
                value: "\(overviewMetrics.pendingGrades)",
                subtitle: "Students still pending".localized,
                icon: "tray.full.fill",
                color: overviewMetrics.pendingGrades > 0 ? .orange : .green
            )
            .appMotionReveal(index: 1)

            metricsCard(
                title: "Upcoming".localized,
                value: "\(overviewMetrics.upcomingCount)",
                subtitle: "Scheduled from today".localized,
                icon: "calendar.badge.clock",
                color: .purple
            )
            .appMotionReveal(index: 2)

            metricsCard(
                title: "Absent".localized,
                value: "\(overviewMetrics.absentResults)",
                subtitle: "Marked absent".localized,
                icon: "person.crop.circle.badge.xmark",
                color: overviewMetrics.absentResults > 0 ? .red : .gray
            )
            .appMotionReveal(index: 3)

            metricsCard(
                title: "Excused".localized,
                value: "\(overviewMetrics.excusedResults)",
                subtitle: "Excused results".localized,
                icon: "checkmark.seal.fill",
                color: overviewMetrics.excusedResults > 0 ? .teal : .gray
            )
            .appMotionReveal(index: 4)

            metricsCard(
                title: "Average".localized,
                value: overviewMetrics.scoredResultsCount > 0 ? String(format: "%.1f%%", overviewMetrics.averagePercent) : "—",
                subtitle: "Across graded results".localized,
                icon: "chart.bar.fill",
                color: overviewMetrics.scoredResultsCount > 0 ? AssessmentPercentMetrics.color(for: overviewMetrics.averagePercent) : .gray
            )
            .appMotionReveal(index: 5)
        }
        .padding(.horizontal)
    }

    private func metricsCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText())

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: color.opacity(0.14),
            tint: color
        )
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus".localized)
                .font(AppTypography.sectionTitle)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)], spacing: 16) {
                focusCard(
                    title: "Needs Grading".localized,
                    subtitle: "Assessments with unresolved student results".localized,
                    icon: "square.and.pencil",
                    color: .orange,
                    assessments: Array(ungradedAssessments.prefix(4))
                )

                focusCard(
                    title: "Coming Up".localized,
                    subtitle: "Next scheduled assessments".localized,
                    icon: "calendar",
                    color: .blue,
                    assessments: Array(upcomingAssessments.prefix(4))
                )
            }
            .padding(.horizontal)
        }
    }

    private func focusCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        assessments: [Assessment]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if assessments.isEmpty {
                Text("Nothing to show for the current filters.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(assessments, id: \.persistentModelID) { assessment in
                        NavigationLink {
                            AssessmentDetailView(assessment: assessment)
                        } label: {
                            AssessmentFocusRow(
                                assessment: assessment,
                                progress: gradingProgress(for: assessment),
                                className: assessment.unit?.subject?.schoolClass?.name ?? "",
                                unitName: assessment.unit?.name ?? ""
                            )
                        }
                        .buttonStyle(AppPressableButtonStyle())
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: color.opacity(0.12),
            tint: color
        )
    }

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Classes".localized)
                .font(AppTypography.sectionTitle)
                .padding(.horizontal)

            if classSummaries.isEmpty {
                emptySectionCard(
                    icon: "building.2",
                    title: "No class assessment data yet".localized,
                    message: "Create assessments inside a unit to start seeing class summaries here.".localized,
                    tint: .blue
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16) {
                    ForEach(classSummaries) { summary in
                        NavigationLink {
                            ClassOverviewView(schoolClass: summary.schoolClass)
                        } label: {
                            ClassAssessmentSummaryCard(summary: summary)
                        }
                        .buttonStyle(AppPressableButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var allAssessmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Assessments".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(filteredAssessments.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if filteredAssessments.isEmpty {
                emptySectionCard(
                    icon: "doc.text",
                    title: "No assessments found".localized,
                    message: "Adjust the filters or add assessments inside a unit to populate this view.".localized,
                    tint: .green
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAssessments, id: \.persistentModelID) { assessment in
                        NavigationLink {
                            AssessmentDetailView(assessment: assessment)
                        } label: {
                            AssessmentHubRow(
                                assessment: assessment,
                                progress: gradingProgress(for: assessment)
                            )
                        }
                        .buttonStyle(AppPressableButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(motion.animation(.standard)) {
                action()
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color.gray.opacity(0.14))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    private func emptySectionCard(icon: String, title: String, message: String, tint: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(.secondary)

            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: tint.opacity(0.1),
            tint: tint
        )
        .padding(.horizontal)
    }

    private func gradingProgress(for assessment: Assessment) -> AssessmentGradingProgress {
        let totalCount = assessment.results.count
        let resolvedCount = assessment.results.filter(\.isResolved).count
        return AssessmentGradingProgress(
            totalCount: totalCount,
            resolvedCount: resolvedCount,
            scoredCount: assessment.results.filter(\.isScored).count,
            absentCount: assessment.results.filter { $0.status == .absent }.count,
            excusedCount: assessment.results.filter { $0.status == .excused }.count
        )
    }

    private func localizedStatusTitle(_ filter: AssessmentStatusFilter) -> String {
        switch filter {
        case .all:
            return "All".localized
        case .ungraded:
            return "Needs Grading".localized
        case .upcoming:
            return "Upcoming".localized
        case .graded:
            return "Resolved".localized
        case .absent:
            return "Absent".localized
        case .excused:
            return "Excused".localized
        }
    }
}

private struct AssessmentOverviewMetrics {
    let totalAssessments: Int
    let upcomingCount: Int
    let pendingGrades: Int
    let absentResults: Int
    let excusedResults: Int
    let scoredResultsCount: Int
    let averagePercent: Double
}

private struct AssessmentGradingProgress {
    let totalCount: Int
    let resolvedCount: Int
    let scoredCount: Int
    let absentCount: Int
    let excusedCount: Int

    var remainingCount: Int {
        max(totalCount - resolvedCount, 0)
    }

    var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(resolvedCount) / Double(totalCount)
    }
}

private struct ClassAssessmentSummary: Identifiable {
    let schoolClass: SchoolClass
    let assessmentCount: Int
    let pendingGrades: Int
    let absentResults: Int
    let excusedResults: Int
    let scoredResultsCount: Int
    let averagePercent: Double
    let nextAssessmentDate: Date?

    var id: PersistentIdentifier {
        schoolClass.id
    }
}

private struct AssessmentFocusRow: View {
    let assessment: Assessment
    let progress: AssessmentGradingProgress
    let className: String
    let unitName: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(assessment.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text([className, unitName].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(assessment.date.appDateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(progress.resolvedCount)/\(progress.totalCount)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(progress.remainingCount > 0 ? .orange : .green)

                if progress.remainingCount > 0 {
                    Text(String(format: "%d left".localized, progress.remainingCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
    }
}

private struct ClassAssessmentSummaryCard: View {
    let summary: ClassAssessmentSummary

    private var averageColor: Color {
        summary.scoredResultsCount > 0 ? AssessmentPercentMetrics.color(for: summary.averagePercent) : .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.schoolClass.name)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.primary)

                    Text(summary.schoolClass.grade)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                classMetric(title: "Assessments".localized, value: "\(summary.assessmentCount)", color: .blue)
                classMetric(title: "Pending".localized, value: "\(summary.pendingGrades)", color: summary.pendingGrades > 0 ? .orange : .green)
            }

            HStack(spacing: 12) {
                classMetric(title: "Absent".localized, value: "\(summary.absentResults)", color: summary.absentResults > 0 ? .red : .secondary)
                classMetric(title: "Excused".localized, value: "\(summary.excusedResults)", color: summary.excusedResults > 0 ? .teal : .secondary)
            }

            HStack {
                Text("Average".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(summary.scoredResultsCount > 0 ? String(format: "%.1f%%", summary.averagePercent) : "—")
                    .font(.headline)
                    .foregroundColor(summary.scoredResultsCount > 0 ? averageColor : .secondary)
            }

            if let nextAssessmentDate = summary.nextAssessmentDate {
                HStack {
                    Text("Next".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(nextAssessmentDate.appDateString)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: averageColor.opacity(0.12),
            tint: averageColor
        )
    }

    private func classMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssessmentHubRow: View {
    let assessment: Assessment
    let progress: AssessmentGradingProgress

    private var averagePercent: Double {
        assessment.results.averagePercent
    }

    private var averageText: String {
        progress.scoredCount > 0 ? String(format: "%.0f%%".localized, averagePercent) : "—"
    }

    private var averageColor: Color {
        progress.scoredCount > 0 ? AssessmentPercentMetrics.color(for: averagePercent) : .gray
    }

    private var progressColor: Color {
        if progress.totalCount == 0 {
            return .gray
        }
        if progress.remainingCount == 0 {
            return .green
        }
        if progress.completionRatio >= 0.5 {
            return .orange
        }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assessment.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(contextLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(assessment.date.appDateString)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(averageText)
                        .font(.headline)
                        .foregroundColor(progress.scoredCount > 0 ? averageColor : .secondary)
                }
            }

            HStack(spacing: 16) {
                infoPill(
                    icon: "checkmark.circle.fill",
                    text: "\(progress.resolvedCount)/\(progress.totalCount) " + "resolved".localized,
                    color: progressColor
                )

                if progress.remainingCount > 0 {
                    infoPill(
                        icon: "tray.full.fill",
                        text: String(format: "%d left".localized, progress.remainingCount),
                        color: .orange
                    )
                }

                if progress.absentCount > 0 {
                    infoPill(
                        icon: "person.crop.circle.badge.xmark",
                        text: String(format: "%d absent".localized, progress.absentCount),
                        color: .red
                    )
                }

                if progress.excusedCount > 0 {
                    infoPill(
                        icon: "checkmark.seal.fill",
                        text: String(format: "%d excused".localized, progress.excusedCount),
                        color: .teal
                    )
                }

                infoPill(
                    icon: "number.circle.fill",
                    text: maxScoreText,
                    color: .blue
                )
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: averageColor.opacity(0.12),
            tint: averageColor
        )
    }

    private var contextLine: String {
        [
            assessment.unit?.subject?.schoolClass?.name,
            assessment.unit?.subject?.name,
            assessment.unit?.name
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " • ")
    }

    private var maxScoreText: String {
        let maxScore = assessment.safeMaxScore
        let formattedValue: String
        if maxScore.rounded() == maxScore {
            formattedValue = String(Int(maxScore))
        } else {
            formattedValue = String(format: "%.1f", maxScore)
        }
        return String(format: "Max %@".localized, formattedValue)
    }

    private func infoPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    AssessmentsView()
}
