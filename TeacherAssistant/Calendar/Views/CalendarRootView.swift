import SwiftUI
import SwiftData

struct CalendarRootView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appMotionContext) private var motion

    @Query private var classes: [SchoolClass]
    @Query private var diaryEntries: [ClassDiaryEntry]
    @Query private var events: [CalendarEvent]

    @State private var selectedDate = Date()
    @State private var viewMode: CalendarViewMode = .month
    @State private var selectedClassID: PersistentIdentifier?
    @State private var showingDayDetail = false
    @State private var derivedData: CalendarDerivedData = .empty
    @State private var saveRefreshRevision = 0
    
    private var selectedClass: SchoolClass? {
        derivedData.selectedClass
    }

    private var upcomingEventViewModels: [CalendarUpcomingEventViewModel] {
        Array(derivedData.upcomingEventViewModels.prefix(5))
    }

    private var refreshToken: String {
        [
            String(classes.count),
            String(diaryEntries.count),
            String(events.count),
            String(describing: selectedClassID),
            String(saveRefreshRevision),
        ].joined(separator: "|")
    }

    enum CalendarViewMode: String, CaseIterable {
        case month
        case week

        var localizedLabel: String {
            switch self {
            case .month: return "Month".localized
            case .week: return "Week".localized
            }
        }
    }

    var body: some View {
        #if os(macOS)
        // macOS: No NavigationStack needed, header navigation handles it
        calendarContent
        #else
        // iOS: Keep NavigationStack for proper navigation
        NavigationStack {
            calendarContent
        }
        #endif
    }
    
    var calendarContent: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                CalendarHeaderSectionView(
                    selectedDate: $selectedDate,
                    viewMode: $viewMode,
                    localeIdentifier: languageManager.currentLanguage.localeIdentifier
                )
                .appMotionReveal(index: 0)

                CalendarFilterSectionView(
                    classes: classes,
                    selectedClassID: $selectedClassID,
                    onSelectToday: {
                        selectedDate = Date()
                    }
                )
                .appMotionReveal(index: 1)

                Group {
                    if viewMode == .month {
                        MonthCalendarView(
                            monthDate: selectedDate,
                            selectedDate: $selectedDate,
                            dayCellViewModelsByDay: derivedData.dayCellViewModelsByDay,
                            localeIdentifier: languageManager.currentLanguage.localeIdentifier,
                            onSelect: {
                                showingDayDetail = true
                            }
                        )
                        .equatable()
                    } else {
                        WeekCalendarView(
                            dateInWeek: selectedDate,
                            selectedDate: $selectedDate,
                            dayCellViewModelsByDay: derivedData.dayCellViewModelsByDay,
                            localeIdentifier: languageManager.currentLanguage.localeIdentifier,
                            onSelect: {
                                showingDayDetail = true
                            }
                        )
                        .equatable()
                    }
                }
                .id(viewMode)
                .transition(motion.transition(.sectionSwitch))
                .appMotionReveal(index: 2)

                upcomingEventsCard
                    .appMotionReveal(index: 3)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        #if !os(macOS)
        .navigationTitle("Calendar".localized)
        #endif
        .appSheetBackground(tint: .blue)
        .id(languageManager.currentLanguage)
        .onReceive(NotificationCenter.default.publisher(for: .persistenceDidSave)) { _ in
            saveRefreshRevision &+= 1
        }
        .task(id: refreshToken) {
            do {
                try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
            } catch {
                return
            }
            await refreshDerivedData()
        }
        .animation(motion.animation(.standard), value: viewMode)
        .animation(motion.animation(.standard), value: selectedDate)
        .animation(motion.animation(.standard), value: selectedClassID)
        .calendarDayDetailSheet(
            isPresented: $showingDayDetail,
            date: selectedDate,
            classes: classes,
            selectedClass: selectedClass,
            diaryEntries: dayEntries(for: selectedDate),
            events: dayEvents(for: selectedDate)
        )
    }

    // MARK: - Upcoming

    var upcomingEventsCard: some View {
        CalendarUpcomingEventsCardView(
            events: upcomingEventViewModels,
            localeIdentifier: languageManager.currentLanguage.localeIdentifier
        )
            .equatable()
            .animation(motion.animation(.standard), value: upcomingEventViewModels.map(\.id))
    }

    // MARK: - Filtering

    var filteredDiaryEntries: [ClassDiaryEntry] {
        derivedData.filteredDiaryEntries
    }

    var filteredEvents: [CalendarEvent] {
        derivedData.filteredEvents
    }

    // MARK: - Helpers

    private func dayEntries(for date: Date) -> [ClassDiaryEntry] {
        let day = Calendar.current.startOfDay(for: date)
        return derivedData.diaryEntriesByDay[day] ?? []
    }

    private func dayEvents(for date: Date) -> [CalendarEvent] {
        let day = Calendar.current.startOfDay(for: date)
        return derivedData.eventsByDay[day] ?? []
    }

    @MainActor
    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.calendarDerive)
        let derived = await CalendarStore.deriveAsync(
            classes: classes,
            diaryEntries: diaryEntries,
            events: events,
            selectedClassID: selectedClassID
        )
        if Task.isCancelled {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }

        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
    }
}

