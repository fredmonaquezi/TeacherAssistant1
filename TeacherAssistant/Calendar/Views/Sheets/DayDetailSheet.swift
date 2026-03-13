import SwiftUI
import SwiftData

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
                        if let assignment = entry.assignment {
                            tag(assignment.title, color: .teal)
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

            HStack(spacing: 6) {
                if let schoolClass = event.schoolClass {
                    tag(schoolClass.name, color: .orange)
                }
                if let assignment = event.assignment {
                    tag(assignment.title, color: .teal)
                }
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
