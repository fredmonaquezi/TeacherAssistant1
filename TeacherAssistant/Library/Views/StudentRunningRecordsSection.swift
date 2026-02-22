import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

private enum RunningRecordDateRange: String, CaseIterable {
    case all
    case last30Days
    case last90Days

    var label: String {
        switch self {
        case .all: return "All Time"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        }
    }

    func includes(_ date: Date, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .all:
            return true
        case .last30Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= cutoff
        case .last90Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return date >= cutoff
        }
    }
}

struct StudentRunningRecordsSection: View {
    let student: Student
    @State private var showingAllRecords = false
    @State private var exportURL: URL?
    @State private var showExportConfirmation = false
    @State private var showEmptyExportAlert = false
    @State private var schoolNameInput: String = ""
    @State private var showSchoolNamePrompt = false
    @State private var filterLevel: ReadingLevel?
    @State private var dateRange: RunningRecordDateRange = .all
    @EnvironmentObject var languageManager: LanguageManager
    
    var sortedRecords: [RunningRecord] {
        student.runningRecords.sorted { $0.date > $1.date }
    }
    
    var filteredRecords: [RunningRecord] {
        sortedRecords.filter { record in
            let matchesLevel = filterLevel == nil || record.readingLevel == filterLevel
            let matchesDate = dateRange.includes(record.date)
            return matchesLevel && matchesDate
        }
    }

    var recentRecords: [RunningRecord] {
        Array(filteredRecords.prefix(3))
    }
    
