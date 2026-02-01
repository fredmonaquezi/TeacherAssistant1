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
                        .font(.body)
                        .foregroundColor(.red)
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
                    Label("\(unit.assessments.count)", systemImage: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let totalResults = unit.assessments.flatMap { $0.results }.count
                    Label("\(totalResults)", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        
                        let completedCount = unit.assessments.flatMap { $0.results }.filter { $0.score > 0 }.count
                        let totalCount = unit.assessments.flatMap { $0.results }.count
                        
                        if totalCount > 0 {
                            Text("\(completedCount)/\(totalCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    GeometryReader { geometry in
                        let completedCount = unit.assessments.flatMap { $0.results }.filter { $0.score > 0 }.count
                        let totalCount = unit.assessments.flatMap { $0.results }.count
                        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
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
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
