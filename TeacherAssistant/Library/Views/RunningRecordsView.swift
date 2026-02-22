import SwiftUI
import SwiftData

struct RunningRecordsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    @Query private var allStudents: [Student]
    @Query(sort: \RunningRecord.date, order: .reverse) private var allRunningRecords: [RunningRecord]

    @State private var selectedClass: SchoolClass?
    @State private var selectedStudent: Student?
    @State private var showingAddRecord = false
    @State private var searchText = ""
    @State private var filterLevel: ReadingLevel?
    @State private var selectedDateRange: RunningRecordDateRangePreset = .all
    @State private var customDateStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customDateEnd = Date()
    @State private var sortOption: RunningRecordSortOption = .dateDescending
    @State private var recordToDelete: RunningRecord?
    @State private var showingDeleteAlert = false
    @State private var exportURL: URL?
    @State private var schoolNameForPDF = ""
    @State private var showingSchoolNamePrompt = false
    @State private var showingEmptyExportAlert = false
    @State private var showingStudentRequiredAlert = false
    @State private var showingExportFailedAlert = false

    var classOptions: [SchoolClass] {
        var seen: Set<String> = []
        var classes: [SchoolClass] = []
        for student in allStudents {
            guard let schoolClass = student.schoolClass else { continue }
            let key = String(describing: schoolClass.id)
            if seen.insert(key).inserted {
                classes.append(schoolClass)
            }
        }
        return classes.sorted { lhs, rhs in
            classDisplayName(lhs) < classDisplayName(rhs)
        }
    }

    var studentOptions: [Student] {
        var seen: Set<PersistentIdentifier> = []
        return allStudents
            .filter { student in
                guard let selectedClass else { return true }
                return student.schoolClass?.id == selectedClass.id
            }
            .filter { student in
                seen.insert(student.id).inserted
            }
            .sorted {
                if $0.name.caseInsensitiveCompare($1.name) == .orderedSame {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var normalizedCustomRange: (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: customDateStart)
        let endDayStart = Calendar.current.startOfDay(for: customDateEnd)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: endDayStart)?.addingTimeInterval(-1) ?? endDayStart
        return start <= end ? (start, end) : (end, start)
    }

    var filteredRecords: [RunningRecord] {
        var records = allRunningRecords

        if let selectedClass {
            records = records.filter { $0.student?.schoolClass?.id == selectedClass.id }
        }

        if let selectedStudent {
            records = records.filter { $0.student?.id == selectedStudent.id }
        }

        if let level = filterLevel {
            records = records.filter { $0.readingLevel == level }
        }

        records = records.filter { record in
            let customStart = selectedDateRange == .custom ? normalizedCustomRange.start : nil
            let customEnd = selectedDateRange == .custom ? normalizedCustomRange.end : nil
            return selectedDateRange.includes(record.date, customStartDate: customStart, customEndDate: customEnd)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            records = records.filter { record in
                record.searchableText.contains(query)
            }
        }

        return records
    }

    var sortedRecords: [RunningRecord] {
        filteredRecords.sorted { lhs, rhs in
            switch sortOption {
            case .dateDescending:
                return lhs.date > rhs.date
            case .dateAscending:
                return lhs.date < rhs.date
            case .accuracyDescending:
                return lhs.accuracy > rhs.accuracy
            case .accuracyAscending:
                return lhs.accuracy < rhs.accuracy
            case .studentAscending:
                return lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName) == .orderedAscending
            case .studentDescending:
                return lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName) == .orderedDescending
            }
        }
    }

    var filteredAverageAccuracy: Double {
        guard !sortedRecords.isEmpty else { return 0 }
        let total = sortedRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(sortedRecords.count)
    }

    var levelCounts: (independent: Int, instructional: Int, frustration: Int) {
        sortedRecords.reduce(into: (0, 0, 0)) { counts, record in
            switch record.readingLevel {
            case .independent:
                counts.0 += 1
            case .instructional:
                counts.1 += 1
            case .frustration:
                counts.2 += 1
            }
        }
    }

    var uniqueStudentsCount: Int {
        Set(allRunningRecords.compactMap { $0.student?.id }).count
    }

    var averageAccuracy: Double {
        guard !allRunningRecords.isEmpty else { return 0 }
        let total = allRunningRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(allRunningRecords.count)
    }

    var hasActiveFilters: Bool {
        selectedClass != nil ||
        selectedStudent != nil ||
        filterLevel != nil ||
        selectedDateRange != .all ||
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        sortOption != .dateDescending
    }

    var activeFiltersDescription: String? {
        var parts: [String] = []

        if let selectedClass {
            parts.append("\(languageManager.localized("Class")): \(classDisplayName(selectedClass))")
        }
        if let selectedStudent {
            parts.append("\(languageManager.localized("Student")): \(selectedStudent.name)")
        }
        if let filterLevel {
            parts.append("\(languageManager.localized("Level")): \(levelShortName(filterLevel))")
        }
        if selectedDateRange != .all {
            parts.append("\(languageManager.localized("Date")): \(dateRangeLabel(selectedDateRange))")
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            parts.append("\(languageManager.localized("Search")): \(query)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var body: some View {
        #if os(macOS)
        runningRecordsContent
        #else
        NavigationStack {
            runningRecordsContent
        }
        #endif
    }

    var runningRecordsContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                headerStatsView

                Divider()

                filtersView

                if sortedRecords.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedRecords, id: \.id) { record in
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

            #if os(macOS)
            Button {
                showingAddRecord = true
            } label: {
                Label(languageManager.localized("New Record"), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(24)
            #endif
        }
        #if !os(macOS)
        .navigationTitle(languageManager.localized("Running Records"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRecord = true
                } label: {
                    Label(languageManager.localized("New Record"), systemImage: "plus.circle.fill")
                }
            }
        }
        #endif
        .sheet(isPresented: $showingAddRecord) {
            AddRunningRecordView()
        }
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
        .alert(languageManager.localized("Export Running Records"), isPresented: $showingSchoolNamePrompt) {
            TextField(languageManager.localized("School Name (optional)"), text: $schoolNameForPDF)
            Button(languageManager.localized("Cancel"), role: .cancel) {}
            Button(languageManager.localized("Export PDF")) {
                performPDFExport()
            }
        } message: {
            Text(languageManager.localized("Enter the school name to appear on the PDF header."))
        }
        .alert(languageManager.localized("Select a Student"), isPresented: $showingStudentRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(languageManager.localized("Please select a student filter before exporting PDF from Running Records."))
        }
        .alert(languageManager.localized("Nothing to Export"), isPresented: $showingEmptyExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(languageManager.localized("There are no running records in the current filter."))
        }
        .alert(languageManager.localized("Export Failed"), isPresented: $showingExportFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(languageManager.localized("The export file could not be created. Please try again."))
        }
        .onChange(of: selectedClass?.id) { _, _ in
            guard let selectedStudent else { return }
            if let selectedClass, selectedStudent.schoolClass?.id != selectedClass.id {
                self.selectedStudent = nil
            }
        }
    }

    var headerStatsView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                statBox(
                    title: languageManager.localized("Total Records"),
                    value: "\(allRunningRecords.count)",
                    icon: "doc.text.fill",
                    color: .blue
                )

                statBox(
                    title: languageManager.localized("Students Assessed"),
                    value: "\(uniqueStudentsCount)",
                    icon: "person.3.fill",
                    color: .purple
                )

                statBox(
                    title: languageManager.localized("Avg. Accuracy"),
                    value: String(format: "%.1f%%", averageAccuracy),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )

                statBox(
                    title: languageManager.localized("Filtered Avg"),
                    value: String(format: "%.1f%%", filteredAverageAccuracy),
                    icon: "line.3.horizontal.decrease.circle",
                    color: .orange
                )
            }

            HStack(spacing: 12) {
                levelSummaryChip(title: languageManager.localized("Independent"), value: levelCounts.independent, color: .green)
                levelSummaryChip(title: languageManager.localized("Instructional"), value: levelCounts.instructional, color: .orange)
                levelSummaryChip(title: languageManager.localized("Frustration"), value: levelCounts.frustration, color: .red)
            }
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

    func levelSummaryChip(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(title): \(value)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var filtersView: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    exportMenuButton

                    Menu {
                        Button(languageManager.localized("All Classes")) {
                            selectedClass = nil
                        }
                        Divider()
                        ForEach(classOptions, id: \.id) { schoolClass in
                            Button(classDisplayName(schoolClass)) {
                                selectedClass = schoolClass
                            }
                        }
                    } label: {
                        filterChip(
                            icon: "graduationcap.fill",
                            title: selectedClass.map(classDisplayName) ?? languageManager.localized("All Classes"),
                            isActive: selectedClass != nil,
                            activeColor: .purple
                        )
                    }

                    Menu {
                        Button(languageManager.localized("All Students")) {
                            selectedStudent = nil
                        }
                        Divider()
                        ForEach(studentOptions, id: \.id) { student in
                            Button(studentMenuLabel(for: student, within: studentOptions)) {
                                selectedStudent = student
                            }
                        }
                    } label: {
                        filterChip(
                            icon: "person.fill",
                            title: selectedStudent.map { studentMenuLabel(for: $0, within: studentOptions) } ?? languageManager.localized("All Students"),
                            isActive: selectedStudent != nil,
                            activeColor: .blue
                        )
                    }

                    Menu {
                        ForEach(RunningRecordDateRangePreset.allCases) { range in
                            Button(dateRangeLabel(range)) {
                                selectedDateRange = range
                            }
                        }
                    } label: {
                        filterChip(
                            icon: "calendar",
                            title: dateRangeLabel(selectedDateRange),
                            isActive: selectedDateRange != .all,
                            activeColor: .indigo
                        )
                    }

                    Menu {
                        ForEach(RunningRecordSortOption.allCases) { option in
                            Button(sortOptionLabel(option)) {
                                sortOption = option
                            }
                        }
                    } label: {
                        filterChip(
                            icon: "arrow.up.arrow.down",
                            title: sortOptionLabel(sortOption),
                            isActive: sortOption != .dateDescending,
                            activeColor: .orange
                        )
                    }

                    ForEach(ReadingLevel.allCases, id: \.self) { level in
                        Button {
                            filterLevel = (filterLevel == level) ? nil : level
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

                    if hasActiveFilters {
                        Button(languageManager.localized("Clear")) {
                            clearFilters()
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(languageManager.localized("Search student, class, text, notes"), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)

            if selectedDateRange == .custom {
                HStack(spacing: 12) {
                    DatePicker(
                        languageManager.localized("From"),
                        selection: $customDateStart,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        languageManager.localized("To"),
                        selection: $customDateEnd,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }
                .padding(.horizontal)
            }

            if let activeFiltersDescription {
                HStack(spacing: 8) {
                    Text(String(format: "%@: %@", languageManager.localized("Filtered"), activeFiltersDescription))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }

    func filterChip(icon: String, title: String, isActive: Bool, activeColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? activeColor.opacity(0.15) : Color.gray.opacity(0.1))
        .foregroundColor(isActive ? activeColor : .primary)
        .cornerRadius(8)
    }

    var exportMenuButton: some View {
        Menu {
            Button {
                requestPDFExport()
            } label: {
                Label(languageManager.localized("Export PDF"), systemImage: "doc.richtext")
            }

            Button {
                exportCSV()
            } label: {
                Label(languageManager.localized("Export CSV"), systemImage: "tablecells")
            }

            Button {
                exportJSON()
            } label: {
                Label(languageManager.localized("Export JSON"), systemImage: "curlybraces")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text(languageManager.localized("Export"))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
    }

    func requestPDFExport() {
        guard !sortedRecords.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        guard selectedStudent != nil else {
            showingStudentRequiredAlert = true
            return
        }

        showingSchoolNamePrompt = true
    }

    func performPDFExport() {
        guard let selectedStudent else {
            showingStudentRequiredAlert = true
            return
        }

        let studentRecords = sortedRecords.filter { $0.student?.id == selectedStudent.id }
        guard !studentRecords.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        let url = RunningRecordPDFExporter.export(
            student: selectedStudent,
            schoolName: schoolNameForPDF,
            runningRecords: studentRecords,
            appliedFilters: activeFiltersDescription
        )
        exportURL = url
    }

    func exportCSV() {
        guard !sortedRecords.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        guard let url = RunningRecordsExportUtility.exportCSV(records: sortedRecords, appliedFilters: activeFiltersDescription) else {
            showingExportFailedAlert = true
            return
        }
        exportURL = url
    }

    func exportJSON() {
        guard !sortedRecords.isEmpty else {
            showingEmptyExportAlert = true
            return
        }

        guard let url = RunningRecordsExportUtility.exportJSON(records: sortedRecords, appliedFilters: activeFiltersDescription) else {
            showingExportFailedAlert = true
            return
        }
        exportURL = url
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle" : "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundColor(.secondary)

            Text(hasActiveFilters ? languageManager.localized("No records match current filters") : languageManager.localized("No Running Records Yet"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(languageManager.localized("Start assessing your students' reading by creating your first running record"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                if hasActiveFilters {
                    Button(languageManager.localized("Clear Filters")) {
                        clearFilters()
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    showingAddRecord = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(languageManager.localized("Create First Record"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func classDisplayName(_ schoolClass: SchoolClass) -> String {
        if schoolClass.grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return schoolClass.name
        }
        return "\(schoolClass.name) (\(schoolClass.grade))"
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

    func dateRangeLabel(_ range: RunningRecordDateRangePreset) -> String {
        switch range {
        case .all: return languageManager.localized("All Time")
        case .last7Days: return languageManager.localized("Last 7 Days")
        case .last30Days: return languageManager.localized("Last 30 Days")
        case .last90Days: return languageManager.localized("Last 90 Days")
        case .thisTerm: return languageManager.localized("This Term")
        case .custom: return languageManager.localized("Custom Range")
        }
    }

    func sortOptionLabel(_ option: RunningRecordSortOption) -> String {
        switch option {
        case .dateDescending: return languageManager.localized("Newest First")
        case .dateAscending: return languageManager.localized("Oldest First")
        case .accuracyDescending: return languageManager.localized("Accuracy High-Low")
        case .accuracyAscending: return languageManager.localized("Accuracy Low-High")
        case .studentAscending: return languageManager.localized("Student A-Z")
        case .studentDescending: return languageManager.localized("Student Z-A")
        }
    }

    func clearFilters() {
        selectedClass = nil
        selectedStudent = nil
        filterLevel = nil
        searchText = ""
        selectedDateRange = .all
        sortOption = .dateDescending
        customDateStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        customDateEnd = Date()
    }

    private func normalizedStudentName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func studentMenuLabel(for student: Student, within students: [Student]) -> String {
        let normalized = normalizedStudentName(student.name)
        let duplicates = students.filter { normalizedStudentName($0.name) == normalized }
        guard duplicates.count > 1 else { return student.name }

        let orderedDuplicates = duplicates.sorted {
            if $0.sortOrder == $1.sortOrder {
                return String(describing: $0.id) < String(describing: $1.id)
            }
            return $0.sortOrder < $1.sortOrder
        }
        let index = (orderedDuplicates.firstIndex(where: { $0.id == student.id }) ?? 0) + 1
        return "\(student.name) (#\(index))"
    }
}

// MARK: - Running Record Card

struct RunningRecordCard: View {
    let record: RunningRecord
    var onDelete: (() -> Void)?
    @State private var showingDetail = false
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let student = record.student {
                            Text(student.name)
                                .font(.headline)
                        } else {
                            Text(languageManager.localized("Unknown Student"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        Text(record.textTitle.isEmpty ? languageManager.localized("Untitled Text") : record.textTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(record.date.appDateString)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(record.date.appTimeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    miniStat(title: languageManager.localized("Accuracy"), value: String(format: "%.1f%%", record.accuracy), color: levelColor(record.readingLevel))
                    miniStat(title: languageManager.localized("Errors"), value: "\(record.errors)", color: .red)
                    miniStat(title: languageManager.localized("SC"), value: "\(record.selfCorrections)", color: .blue)
                    miniStat(title: languageManager.localized("Words"), value: "\(record.totalWords)", color: .purple)
                }

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
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(languageManager.localized("Delete"), systemImage: "trash")
                }
            }
        }
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
