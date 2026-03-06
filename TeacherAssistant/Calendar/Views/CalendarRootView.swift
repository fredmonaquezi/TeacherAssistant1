import SwiftUI
import SwiftData

struct CalendarRootView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.modelContext) private var context

    @Query private var classes: [SchoolClass]
    @Query private var diaryEntries: [ClassDiaryEntry]
    @Query private var events: [CalendarEvent]

    @State private var selectedDate = Date()
    @State private var viewMode: CalendarViewMode = .month
    @State private var selectedClassID: PersistentIdentifier?
    @State private var showingDayDetail = false
    @State private var derivedData: CalendarDerivedData = .empty
    
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
                headerBar

                filterBar

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

                upcomingEventsCard
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        #if !os(macOS)
        .navigationTitle("Calendar".localized)
        #endif
        .appSheetBackground(tint: .blue)
        .id(languageManager.currentLanguage)
        .task(id: refreshToken) {
            do {
                try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
            } catch {
                return
            }
            await refreshDerivedData()
        }
        .sheet(isPresented: $showingDayDetail) {
            DayDetailSheet(
                date: selectedDate,
                classes: classes,
                selectedClass: selectedClass,
                diaryEntries: dayEntries(for: selectedDate),
                events: dayEvents(for: selectedDate),
                onSaveEntry: { entry in
                    Task {
                        await PersistenceWriteCoordinator.shared.perform(
                            context: context,
                            reason: "Create calendar diary entry"
                        ) {
                            context.insert(entry)
                        }
                    }
                },
                onSaveEvent: { event in
                    Task {
                        await PersistenceWriteCoordinator.shared.perform(
                            context: context,
                            reason: "Create calendar event"
                        ) {
                            context.insert(event)
                        }
                    }
                }
            )
        }
    }

    // MARK: - Header

    var headerBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    let component: Calendar.Component = viewMode == .month ? .month : .weekOfYear
                    selectedDate = Calendar.current.date(byAdding: component, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle(for: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    let component: Calendar.Component = viewMode == .month ? .month : .weekOfYear
                    selectedDate = Calendar.current.date(byAdding: component, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            Picker("View Mode".localized, selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.rawValue) { mode in
                    Text(mode.localizedLabel).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }

    // MARK: - Filter

    var filterBar: some View {
        HStack(spacing: 12) {
            Text("Class".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Class".localized, selection: $selectedClassID) {
                Text("All Classes".localized).tag(PersistentIdentifier?.none)
                ForEach(classes, id: \.persistentModelID) { schoolClass in
                    Text(schoolClass.name).tag(PersistentIdentifier?.some(schoolClass.persistentModelID))
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Button {
                selectedDate = Date()
            } label: {
                Text("Today".localized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .appCardStyle(
                        cornerRadius: 10,
                        borderColor: Color.blue.opacity(0.16),
                        shadowOpacity: 0.02,
                        shadowRadius: 4,
                        shadowY: 1,
                        tint: .blue
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Upcoming

    var upcomingEventsCard: some View {
        CalendarUpcomingEventsCardView(
            events: upcomingEventViewModels,
            localeIdentifier: languageManager.currentLanguage.localeIdentifier
        )
            .equatable()
    }

    // MARK: - Filtering

    var filteredDiaryEntries: [ClassDiaryEntry] {
        derivedData.filteredDiaryEntries
    }

    var filteredEvents: [CalendarEvent] {
        derivedData.filteredEvents
    }

    // MARK: - Helpers

    func monthTitle(for date: Date) -> String {
        CalendarLocalizedFormatting.monthTitle(
            for: date,
            localeIdentifier: languageManager.currentLanguage.localeIdentifier,
            in: viewMode
        )
    }

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
            selectedDate = date
            onSelect()
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
        .buttonStyle(.plain)
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
            selectedDate = date
            onSelect()
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
        .buttonStyle(.plain)
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

// MARK: - Day Detail

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.modelContext) private var context

    let date: Date
    let classes: [SchoolClass]
    let selectedClass: SchoolClass?
    let diaryEntries: [ClassDiaryEntry]
    let events: [CalendarEvent]
    let onSaveEntry: (ClassDiaryEntry) -> Void
    let onSaveEvent: (CalendarEvent) -> Void

    @State private var showingNewEntry = false
    @State private var showingNewEvent = false
    @State private var entryToDelete: ClassDiaryEntry?
    @State private var eventToDelete: CalendarEvent?
    @State private var showingDeleteEntryAlert = false
    @State private var showingDeleteEventAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PlatformSpacing.sectionSpacing) {
                    headerCard

                    diarySection

                    eventsSection
                }
                .padding()
            }
            .appSheetBackground(tint: .blue)
            .navigationTitle(dayTitle(date))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) { dismiss() }
                }
            }
            .alert("Delete Entry?".localized, isPresented: $showingDeleteEntryAlert) {
                Button("Cancel".localized, role: .cancel) {
                    entryToDelete = nil
                }
                Button("Delete".localized, role: .destructive) {
                    if let entryToDelete {
                        Task {
                            await PersistenceWriteCoordinator.shared.perform(
                                context: context,
                                reason: "Delete calendar diary entry"
                            ) {
                                context.delete(entryToDelete)
                            }
                        }
                    }
                    entryToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this diary entry?".localized)
            }
            .alert("Delete Event?".localized, isPresented: $showingDeleteEventAlert) {
                Button("Cancel".localized, role: .cancel) {
                    eventToDelete = nil
                }
                Button("Delete".localized, role: .destructive) {
                    if let eventToDelete {
                        Task {
                            await PersistenceWriteCoordinator.shared.perform(
                                context: context,
                                reason: "Delete calendar event"
                            ) {
                                context.delete(eventToDelete)
                            }
                        }
                    }
                    eventToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this event?".localized)
            }
        }
    }

    var headerCard: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle(date))
                    .font(AppTypography.sectionTitle)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.blue.opacity(0.14),
            tint: .blue
        )
    }

    var diarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Class Diary".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
                Button {
                    showingNewEntry = true
                } label: {
                    Label("Add Entry".localized, systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            if diaryEntriesForDay.isEmpty {
                Text("No diary entries for this day".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(diaryEntriesForDay, id: \.id) { entry in
                    diaryCard(entry)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.10),
            tint: .blue
        )
        .sheet(isPresented: $showingNewEntry) {
            DiaryEntryEditor(
                date: date,
                classes: classes,
                selectedClass: selectedClass,
                onSave: onSaveEntry
            )
        }
    }

    var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events & Alerts".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
                Button {
                    showingNewEvent = true
                } label: {
                    Label("Add Event".localized, systemImage: "bell.badge.fill")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }

            if eventsForDay.isEmpty {
                Text("No events for this day".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(eventsForDay, id: \.id) { event in
                    eventCard(event)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.10),
            tint: .orange
        )
        .sheet(isPresented: $showingNewEvent) {
            EventEditor(
                date: date,
                classes: classes,
                selectedClass: selectedClass,
                onSave: onSaveEvent
            )
        }
    }

    func diaryCard(_ entry: ClassDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.schoolClass?.name ?? "All Classes".localized)
                        .font(AppTypography.cardTitle)
                    if let time = timeRangeText(start: entry.startTime, end: entry.endTime) {
                        Text(time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        if let subject = entry.subject {
                            tag(subject.name, color: .blue)
                        }
                        if let unit = entry.unit {
                            tag(unit.name, color: .blue.opacity(0.7))
                        }
                    }
                }
                Spacer()
                Button {
                    entryToDelete = entry
                    showingDeleteEntryAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }

            if !entry.plan.isEmpty {
                labeledBody("Plan".localized, entry.plan)
            }
            if !entry.objectives.isEmpty {
                labeledBody("Objectives".localized, entry.objectives)
            }
            if !entry.materials.isEmpty {
                labeledBody("Materials".localized, entry.materials)
            }
            if !entry.notes.isEmpty {
                labeledBody("Notes".localized, entry.notes)
            }
        }
        .padding(16)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.15),
            tint: .blue
        )
    }

    func eventCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.title)
                    .font(AppTypography.cardTitle)
                Spacer()
                Button {
                    eventToDelete = event
                    showingDeleteEventAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }

            if let timeText = eventTimeText(event) {
                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(shortDate(event.date))
                .font(.caption2)
                .foregroundColor(.secondary)

            if let schoolClass = event.schoolClass {
                tag(schoolClass.name, color: .orange)
            }

            if !event.details.isEmpty {
                Text(event.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.18),
            tint: .orange
        )
    }

    func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    func labeledBody(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.eyebrow)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    func timeRangeText(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        return "\(start.appTimeString(systemStyle: .short)) – \(end.appTimeString(systemStyle: .short))"
    }

    func eventTimeText(_ event: CalendarEvent) -> String? {
        if event.isAllDay {
            return "All Day".localized
        }
        return timeRangeText(start: event.startTime, end: event.endTime)
    }

    func shortDate(_ date: Date) -> String {
        date.appDateString(systemStyle: .medium)
    }

    var diaryEntriesForDay: [ClassDiaryEntry] {
        diaryEntries
    }

    var eventsForDay: [CalendarEvent] {
        events
    }

    func dayTitle(_ date: Date) -> String {
        CalendarLocalizedFormatting.shortWeekday(
            date,
            localeIdentifier: languageManager.currentLanguage.localeIdentifier
        )
    }

    func longDate(_ date: Date) -> String {
        CalendarLocalizedFormatting.longDate(
            date,
            localeIdentifier: languageManager.currentLanguage.localeIdentifier
        )
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
                            unit: selectedUnit
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
        }
        .onChange(of: selectedSubject) { _, _ in
            selectedUnit = nil
        }
    }

    var subjectsForSelectedClass: [Subject] {
        selectedClassObject?.subjects.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var unitsForSelectedSubject: [Unit] {
        selectedSubject?.units.sorted { $0.sortOrder < $1.sortOrder } ?? []
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
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    
    private var selectedClassObject: SchoolClass? {
        guard let selectedClassID else { return nil }
        return classes.first(where: { $0.persistentModelID == selectedClassID })
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
                            schoolClass: selectedClassObject
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

private enum CalendarLocalizedFormatting {
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