    var averageAccuracy: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        let total = filteredRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(filteredRecords.count)
    }
    
    var latestLevel: ReadingLevel? {
        filteredRecords.first?.readingLevel
    }

    var hasActiveFilters: Bool {
        filterLevel != nil || dateRange != .all
    }

    var activeFiltersLabel: String {
        var parts: [String] = []
        if let filterLevel {
            parts.append(levelShortName(filterLevel))
        }
        if dateRange != .all {
            parts.append(dateRange.label.localized)
        }
        return parts.joined(separator: " • ")
    }

    var exportFilterDescription: String? {
        guard hasActiveFilters else { return nil }
        return activeFiltersLabel
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
                    HStack(spacing: 12) {
                        Menu {
                            Section(languageManager.localized("Reading Level")) {
                                Button(languageManager.localized("All Levels")) {
                                    filterLevel = nil
                                }
                                ForEach(ReadingLevel.allCases, id: \.self) { level in
                                    Button(levelShortName(level)) {
                                        filterLevel = level
                                    }
                                }
                            }

                            Section(languageManager.localized("Date Range")) {
                                ForEach(RunningRecordDateRange.allCases, id: \.self) { range in
                                    Button(range.label.localized) {
                                        dateRange = range
                                    }
                                }
                            }

                            if hasActiveFilters {
                                Section {
                                    Button(languageManager.localized("Clear Filters"), role: .destructive) {
                                        clearFilters()
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                                .foregroundColor(hasActiveFilters ? .blue : .secondary)
                        }

                        Button {
                            showSchoolNamePrompt = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }

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
            }

            if hasActiveFilters {
                HStack(spacing: 8) {
                    Text(String(format: "%@: %@", languageManager.localized("Filtered"), activeFiltersLabel))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button(languageManager.localized("Clear")) {
                        clearFilters()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
            }
            
            if student.runningRecords.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    // Icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.blue.opacity(0.6))
                    }
                    
                    VStack(spacing: 6) {
                        Text(languageManager.localized("No running records yet"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(languageManager.localized("Start tracking reading progress by adding your first running record."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            } else if filteredRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text(languageManager.localized("No records match current filters"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button(languageManager.localized("Clear Filters")) {
                        clearFilters()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Stats
                HStack(spacing: 12) {
                    statMiniBox(
                        title: hasActiveFilters ? languageManager.localized("Filtered") : languageManager.localized("Total"),
                        value: "\(filteredRecords.count)",
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
                if filteredRecords.count >= 2 {
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
        .alert(languageManager.localized("Export Running Records"), isPresented: $showSchoolNamePrompt) {
            TextField(languageManager.localized("School Name (optional)"), text: $schoolNameInput)
            Button(languageManager.localized("Cancel"), role: .cancel) {}
            Button(languageManager.localized("Export PDF")) {
                exportRunningRecordsPDF()
            }
        } message: {
            Text(languageManager.localized("Enter the school name to appear on the PDF header."))
        }
        #if os(iOS)
        .sheet(
            isPresented: Binding(
                get: { exportURL != nil },
                set: { newValue in if !newValue { exportURL = nil } }
            )
        ) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
        .alert(languageManager.localized("PDF Exported"), isPresented: $showExportConfirmation) {
            Button("OK") {}
        } message: {
            Text(languageManager.localized("Running records PDF has been saved successfully."))
        }
        .alert(languageManager.localized("Nothing to Export"), isPresented: $showEmptyExportAlert) {
            Button("OK") {}
        } message: {
            Text(languageManager.localized("There are no running records in the current filter."))
        }
    }

    // MARK: - Export

    func exportRunningRecordsPDF() {
        guard !filteredRecords.isEmpty else {
            showEmptyExportAlert = true
            return
        }

        let sanitizedSchoolName = SecurityHelpers.sanitizeNotes(schoolNameInput)
        let pdfURL = RunningRecordPDFExporter.export(
            student: student,
            schoolName: sanitizedSchoolName,
            runningRecords: filteredRecords,
            appliedFilters: exportFilterDescription
        )

        #if os(iOS)
        exportURL = pdfURL
        #elseif os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let safeName = SecurityHelpers.sanitizeFilename(student.name)
        savePanel.nameFieldStringValue = "\(safeName) - Running Records.pdf"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.copyItem(at: pdfURL, to: url)
                showExportConfirmation = true
            }
        }
        #endif
    }

    func clearFilters() {
        filterLevel = nil
        dateRange = .all
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
                ForEach(filteredRecords.reversed(), id: \.id) { record in
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
                Text(record.date.appDateString)
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
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    @State private var searchText = ""
    @State private var filterLevel: ReadingLevel?
    @State private var dateRange: RunningRecordDateRange = .all
    @State private var recordToDelete: RunningRecord?
    @State private var showingDeleteAlert = false

    var sortedRecords: [RunningRecord] {
        student.runningRecords.sorted { $0.date > $1.date }
    }

    var filteredRecords: [RunningRecord] {
        sortedRecords.filter { record in
            let matchesLevel = filterLevel == nil || record.readingLevel == filterLevel
            let matchesDate = dateRange.includes(record.date)
            let matchesSearch =
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                record.textTitle.localizedCaseInsensitiveContains(searchText) ||
                record.notes.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesDate && matchesSearch
        }
    }

    var hasActiveFilters: Bool {
        filterLevel != nil || dateRange != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                allRecordsFilters

                if filteredRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary)
                        Text(languageManager.localized("No records match current filters"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if hasActiveFilters {
                            Button(languageManager.localized("Clear Filters")) {
                                clearFilters()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRecords, id: \.id) { record in
                                RunningRecordCard(record: record, onDelete: {
                                    recordToDelete = record
                                    showingDeleteAlert = true
                                })
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(String(format: languageManager.localized("%@'s Records"), student.name))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: Text(languageManager.localized("Search text or notes")))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section(languageManager.localized("Reading Level")) {
                            Button(languageManager.localized("All Levels")) {
                                filterLevel = nil
                            }
                            ForEach(ReadingLevel.allCases, id: \.self) { level in
                                Button(levelShortName(level)) {
                                    filterLevel = level
                                }
                            }
                        }

                        Section(languageManager.localized("Date Range")) {
                            ForEach(RunningRecordDateRange.allCases, id: \.self) { range in
                                Button(range.label.localized) {
                                    dateRange = range
                                }
                            }
                        }

                        if hasActiveFilters {
                            Section {
                                Button(languageManager.localized("Clear Filters"), role: .destructive) {
                                    clearFilters()
                                }
                            }
                        }
                    } label: {
                        Label(languageManager.localized("Filter"), systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(languageManager.localized("Delete Running Record?"), isPresented: $showingDeleteAlert) {
                Button(languageManager.localized("Cancel"), role: .cancel) {
                    recordToDelete = nil
                }
                Button(languageManager.localized("Delete"), role: .destructive) {
                    if let record = recordToDelete {
                        context.delete(record)
                        try? context.save()
                    }
                    recordToDelete = nil
                }
            } message: {
                if let record = recordToDelete {
                    Text(String(format: languageManager.localized("Are you sure you want to delete the running record for \"%@\"? This cannot be undone."), record.textTitle))
                }
            }
        }
    }

    var allRecordsFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReadingLevel.allCases, id: \.self) { level in
                    Button {
                        filterLevel = (filterLevel == level) ? nil : level
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: level.systemImage)
                            Text(levelShortName(level))
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(filterLevel == level ? levelColor(level).opacity(0.16) : Color.gray.opacity(0.12))
                        .foregroundColor(filterLevel == level ? levelColor(level) : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    ForEach(RunningRecordDateRange.allCases, id: \.self) { range in
                        Button(range.label.localized) {
                            dateRange = range
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(dateRange.label.localized)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(dateRange != .all ? Color.blue.opacity(0.16) : Color.gray.opacity(0.12))
                    .foregroundColor(dateRange != .all ? .blue : .primary)
                    .cornerRadius(8)
                }

                if hasActiveFilters {
                    Button(languageManager.localized("Clear")) {
                        clearFilters()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    func clearFilters() {
        searchText = ""
        filterLevel = nil
        dateRange = .all
    }

    func levelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return languageManager.localized("Independent")
        case .instructional: return languageManager.localized("Instructional")
        case .frustration: return languageManager.localized("Frustration")
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
