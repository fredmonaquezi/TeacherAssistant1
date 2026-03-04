import SwiftUI

struct UnitCardView: View {
    let unit: Unit
    let onDelete: () -> Void
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(unit.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("\(unit.assessments.count) \(unit.assessments.count == 1 ? languageManager.localized("assessment") : languageManager.localized("assessments"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Delete unit"))
            }
            
            Divider()
            
            // Statistics
            HStack(spacing: 20) {
                // Unit Average
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageManager.localized("Average"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", unitAverage))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(averageColor(unitAverage))
                }
                
                Spacer()
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 4) {
                    statPill(icon: "doc.text.fill", value: "\(unit.assessments.count)")

                    let totalResults = unit.assessments.flatMap { $0.results }.count
                    statPill(icon: "person.fill", value: "\(totalResults)")
                }
            }
            
            // Progress indicator
            if !unit.assessments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(languageManager.localized("Progress"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let completedCount = unit.assessments.flatMap { $0.results }.filter(\.isScored).count
                        let totalCount = unit.assessments.flatMap { $0.results }.count
                        
                        if totalCount > 0 {
                            Text("\(completedCount)/\(totalCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    GeometryReader { geometry in
                        let completedCount = unit.assessments.flatMap { $0.results }.filter(\.isScored).count
                        let totalCount = unit.assessments.flatMap { $0.results }.count
                        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
                        
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            borderColor: averageColor(unitAverage).opacity(0.16),
            tint: averageColor(unitAverage)
        )
    }
    
    // MARK: - Helpers
    
    var unitAverage: Double {
        let allResults = unit.assessments.flatMap { $0.results }
        return allResults.averageScore
    }
    
    func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
    
    func progressColor(_ progress: Double) -> Color {
        if progress >= 0.8 { return .green }
        if progress >= 0.5 { return .blue }
        if progress >= 0.3 { return .orange }
        return .red
    }
    
    func statPill(icon: String, value: String) -> some View {
        Label(value, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppChrome.elevatedBackground)
            )
    }
}
