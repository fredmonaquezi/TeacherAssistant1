import SwiftUI
import SwiftData

private struct CalendarDayDetailSheetModifier: ViewModifier {
    @Environment(\.modelContext) private var context

    @Binding var isPresented: Bool
    let date: Date
    let classes: [SchoolClass]
    let selectedClass: SchoolClass?
    let diaryEntries: [ClassDiaryEntry]
    let events: [CalendarEvent]

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            DayDetailSheet(
                date: date,
                classes: classes,
                selectedClass: selectedClass,
                diaryEntries: diaryEntries,
                events: events,
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
}

extension View {
    func calendarDayDetailSheet(
        isPresented: Binding<Bool>,
        date: Date,
        classes: [SchoolClass],
        selectedClass: SchoolClass?,
        diaryEntries: [ClassDiaryEntry],
        events: [CalendarEvent]
    ) -> some View {
        modifier(
            CalendarDayDetailSheetModifier(
                isPresented: isPresented,
                date: date,
                classes: classes,
                selectedClass: selectedClass,
                diaryEntries: diaryEntries,
                events: events
            )
        )
    }
}
