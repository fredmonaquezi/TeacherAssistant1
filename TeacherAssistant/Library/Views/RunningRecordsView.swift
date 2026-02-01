import SwiftUI
import SwiftData

struct RunningRecordsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allStudents: [Student]
    @Query(sort: \RunningRecord.date, order: .reverse) private var allRunningRecords: [RunningRecord]
    
    @State private var selectedStudent: Student?
    @State private var showingAddRecord = false
    @State private var searchText = ""
    @State private var filterLevel: ReadingLevel?
    
    var filteredRecords: [RunningRecord] {
        var records = allRunningRecords
        
        if let student = selectedStudent {
            records = records.filter { $0.student?.id == student.id }
        }
        
        if let level = filterLevel {
            records = records.filter { $0.readingLevel == level }
        }
        
        if !searchText.isEmpty {
            records = records.filter {
                $0.student?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.textTitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return records
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                headerStatsView
                
                Divider()
                
                // Filters
                filtersView
                
                // Records List
                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRecords, id: \.id) { record in
                                RunningRecordCard(record: record)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Running Records")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRecord = true
                    } label: {
                        Label("New Record", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddRunningRecordView()
            }
        }
    }
    
    // MARK: - Header Stats
    
    var headerStatsView: some View {
        HStack(spacing: 16) {
            statBox(
                title: "Total Records",
                value: "\(allRunningRecords.count)",
                icon: "doc.text.fill",
                color: .blue
            )
            
            statBox(
                title: "Students Assessed",
                value: "\(uniqueStudentsCount)",
                icon: "person.3.fill",
                color: .purple
            )
            
            statBox(
                title: "Avg. Accuracy",
                value: String(format: "%.1f%%", averageAccuracy),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    var uniqueStudentsCount: Int {
        Set(allRunningRecords.compactMap { $0.student?.id }).count
    }
    
    var averageAccuracy: Double {
        guard !allRunningRecords.isEmpty else { return 0 }
        let total = allRunningRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(allRunningRecords.count)
    }
    
    // MARK: - Filters
    
    var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Student filter
                Menu {
                    Button("All Students") {
                        selectedStudent = nil
                    }
                    
                    Divider()
                    
                    ForEach(allStudents.sorted(by: { $0.name < $1.name }), id: \.id) { student in
                        Button(student.name) {
                            selectedStudent = student
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                        Text(selectedStudent?.name ?? "All Students")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedStudent != nil ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .foregroundColor(selectedStudent != nil ? .blue : .primary)
                    .cornerRadius(8)
                }
                
                // Level filters
                ForEach(ReadingLevel.allCases, id: \.self) { level in
                    Button {
                        if filterLevel == level {
                            filterLevel = nil
                        } else {
                            filterLevel = level
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: level.systemImage)
                            Text(levelShortName(level))
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(filterLevel == level ? levelColor(level).opacity(0.15) : Color.gray.opacity(0.1))
                        .foregroundColor(filterLevel == level ? levelColor(level) : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    func levelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
        }
    }
    
    func levelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }
    
    // MARK: - Empty State
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Running Records Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start assessing your students' reading by creating your first running record")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddRecord = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create First Record")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Running Record Card

struct RunningRecordCard: View {
    let record: RunningRecord
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(spacing: 16) {
                // Header with student and date
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let student = record.student {
                            Text(student.name)
                                .font(.headline)
                        } else {
                            Text("Unknown Student")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(record.textTitle.isEmpty ? "Untitled Text" : record.textTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(record.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(record.date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats
                HStack(spacing: 12) {
                    miniStat(title: "Accuracy", value: String(format: "%.1f%%", record.accuracy), color: levelColor(record.readingLevel))
                    miniStat(title: "Errors", value: "\(record.errors)", color: .red)
                    miniStat(title: "SC", value: "\(record.selfCorrections)", color: .blue)
                    miniStat(title: "Words", value: "\(record.totalWords)", color: .purple)
                }
                
                // Reading Level Badge
                HStack {
                    Image(systemName: record.readingLevel.systemImage)
                    Text(levelShortName(record.readingLevel))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(levelColor(record.readingLevel))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(levelColor(record.readingLevel).opacity(0.15))
                .cornerRadius(8)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            RunningRecordDetailView(record: record)
        }
    }
    
    func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
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
    
    func levelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
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
