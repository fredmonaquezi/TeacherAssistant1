import SwiftUI
import Charts

struct StudentProgressOverviewTabView: View, Equatable {
    let overallAverageScore: Double
    let attendancePercentage: Double
    let runningRecordCount: Int
    let developmentAreaCount: Int
    let subjectOverviewViewModels: [StudentProgressSubjectOverviewViewModel]
    let recentActivityViewModels: [StudentProgressRecentActivityViewModel]

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                summaryCard(
                    title: "Academic Average".localized,
                    value: String(format: "%.1f", overallAverageScore),
                    icon: "chart.bar.fill",
                    color: .purple
                )

                summaryCard(
                    title: "Attendance Rate".localized,
                    value: String(format: "%.0f%%", attendancePercentage),
                    icon: "calendar",
                    color: .green
                )
            }

            HStack(spacing: 16) {
                summaryCard(
                    title: "Running Records".localized,
                    value: "\(runningRecordCount)",
                    icon: "book.fill",
                    color: .orange
                )

                summaryCard(
                    title: "Development Areas".localized,
                    value: "\(developmentAreaCount)",
                    icon: "star.fill",
                    color: .pink
                )
            }

            sectionHeader(title: "Subject Performance".localized, icon: "graduationcap.fill", color: .purple)

            if subjectOverviewViewModels.isEmpty {
                emptyState(icon: "book.closed", message: "No academic results yet")
            } else {
                ForEach(subjectOverviewViewModels) { subject in
                    subjectOverviewCard(subject: subject)
                }
            }

            sectionHeader(title: "Recent Activity".localized, icon: "clock.fill", color: .blue)

            if recentActivityViewModels.isEmpty {
                emptyState(icon: "tray", message: "No recent activity")
            } else {
                VStack(spacing: 12) {
                    ForEach(recentActivityViewModels) { result in
                        activityRow(result: result)
                    }
                }
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
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
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }

    private func subjectOverviewCard(subject: StudentProgressSubjectOverviewViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.subjectName)
                    .font(.headline)

                Text("\(subject.assessmentCount) \(subject.assessmentCount == 1 ? "assessment".localized : "assessments".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f", subject.averageScore))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(averageColor(subject.averageScore))
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func activityRow(result: StudentProgressRecentActivityViewModel) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.purple)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(result.assessmentTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let subjectName = result.subjectName {
                    Text(subjectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(String(format: "%.1f", result.score))
                .font(.headline)
                .foregroundColor(averageColor(result.score))
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

struct StudentProgressAcademicsTabView: View, Equatable {
    let overallAverageScore: Double
    let scoredResultsCount: Int
    let subjectSectionViewModels: [StudentProgressSubjectSectionViewModel]

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                statCard(
                    title: "Overall Average",
                    value: String(format: "%.1f", overallAverageScore),
                    icon: "chart.bar.fill",
                    color: averageColor(overallAverageScore)
                )

                statCard(
                    title: "Total Assessments",
                    value: "\(scoredResultsCount)",
                    icon: "list.bullet.clipboard",
                    color: .blue
                )
            }

            sectionHeader(title: "Performance by Subject", icon: "graduationcap.fill", color: .purple)

            if subjectSectionViewModels.isEmpty {
                emptyState(icon: "book.closed", message: "No academic results yet")
            } else {
                ForEach(subjectSectionViewModels) { subject in
                    subjectSection(subject: subject)
                }
            }
        }
    }

    private func subjectSection(subject: StudentProgressSubjectSectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.subjectName)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("\(subject.assessmentCount) assessments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(String(format: "%.1f", subject.averageScore))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(averageColor(subject.averageScore))
            }

            if !subject.units.isEmpty {
                Divider()

                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                ForEach(subject.units) { unitSummary in
                    unitRow(unitSummary: unitSummary)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func unitRow(unitSummary: StudentProgressUnitRowViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(unitSummary.unitName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(unitSummary.criteriaCount) criteria")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f", unitSummary.averageScore))
                .font(.headline)
                .foregroundColor(averageColor(unitSummary.averageScore))
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

struct StudentProgressAttendanceTabView: View, Equatable {
    let totalSessions: Int
    let presentCount: Int
    let absentCount: Int
    let lateCount: Int
    let attendancePercentage: Double

    var body: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Attendance Summary", icon: "calendar", color: .green)

            if totalSessions == 0 {
                emptyState(icon: "calendar.badge.exclamationmark", message: "No attendance records yet")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    attendanceStatCard(title: "Total Sessions", value: "\(totalSessions)", color: .blue)
                    attendanceStatCard(title: "Present", value: "\(presentCount)", color: .green)
                    attendanceStatCard(title: "Absent", value: "\(absentCount)", color: .red)
                    attendanceStatCard(title: "Late", value: "\(lateCount)", color: .orange)
                }

                VStack(spacing: 12) {
                    Text("Attendance Rate")
                        .font(.headline)

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: attendancePercentage / 100)
                            .stroke(
                                attendancePercentage >= 90 ? Color.green : attendancePercentage >= 75 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: attendancePercentage)

                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", attendancePercentage))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(attendancePercentage >= 90 ? .green : attendancePercentage >= 75 ? .orange : .red)

                            Text("Present")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)

                sectionHeader(title: "Breakdown", icon: "chart.pie.fill", color: .blue)

                VStack(spacing: 12) {
                    attendanceBreakdownRow(label: "Present", count: presentCount, total: totalSessions, color: .green)
                    attendanceBreakdownRow(label: "Absent", count: absentCount, total: totalSessions, color: .red)
                    attendanceBreakdownRow(label: "Late", count: lateCount, total: totalSessions, color: .orange)
                }
            }
        }
    }

    private func attendanceStatCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
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
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func attendanceBreakdownRow(label: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(count) (\(Int(percentage * 100))%)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(), value: percentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

struct StudentProgressRunningRecordsTabView: View, Equatable {
    let runningRecordCount: Int
    let averageAccuracy: Double
    let latestRunningRecordViewModel: StudentProgressRunningRecordViewModel?
    let runningRecordViewModelsDescending: [StudentProgressRunningRecordViewModel]
    let runningRecordViewModelsAscending: [StudentProgressRunningRecordViewModel]

    var body: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Running Records", icon: "book.fill", color: .orange)

            if runningRecordCount == 0 {
                emptyState(icon: "book.closed", message: "No running records yet")
            } else {
                HStack(spacing: 16) {
                    statCard(
                        title: "Total Records",
                        value: "\(runningRecordCount)",
                        icon: "doc.text.fill",
                        color: .orange
                    )

                    statCard(
                        title: "Avg. Accuracy",
                        value: String(format: "%.1f%%", averageAccuracy),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }

                if let latestRecord = latestRunningRecordViewModel {
                    VStack(spacing: 12) {
                        Text("Current Reading Level")
                            .font(.headline)

                        HStack(spacing: 16) {
                            Image(systemName: latestRecord.readingLevel.systemImage)
                                .font(.system(size: 40))
                                .foregroundColor(readingLevelColor(latestRecord.readingLevel))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(readingLevelName(latestRecord.readingLevel))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(readingLevelColor(latestRecord.readingLevel))

                                Text(latestRecord.date.appDateString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(readingLevelColor(latestRecord.readingLevel).opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                if runningRecordCount >= 2 {
                    sectionHeader(title: "Progress Over Time", icon: "chart.line.uptrend.xyaxis", color: .blue)
                    runningRecordsChart
                }

                sectionHeader(title: "All Records", icon: "list.bullet", color: .purple)

                ForEach(runningRecordViewModelsDescending) { record in
                    StudentProgressRunningRecordCardView(model: record)
                }
            }
        }
    }

    private var runningRecordsChart: some View {
        VStack(spacing: 8) {
            Chart {
                ForEach(runningRecordViewModelsAscending, id: \.id) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Accuracy", record.accuracy)
                    )
                    .foregroundStyle(.orange)
                    .symbol(.circle)
                    .symbolSize(60)

                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Accuracy", record.accuracy)
                    )
                    .foregroundStyle(.orange)
                }

                RuleMark(y: .value("Independent", 95))
                    .foregroundStyle(.green.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))

                RuleMark(y: .value("Instructional", 90))
                    .foregroundStyle(.orange.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
            }
            .chartYScale(domain: 70...100)
            .frame(height: 200)
            .padding()
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)

            HStack(spacing: 16) {
                legendItem(color: .green, text: "95%+ Independent")
                legendItem(color: .orange, text: "90%+ Instructional")
                legendItem(color: .red, text: "<90% Frustration")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.5))
                .frame(width: 20, height: 3)

            Text(text)
        }
    }

    private func readingLevelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }

    private func readingLevelName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