struct CalendarUpcomingEventsCardView: View, Equatable {
    let events: [CalendarUpcomingEventViewModel]
    let localeIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                Text("Upcoming Alerts".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
            }

            if events.isEmpty {
                Text("No upcoming alerts".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(events) { event in
                    CalendarUpcomingEventRowView(
                        event: event,
                        localeIdentifier: localeIdentifier
                    )
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.12),
            tint: .orange
        )
    }
}

private struct CalendarUpcomingEventRowView: View, Equatable {
    let event: CalendarUpcomingEventViewModel
    let localeIdentifier: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(CalendarLocalizedFormatting.mediumDate(event.date, localeIdentifier: localeIdentifier))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let className = event.className, !className.isEmpty {
                Text(className)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Month View

struct MonthCalendarView: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    let dayCellViewModelsByDay: [Date: CalendarDayCellViewModel]
    let localeIdentifier: String
    let onSelect: () -> Void
    @Environment(\.appMotionContext) private var motion

    var body: some View {
        let days = CalendarGridBuilder.monthDays(for: monthDate)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(spacing: 8) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayCell(for: day)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            shadowOpacity: 0.04,
            shadowRadius: 6,
            shadowY: 2,
            tint: .blue
        )
    }

    var weekdayHeader: some View {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: localeIdentifier)
        let symbols = calendar.shortWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    func dayCell(for date: Date) -> some View {
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: monthDate, toGranularity: .month)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let daySummary = daySummary(for: date)

        return Button {
            withAnimation(motion.animation(.standard)) {
                selectedDate = date
                onSelect()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isCurrentMonth ? .primary : .secondary)
                    Spacer()
                    if isToday(date) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                }

