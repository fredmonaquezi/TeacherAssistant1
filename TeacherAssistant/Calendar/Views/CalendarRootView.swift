import SwiftUI
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
    
    private var selectedClass: SchoolClass? {
        guard let selectedClassID else { return nil }
        return classes.first(where: { $0.persistentModelID == selectedClassID })
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
            VStack(spacing: 16) {
                headerBar

                filterBar

                if viewMode == .month {
                    MonthCalendarView(
                        monthDate: selectedDate,
                        selectedDate: $selectedDate,
                        entries: filteredDiaryEntries,
                        events: filteredEvents,
                        localeIdentifier: languageManager.currentLanguage.localeIdentifier,
                        onSelect: {
                            showingDayDetail = true
                        }
                    )
                } else {
                    WeekCalendarView(
                        dateInWeek: selectedDate,
                        selectedDate: $selectedDate,
                        entries: filteredDiaryEntries,
                        events: filteredEvents,
                        localeIdentifier: languageManager.currentLanguage.localeIdentifier,
                        onSelect: {
                            showingDayDetail = true
                        }
                    )
                }

                upcomingEventsCard
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        #if !os(macOS)
        .navigationTitle("Calendar".localized)
        #endif
        .id(languageManager.currentLanguage)
        .sheet(isPresented: $showingDayDetail) {
            DayDetailSheet(
                date: selectedDate,
                classes: classes,
                selectedClass: selectedClass,
                entries: filteredDiaryEntries,
                events: filteredEvents,
                onSaveEntry: { entry in
                    context.insert(entry)
                },
                onSaveEvent: { event in
                    context.insert(event)
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
                        .font(.headline)
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
                        .font(.headline)
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
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        .cornerRadius(16)
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
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Upcoming

    var upcomingEventsCard: some View {
        let upcoming = upcomingEvents(limit: 5)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                Text("Upcoming Alerts".localized)
                    .font(.headline)
                Spacer()
            }

            if upcoming.isEmpty {
                Text("No upcoming alerts".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(upcoming, id: \.id) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(shortDate(event.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let schoolClass = event.schoolClass {
                            Text(schoolClass.name)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
    }

    // MARK: - Filtering

    var filteredDiaryEntries: [ClassDiaryEntry] {
        guard let selectedClass else { return diaryEntries }
        return diaryEntries.filter { $0.schoolClass?.persistentModelID == selectedClass.persistentModelID }
    }

    var filteredEvents: [CalendarEvent] {
        guard let selectedClass else { return events }
        return events.filter { $0.schoolClass?.persistentModelID == selectedClass.persistentModelID }
    }

    // MARK: - Helpers

    func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        if viewMode == .month {
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: date)
        }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func upcomingEvents(limit: Int) -> [CalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return filteredEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Month View

struct MonthCalendarView: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    let entries: [ClassDiaryEntry]
    let events: [CalendarEvent]
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
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
        let entryCount = entriesFor(date).count
        let eventCount = eventsFor(date).count
        let dayEntries = entriesFor(date)
        let dayEvents = eventsFor(date)
        let previewEvents = Array(dayEvents.prefix(2))
        let previewEntries = Array(dayEntries.prefix(2))
        let remainingCount = max(0, (dayEntries.count + dayEvents.count) - (previewEvents.count + previewEntries.count))

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

                ForEach(previewEvents, id: \.id) { event in
                    Text(event.title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.orange)
                }

                ForEach(previewEntries, id: \.id) { entry in
                    let label = entry.unit?.name ?? entry.subject?.name ?? entry.schoolClass?.name ?? "Class Diary".localized
                    Text(label)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }

                if remainingCount > 0 {
                    Text(String(format: "+%d", remainingCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.gray.opacity(0.04))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    func entriesFor(_ date: Date) -> [ClassDiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Week View

struct WeekCalendarView: View {
    let dateInWeek: Date
    @Binding var selectedDate: Date
    let entries: [ClassDiaryEntry]
    let events: [CalendarEvent]
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    func weekDayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let entryCount = entriesFor(date).count
        let eventCount = eventsFor(date).count
        let dayEntries = entriesFor(date)
        let dayEvents = eventsFor(date)
        let previewEvents = Array(dayEvents.prefix(2))
        let previewEntries = Array(dayEntries.prefix(2))
        let remainingCount = max(0, (dayEntries.count + dayEvents.count) - (previewEvents.count + previewEntries.count))

        return Button {
            selectedDate = date
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(shortWeekday(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.headline)
                ForEach(previewEvents, id: \.id) { event in
                    Text(event.title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.orange)
                }
                ForEach(previewEntries, id: \.id) { entry in
                    let label = entry.unit?.name ?? entry.subject?.name ?? entry.schoolClass?.name ?? "Class Diary".localized
                    Text(label)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }
                if remainingCount > 0 {
                    Text(String(format: "+%d", remainingCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.gray.opacity(0.04))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func entriesFor(_ date: Date) -> [ClassDiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
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
    let entries: [ClassDiaryEntry]
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
                VStack(spacing: 16) {
                    headerCard

                    diarySection

                    eventsSection
                }
                .padding()
            }
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
                        context.delete(entryToDelete)
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
                        context.delete(eventToDelete)
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
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    var diarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Class Diary".localized)
                    .font(.headline)
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
                    .font(.headline)
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
                        .font(.headline)
                        .fontWeight(.semibold)
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    func eventCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    eventToDelete = event
                    showingDeleteEventAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }

    func labeledBody(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    func timeRangeText(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    func eventTimeText(_ event: CalendarEvent) -> String? {
        if event.isAllDay {
            return "All Day".localized
        }
        return timeRangeText(start: event.startTime, end: event.endTime)
    }

    func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var diaryEntriesForDay: [ClassDiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted {
                let t0 = $0.startTime ?? Date.distantFuture
                let t1 = $1.startTime ?? Date.distantFuture
                if t0 != t1 { return t0 < t1 }
                return ($0.schoolClass?.name ?? "") < ($1.schoolClass?.name ?? "")
            }
    }

    var eventsForDay: [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                let t0 = $0.startTime ?? Date.distantFuture
                let t1 = $1.startTime ?? Date.distantFuture
                return t0 < t1
            }
    }

    func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
                VStack(spacing: 16) {
                    headerCard

                    infoCard

                    textCard(title: "Plan".localized, text: $plan, color: .blue)
                    textCard(title: "Objectives".localized, text: $objectives, color: .purple)
                    textCard(title: "Materials".localized, text: $materials, color: .green)
                    textCard(title: "Notes".localized, text: $notes, color: .gray)
                }
                .padding()
            }
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
                .background(Color.blue.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text("New Diary Entry".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                Text("Class & Unit".localized)
                    .font(.headline)
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
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
                    .font(.headline)
                Spacer()
            }

            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
                VStack(spacing: 16) {
                    eventHeaderCard
                    eventInfoCard
                    eventDetailsCard
                }
                .padding()
            }
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
                .background(Color.orange.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text("New Event".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(longDate(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    var eventInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.orange)
                Text("Event".localized)
                    .font(.headline)
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
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(10)
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
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1)
        )
    }

    var eventDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Details".localized)
                    .font(.headline)
                Spacer()
            }

            TextEditor(text: $details)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage.localeIdentifier)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