struct StudentProgressDevelopmentTabView: View, Equatable {
    let latestTrackedCount: Int
    let totalUpdatesCount: Int
    let developmentCategoryViewModels: [StudentProgressDevelopmentCategoryViewModel]

    @EnvironmentObject private var languageManager: LanguageManager

    static func == (lhs: StudentProgressDevelopmentTabView, rhs: StudentProgressDevelopmentTabView) -> Bool {
        lhs.latestTrackedCount == rhs.latestTrackedCount
            && lhs.totalUpdatesCount == rhs.totalUpdatesCount
            && lhs.developmentCategoryViewModels == rhs.developmentCategoryViewModels
    }

    var body: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Development Tracking".localized, icon: "star.fill", color: .pink)

            if totalUpdatesCount == 0 {
                emptyState(icon: "star.circle", message: "No development tracking yet".localized)
            } else {
                HStack(spacing: 16) {
                    statCard(
                        title: "Areas Tracked",
                        value: "\(latestTrackedCount)",
                        icon: "star.fill",
                        color: .pink
                    )

                    statCard(
                        title: "Total Updates",
                        value: "\(totalUpdatesCount)",
                        icon: "arrow.clockwise",
                        color: .blue
                    )
                }

                ForEach(developmentCategoryViewModels) { category in
                    developmentCategorySection(category: category)
                }
            }
        }
    }

    private func developmentCategorySection(category: StudentProgressDevelopmentCategoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayRubricText(category.category))
                .font(.headline)
                .foregroundColor(.pink)

            ForEach(category.scores) { score in
                developmentScoreCard(score)
            }
        }
        .padding()
        .background(Color.pink.opacity(0.05))
        .cornerRadius(12)
    }

    private func developmentScoreCard(_ score: StudentProgressDevelopmentScoreViewModel) -> some View {
        let color = ratingColor(for: score.rating)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayRubricText(score.criterionName))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= score.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= score.rating ? color : .gray.opacity(0.3))
                    }
                }
            }

            Text(score.ratingLabel)
                .font(.caption)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .cornerRadius(6)

            if !score.notes.isEmpty {
                Divider()

                Text(score.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(score.date.appDateString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func displayRubricText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = languageManager.localized(trimmed)
        if localized != trimmed { return localized }
        return RubricLocalization.localized(trimmed, languageCode: languageManager.currentLanguage.rawValue)
    }

    private func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 5: return .green
        case 4: return .blue
        case 3: return .orange
        case 2: return .yellow
        case 1: return .red
        default: return .gray
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