                ForEach(daySummary.eventPreviews) { event in
                    Text(event.text)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.orange)
                }

                ForEach(daySummary.entryPreviews) { entry in
                    Text(entry.text)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }

                if daySummary.remainingCount > 0 {
                    Text(String(format: "+%d", daySummary.remainingCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.12) : AppChrome.elevatedBackground.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.28) : AppChrome.separator, lineWidth: 1)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    func daySummary(for date: Date) -> CalendarDayCellViewModel {
        dayCellViewModelsByDay[Calendar.current.startOfDay(for: date)] ?? .empty
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Week View

struct WeekCalendarView: View {
    let dateInWeek: Date
    @Binding var selectedDate: Date
    let dayCellViewModelsByDay: [Date: CalendarDayCellViewModel]
    let localeIdentifier: String
    let onSelect: () -> Void
    @Environment(\.appMotionContext) private var motion

    var body: some View {
        let weekDays = CalendarGridBuilder.weekDays(for: dateInWeek)
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    weekDayCell(for: day)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            shadowOpacity: 0.04,
            shadowRadius: 6,
            shadowY: 2,
            tint: .blue
        )
    }

    func weekDayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let daySummary = daySummary(for: date)

        return Button {
            withAnimation(motion.animation(.standard)) {
                selectedDate = date
                onSelect()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(shortWeekday(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AppTypography.cardTitle)
                ForEach(daySummary.eventPreviews) { event in
                    Text(event.text)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.orange)
                }
                ForEach(daySummary.entryPreviews) { entry in
                    Text(entry.text)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }
                if daySummary.remainingCount > 0 {
                    Text(String(format: "+%d", daySummary.remainingCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.12) : AppChrome.elevatedBackground.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.28) : AppChrome.separator, lineWidth: 1)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    func shortWeekday(_ date: Date) -> String {
        CalendarLocalizedFormatting.shortWeekday(date, localeIdentifier: localeIdentifier)
    }

    func daySummary(for date: Date) -> CalendarDayCellViewModel {
        dayCellViewModelsByDay[Calendar.current.startOfDay(for: date)] ?? .empty
    }
}

extension MonthCalendarView: Equatable {
    static func == (lhs: MonthCalendarView, rhs: MonthCalendarView) -> Bool {
        lhs.monthDate == rhs.monthDate &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.dayCellViewModelsByDay == rhs.dayCellViewModelsByDay &&
        lhs.localeIdentifier == rhs.localeIdentifier
    }
}

extension WeekCalendarView: Equatable {
    static func == (lhs: WeekCalendarView, rhs: WeekCalendarView) -> Bool {
        lhs.dateInWeek == rhs.dateInWeek &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.dayCellViewModelsByDay == rhs.dayCellViewModelsByDay &&
        lhs.localeIdentifier == rhs.localeIdentifier
    }
}

// MARK: - Editors

struct DiaryEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    let date: Date
    let classes: [SchoolClass]
    let selectedClass: SchoolClass?
    let onSave: (ClassDiaryEntry) -> Void

    @State private var selectedClassID: PersistentIdentifier?
    @State private var selectedSubject: Subject?
    @State private var selectedUnit: Unit?
    @State private var selectedAssignmentID: UUID?

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    @State private var plan = ""
    @State private var objectives = ""
    @State private var materials = ""
    @State private var notes = ""
    
    private var selectedClassObject: SchoolClass? {
        guard let selectedClassID else { return nil }
        return classes.first(where: { $0.persistentModelID == selectedClassID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PlatformSpacing.sectionSpacing) {
                    headerCard

                    infoCard

                    textCard(title: "Plan".localized, text: $plan, color: .blue)
                    textCard(title: "Objectives".localized, text: $objectives, color: .purple)
                    textCard(title: "Materials".localized, text: $materials, color: .green)
                    textCard(title: "Notes".localized, text: $notes, color: .gray)
                }
                .padding()
            }
            .appSheetBackground(tint: .blue)
            .navigationTitle("New Diary Entry".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        let entry = ClassDiaryEntry(
                            date: Calendar.current.startOfDay(for: date),
                            startTime: merge(date: date, time: startTime),
                            endTime: merge(date: date, time: endTime),
                            plan: SecurityHelpers.sanitizeNotes(plan),
                            objectives: SecurityHelpers.sanitizeNotes(objectives),
                            materials: SecurityHelpers.sanitizeNotes(materials),
                            notes: SecurityHelpers.sanitizeNotes(notes),
                            schoolClass: selectedClassObject,
                            subject: selectedSubject,
                            unit: selectedUnit,
                            assignment: selectedAssignmentObject
                        )
                        onSave(entry)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedClassID = selectedClass?.persistentModelID
            startTime = merge(date: date, time: defaultTime(hour: 8, minute: 30))
            endTime = merge(date: date, time: defaultTime(hour: 9, minute: 30))
        }
        .onChange(of: selectedClassID) { _, _ in
            selectedSubject = nil
            selectedUnit = nil
            if !assignmentsForSelection.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = nil
            }
        }
        .onChange(of: selectedSubject) { _, _ in
            selectedUnit = nil
            if !assignmentsForSelection.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = nil
            }
        }
        .onChange(of: selectedUnit) { _, _ in
            if !assignmentsForSelection.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = nil
            }
        }
    }

    var subjectsForSelectedClass: [Subject] {
        selectedClassObject?.subjects.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var unitsForSelectedSubject: [Unit] {
        selectedSubject?.units.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var assignmentsForSelection: [Assignment] {
        let scopedAssignments: [Assignment]
        if let selectedUnit {
            scopedAssignments = selectedUnit.assignments
        } else if let selectedClassObject {
            scopedAssignments = selectedClassObject.subjects.flatMap { subject in
                subject.units.flatMap(\.assignments)
            }
        } else {
            scopedAssignments = []
        }

        return scopedAssignments.sorted { lhs, rhs in
            if lhs.dueDate != rhs.dueDate {
                return lhs.dueDate < rhs.dueDate
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    var selectedAssignmentObject: Assignment? {
        guard let selectedAssignmentID else { return nil }
        return assignmentsForSelection.first(where: { $0.id == selectedAssignmentID })
    }

    var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .frame(width: 48, height: 48)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: Color.blue.opacity(0.14),
                    shadowOpacity: 0.02,
                    shadowRadius: 4,
                    shadowY: 1,
                    tint: .blue
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("New Diary Entry".localized)
                    .font(AppTypography.sectionTitle)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                Text("Class & Unit".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
            }

            pickerRow(label: "Class".localized) {
                Picker("Class".localized, selection: $selectedClassID) {
                    Text("All Classes".localized).tag(PersistentIdentifier?.none)
                    ForEach(classes, id: \.persistentModelID) { schoolClass in
                        Text(schoolClass.name).tag(PersistentIdentifier?.some(schoolClass.persistentModelID))
                    }
                }
                .pickerStyle(.menu)
            }

            pickerRow(label: "Subject".localized) {
                Picker("Subject".localized, selection: $selectedSubject) {
                    Text("None".localized).tag(Subject?.none)
                    ForEach(subjectsForSelectedClass, id: \.id) { subject in
                        Text(subject.name).tag(Optional(subject))
                    }
                }
                .pickerStyle(.menu)
            }

            pickerRow(label: "Unit".localized) {
                Picker("Unit".localized, selection: $selectedUnit) {
                    Text("None".localized).tag(Unit?.none)
                    ForEach(unitsForSelectedSubject, id: \.id) { unit in
                        Text(unit.name).tag(Optional(unit))
                    }
                }
                .pickerStyle(.menu)
            }

            pickerRow(label: "Assignment".localized) {
                Picker("Assignment".localized, selection: $selectedAssignmentID) {
                    Text("None".localized).tag(UUID?.none)
                    ForEach(assignmentsForSelection, id: \.id) { assignment in
                        Text(assignmentPickerLabel(for: assignment)).tag(UUID?.some(assignment.id))
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                Text("Start Time".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
            }

            HStack(spacing: 12) {
                Text("End Time".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }

    func pickerRow(label: String, picker: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            picker()
            Spacer()
        }
        .padding(.vertical, 4)
    }

    func textCard(title: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppTypography.cardTitle)
                Spacer()
            }

            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppChrome.elevatedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.16), lineWidth: 1)
                )
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: color.opacity(0.18),
            tint: color
        )
    }

    func longDate(_ date: Date) -> String {
        date.appDateString(systemStyle: .full)
    }

    func assignmentPickerLabel(for assignment: Assignment) -> String {
        let unitName = assignment.unit?.name ?? ""
        return unitName.isEmpty ? assignment.title : "\(assignment.title) • \(unitName)"
    }

    func merge(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    func defaultTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

struct EventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    let date: Date
    let classes: [SchoolClass]
    let selectedClass: SchoolClass?
    let onSave: (CalendarEvent) -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var isAllDay = true
    @State private var selectedClassID: PersistentIdentifier?
    @State private var selectedAssignmentID: UUID?
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    
    private var selectedClassObject: SchoolClass? {
        guard let selectedClassID else { return nil }
        return classes.first(where: { $0.persistentModelID == selectedClassID })
    }

    private var assignmentsForSelectedClass: [Assignment] {
        guard let selectedClassObject else { return [] }
        return selectedClassObject.subjects
            .flatMap { subject in
                subject.units.flatMap(\.assignments)
            }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var selectedAssignmentObject: Assignment? {
        guard let selectedAssignmentID else { return nil }
        return assignmentsForSelectedClass.first(where: { $0.id == selectedAssignmentID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PlatformSpacing.sectionSpacing) {
                    eventHeaderCard
                    eventInfoCard
                    eventDetailsCard
                }
                .padding()
            }
            .appSheetBackground(tint: .orange)
            .navigationTitle("New Event".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        let sanitizedTitle = SecurityHelpers.sanitizeName(title) ?? ""
                        let event = CalendarEvent(
                            title: sanitizedTitle,
                            date: Calendar.current.startOfDay(for: date),
                            startTime: isAllDay ? nil : merge(date: date, time: startTime),
                            endTime: isAllDay ? nil : merge(date: date, time: endTime),
                            details: SecurityHelpers.sanitizeNotes(details),
                            isAllDay: isAllDay,
                            schoolClass: selectedClassObject,
                            assignment: selectedAssignmentObject
                        )
                        onSave(event)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            selectedClassID = selectedClass?.persistentModelID
            startTime = merge(date: date, time: defaultTime(hour: 8, minute: 30))
            endTime = merge(date: date, time: defaultTime(hour: 9, minute: 30))
        }
        .onChange(of: selectedClassID) { _, _ in
            if !assignmentsForSelectedClass.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = nil
            }
        }
    }

    var eventHeaderCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
                .frame(width: 48, height: 48)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: Color.orange.opacity(0.14),
                    shadowOpacity: 0.02,
                    shadowRadius: 4,
                    shadowY: 1,
                    tint: .orange
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("New Event".localized)
                    .font(AppTypography.sectionTitle)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.18),
            tint: .orange
        )
    }

    var eventInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.orange)
                Text("Event".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Title".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextField("Title".localized, text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .appFieldStyle(tint: .orange)
            }

            Toggle("All Day".localized, isOn: $isAllDay)

            if !isAllDay {
                HStack(spacing: 12) {
                    Text("Start Time".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("End Time".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                Text("Class".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Picker("Class".localized, selection: $selectedClassID) {
                    Text("All Classes".localized).tag(PersistentIdentifier?.none)
                    ForEach(classes, id: \.persistentModelID) { schoolClass in
                        Text(schoolClass.name).tag(PersistentIdentifier?.some(schoolClass.persistentModelID))
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }

            HStack(spacing: 12) {
                Text("Assignment".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Picker("Assignment".localized, selection: $selectedAssignmentID) {
                    Text("None".localized).tag(UUID?.none)
                    ForEach(assignmentsForSelectedClass, id: \.id) { assignment in
                        Text(assignmentPickerLabel(for: assignment)).tag(UUID?.some(assignment.id))
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.12),
            tint: .orange
        )
    }

    var eventDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Details".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
            }

            TextEditor(text: $details)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppChrome.elevatedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                )
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.18),
            tint: .orange
        )
    }

    func longDate(_ date: Date) -> String {
        date.appDateString(systemStyle: .full)
    }

    func assignmentPickerLabel(for assignment: Assignment) -> String {
        let unitName = assignment.unit?.name ?? ""
        return unitName.isEmpty ? assignment.title : "\(assignment.title) • \(unitName)"
    }

    func merge(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    func defaultTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

enum CalendarLocalizedFormatting {
    private static var formatterCache: [String: DateFormatter] = [:]
    private static let cacheLock = NSLock()

    static func monthTitle(
        for date: Date,
        localeIdentifier: String,
        in mode: CalendarRootView.CalendarViewMode
    ) -> String {
        switch mode {
        case .month:
            return formatted(
                date,
                localeIdentifier: localeIdentifier,
                dateFormat: "LLLL yyyy"
            )
        case .week:
            return mediumDate(date, localeIdentifier: localeIdentifier)
        }
    }

    static func shortWeekday(_ date: Date, localeIdentifier: String) -> String {
        formatted(date, localeIdentifier: localeIdentifier, dateFormat: "EEE")
    }

    static func mediumDate(_ date: Date, localeIdentifier: String) -> String {
        formatted(date, localeIdentifier: localeIdentifier, dateStyle: .medium)
    }

    static func longDate(_ date: Date, localeIdentifier: String) -> String {
        formatted(date, localeIdentifier: localeIdentifier, dateStyle: .full)
    }

    private static func formatted(
        _ date: Date,
        localeIdentifier: String,
        dateFormat: String? = nil,
        dateStyle: DateFormatter.Style = .none
    ) -> String {
        let key = "\(localeIdentifier)|\(dateFormat ?? "style-\(dateStyle.rawValue)")"
        let formatter: DateFormatter

        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = formatterCache[key] {
            formatter = cached
        } else {
            let created = DateFormatter()
            created.locale = Locale(identifier: localeIdentifier)
            if let dateFormat {
                created.dateFormat = dateFormat
            } else {
                created.dateStyle = dateStyle
                created.timeStyle = .none
            }
            formatterCache[key] = created
            formatter = created
        }

        return formatter.string(from: date)
    }
}

// MARK: - Calendar Grid Builder

enum CalendarGridBuilder {
    static func monthDays(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        var days: [Date] = []

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        if leadingDays > 0 {
            for i in 1...leadingDays {
                if let day = calendar.date(byAdding: .day, value: -i, to: monthStart) {
                    days.append(day)
                }
            }
            days.reverse()
        }

        var current = monthStart
        while current < monthEnd {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        while days.count % 7 != 0 {
            if let last = days.last,
               let next = calendar.date(byAdding: .day, value: 1, to: last) {
                days.append(next)
            } else {
                break
            }
        }

        return days
    }

    static func weekDays(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
}
