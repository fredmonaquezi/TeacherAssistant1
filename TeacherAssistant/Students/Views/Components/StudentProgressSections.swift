import SwiftUI

struct StudentProgressHeroHeaderSectionView: View, Equatable {
    let studentName: String
    let overallAverageScore: Double
    let scoredResultsCount: Int
    let attendancePercentage: Double

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text(studentName.prefix(1).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(studentName)
                .font(.title)
                .fontWeight(.bold)

            HStack(spacing: 24) {
                quickStat(
                    value: String(format: "%.1f", overallAverageScore),
                    label: "Average".localized,
                    color: averageColor(overallAverageScore)
                )

                Divider()
                    .frame(height: 40)

                quickStat(
                    value: "\(scoredResultsCount)",
                    label: "Assessments".localized,
                    color: .blue
                )

                Divider()
                    .frame(height: 40)

                quickStat(
                    value: String(format: "%.0f%%", attendancePercentage),
                    label: "Attendance".localized,
                    color: .green
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func quickStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
}

struct StudentProgressTabPickerSectionView: View {
    let selectedTab: StudentProgressView.ProgressTab
    let actionCoordinator: StudentProgressActionCoordinator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StudentProgressView.ProgressTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(0.05))
    }

    private func tabButton(_ tab: StudentProgressView.ProgressTab) -> some View {
        Button {
            actionCoordinator.selectTab(tab)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.subheadline)

                Text(tab.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedTab == tab ? tab.color : Color.gray.opacity(0.1))
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
