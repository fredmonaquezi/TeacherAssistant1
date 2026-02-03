import SwiftUI
import Charts

struct StudentRunningRecordsSection: View {
    let student: Student
    @State private var showingAllRecords = false
    @EnvironmentObject var languageManager: LanguageManager
    
    var sortedRecords: [RunningRecord] {
        student.runningRecords.sorted { $0.date > $1.date }
    }
    
    var recentRecords: [RunningRecord] {
        Array(sortedRecords.prefix(3))
    }
    
    var averageAccuracy: Double {
        guard !student.runningRecords.isEmpty else { return 0 }
        let total = student.runningRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(student.runningRecords.count)
    }
    
    var latestLevel: ReadingLevel? {
        sortedRecords.first?.readingLevel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(languageManager.localized("Running Records"), systemImage: "doc.text.magnifyingglass")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !student.runningRecords.isEmpty {
                    Button {
                        showingAllRecords = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(languageManager.localized("View All"))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if student.runningRecords.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(languageManager.localized("No running records yet"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                // Stats
                HStack(spacing: 12) {
                    statMiniBox(
                        title: languageManager.localized("Total"),
                        value: "\(student.runningRecords.count)",
                        color: .blue
                    )
                    
                    statMiniBox(
                        title: languageManager.localized("Avg. Accuracy"),
                        value: String(format: "%.1f%%", averageAccuracy),
                        color: .green
                    )
                    
                    if let level = latestLevel {
                        statMiniBox(
                            title: languageManager.localized("Latest"),
                            value: levelShortName(level),
                            color: levelColor(level)
                        )
                    }
                }
                
                // Progress Chart
                if sortedRecords.count >= 2 {
                    progressChart
                }
                
                // Recent Records
                VStack(spacing: 8) {
                    ForEach(recentRecords, id: \.id) { record in
                        runningRecordMiniCard(record)
                    }
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingAllRecords) {
            StudentAllRunningRecordsView(student: student)
        }
    }
    
    // MARK: - Dark Mode Support
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    // MARK: - Components
    
    func statMiniBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    var progressChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageManager.localized("Progress Over Time"))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Chart {
                ForEach(sortedRecords.reversed(), id: \.id) { record in
                    LineMark(
                        x: .value(languageManager.localized("Date"), record.date),
                        y: .value(languageManager.localized("Accuracy"), record.accuracy)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    PointMark(
                        x: .value(languageManager.localized("Date"), record.date),
                        y: .value(languageManager.localized("Accuracy"), record.accuracy)
                    )
                    .foregroundStyle(.blue)
                }
                
                // Reference lines
                RuleMark(y: .value(languageManager.localized("Independent"), 95))
                    .foregroundStyle(.green.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
                
                RuleMark(y: .value(languageManager.localized("Instructional"), 90))
                    .foregroundStyle(.orange.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
            }
            .chartYScale(domain: 70...100)
            .frame(height: 120)
            .padding(8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    func runningRecordMiniCard(_ record: RunningRecord) -> some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.textTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Accuracy
            Text(String(format: "%.1f%%", record.accuracy))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(levelColor(record.readingLevel))
            
            // Level indicator
            Image(systemName: record.readingLevel.systemImage)
                .font(.caption)
                .foregroundColor(levelColor(record.readingLevel))
                .frame(width: 20, height: 20)
                .background(levelColor(record.readingLevel).opacity(0.15))
                .clipShape(Circle())
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    func levelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return languageManager.localized("Ind.")
        case .instructional: return languageManager.localized("Inst.")
        case .frustration: return languageManager.localized("Frust.")
        }
    }
    
    func levelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }
}

// MARK: - All Running Records View

struct StudentAllRunningRecordsView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    var sortedRecords: [RunningRecord] {
        student.runningRecords.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedRecords, id: \.id) { record in
                        RunningRecordCard(record: record)
                    }
                }
                .padding()
            }
            .navigationTitle(String(format: languageManager.localized("%@'s Records"), student.name))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
