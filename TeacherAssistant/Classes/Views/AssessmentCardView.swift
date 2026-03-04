import SwiftUI

struct AssessmentCardView: View {
    let assessment: Assessment
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(assessment.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !assessment.details.isEmpty {
                        Text(assessment.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.red)
                        .padding(7)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Delete assessment"))
            }
            
            Divider()
            
            // Statistics
            HStack(spacing: 16) {
                statsCard(stackAlignment: .leading, frameAlignment: .leading) {
                    Text("Average")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f", assessmentAverage))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(averageColor(assessmentAverage))

                    Text(String(format: "%.0f%%", assessmentAveragePercent))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                let gradedCount = assessment.results.filter(\.isScored).count
                let totalCount = assessment.results.count

                statsCard(stackAlignment: .trailing, frameAlignment: .trailing) {
                    Text("Grades")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("\(gradedCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(gradedCount == totalCount ? .green : .orange)

                        Text("/ \(totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress bar
            if !assessment.results.isEmpty {
                let gradedCount = assessment.results.filter(\.isScored).count
                let totalCount = assessment.results.count
                let progress = totalCount > 0 ? Double(gradedCount) / Double(totalCount) : 0
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppChrome.elevatedBackground)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(progress))
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            borderColor: averageColor(assessmentAverage).opacity(0.16),
            tint: averageColor(assessmentAverage)
        )
    }
    
    // MARK: - Helpers
    
    var assessmentAverage: Double {
        assessment.results.averageScore
    }

    var assessmentAveragePercent: Double {
        assessment.results.averagePercent
    }
    
    func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
    
    func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .blue }
        if progress >= 0.4 { return .orange }
        return .red
    }

    func statsCard<Content: View>(
        stackAlignment: HorizontalAlignment,
        frameAlignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: stackAlignment, spacing: 4, content: content)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
    }
}
