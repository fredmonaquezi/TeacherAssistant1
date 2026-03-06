import Foundation
import SwiftData

struct CalendarPreviewText: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
}

struct CalendarDayCellViewModel: Equatable, Sendable {
    let eventPreviews: [CalendarPreviewText]
    let entryPreviews: [CalendarPreviewText]
    let remainingCount: Int

    static let empty = CalendarDayCellViewModel(
        eventPreviews: [],
        entryPreviews: [],
        remainingCount: 0
    )
}

struct CalendarUpcomingEventViewModel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let date: Date
    let className: String?
}

struct CalendarDerivedData {
    let selectedClass: SchoolClass?
    let filteredDiaryEntries: [ClassDiaryEntry]
    let filteredEvents: [CalendarEvent]
    let diaryEntriesByDay: [Date: [ClassDiaryEntry]]
    let eventsByDay: [Date: [CalendarEvent]]
    let dayCellViewModelsByDay: [Date: CalendarDayCellViewModel]
    let upcomingEvents: [CalendarEvent]
    let upcomingEventViewModels: [CalendarUpcomingEventViewModel]

    static let empty = CalendarDerivedData(
        selectedClass: nil,
        filteredDiaryEntries: [],
        filteredEvents: [],
        diaryEntriesByDay: [:],
        eventsByDay: [:],
        dayCellViewModelsByDay: [:],
        upcomingEvents: [],
        upcomingEventViewModels: []
    )
}

enum CalendarStore {
    static func derive(
        classes: [SchoolClass],
        diaryEntries: [ClassDiaryEntry],
        events: [CalendarEvent],
        selectedClassID: PersistentIdentifier?
    ) -> CalendarDerivedData {
        let selectedClassKey = selectedClassID.map { String(describing: $0) }
        let classSnapshots = makeClassSnapshots(classes)
        let diarySnapshots = makeDiarySnapshots(diaryEntries)
        let eventSnapshots = makeEventSnapshots(events)
        let computation = computeDerivation(
            selectedClassKey: selectedClassKey,
            classSnapshots: classSnapshots,
            diarySnapshots: diarySnapshots,
            eventSnapshots: eventSnapshots,
            todayStart: Calendar.current.startOfDay(for: Date())
        )

        return makeDerivedData(
            classes: classes,
            diaryEntries: diaryEntries,
            events: events,
            eventSnapshots: eventSnapshots,
            computation: computation
        )
    }

    static func deriveAsync(
        classes: [SchoolClass],
        diaryEntries: [ClassDiaryEntry],
        events: [CalendarEvent],
        selectedClassID: PersistentIdentifier?
    ) async -> CalendarDerivedData {
        let selectedClassKey = selectedClassID.map { String(describing: $0) }
        let classSnapshots = makeClassSnapshots(classes)
        let diarySnapshots = makeDiarySnapshots(diaryEntries)
        let eventSnapshots = makeEventSnapshots(events)
        let todayStart = Calendar.current.startOfDay(for: Date())

        let computation = await Task.detached(priority: .userInitiated) {
            computeDerivation(
                selectedClassKey: selectedClassKey,
                classSnapshots: classSnapshots,
                diarySnapshots: diarySnapshots,
                eventSnapshots: eventSnapshots,
                todayStart: todayStart
            )
        }.value

        if Task.isCancelled {
            return .empty
        }

        return makeDerivedData(
            classes: classes,
            diaryEntries: diaryEntries,
            events: events,
            eventSnapshots: eventSnapshots,
            computation: computation
        )
    }

    private static func makeClassSnapshots(_ classes: [SchoolClass]) -> [CalendarClassSnapshot] {
        classes.enumerated().map { index, schoolClass in
            CalendarClassSnapshot(
                index: index,
                classKey: String(describing: schoolClass.persistentModelID)
            )
        }
    }

    private static func makeDiarySnapshots(_ entries: [ClassDiaryEntry]) -> [CalendarDiarySnapshot] {
        entries.enumerated().map { index, entry in
            CalendarDiarySnapshot(
                index: index,
                classKey: entry.schoolClass.map { String(describing: $0.persistentModelID) },
                day: Calendar.current.startOfDay(for: entry.date),
                startTime: entry.startTime ?? Date.distantFuture,
                className: entry.schoolClass?.name ?? "",
                previewLabel: entry.unit?.name ?? entry.subject?.name ?? entry.schoolClass?.name ?? "Class Diary"
            )
        }
    }

    private static func makeEventSnapshots(_ events: [CalendarEvent]) -> [CalendarEventSnapshot] {
        events.enumerated().map { index, event in
            CalendarEventSnapshot(
                index: index,
                classKey: event.schoolClass.map { String(describing: $0.persistentModelID) },
                className: event.schoolClass?.name,
                date: event.date,
                day: Calendar.current.startOfDay(for: event.date),
                startTime: event.startTime ?? Date.distantFuture,
                isAllDay: event.isAllDay,
                title: event.title
            )
        }
    }

    nonisolated private static func computeDerivation(
        selectedClassKey: String?,
        classSnapshots: [CalendarClassSnapshot],
        diarySnapshots: [CalendarDiarySnapshot],
        eventSnapshots: [CalendarEventSnapshot],
        todayStart: Date
    ) -> CalendarComputation {
        let selectedClassIndex = selectedClassKey.flatMap { key in
            classSnapshots.first(where: { $0.classKey == key })?.index
        }
        let selectedFilterKey = selectedClassIndex.flatMap { index in
            classSnapshots.indices.contains(index) ? classSnapshots[index].classKey : nil
        }

        let filteredDiaryIndices: [Int]
        let filteredEventIndices: [Int]
        if let selectedFilterKey {
            filteredDiaryIndices = diarySnapshots
                .filter { $0.classKey == selectedFilterKey }
                .map(\.index)
            filteredEventIndices = eventSnapshots
                .filter { $0.classKey == selectedFilterKey }
                .map(\.index)
        } else {
            filteredDiaryIndices = diarySnapshots.map(\.index)
            filteredEventIndices = eventSnapshots.map(\.index)
        }
        let filteredDiaryIndexSet = Set(filteredDiaryIndices)
        let filteredEventIndexSet = Set(filteredEventIndices)

        var diaryByDayIndices: [Date: [Int]] = [:]
        for snapshot in diarySnapshots where filteredDiaryIndexSet.contains(snapshot.index) {
            diaryByDayIndices[snapshot.day, default: []].append(snapshot.index)
        }
        for day in diaryByDayIndices.keys {
            diaryByDayIndices[day]?.sort { lhs, rhs in
                guard diarySnapshots.indices.contains(lhs), diarySnapshots.indices.contains(rhs) else {
                    return lhs < rhs
                }
                let left = diarySnapshots[lhs]
                let right = diarySnapshots[rhs]
                if left.startTime != right.startTime {
                    return left.startTime < right.startTime
                }
                let order = left.className.localizedCaseInsensitiveCompare(right.className)
                if order == .orderedSame {
                    return left.index < right.index
                }
                return order == .orderedAscending
            }
        }

        var eventsByDayIndices: [Date: [Int]] = [:]
        for snapshot in eventSnapshots where filteredEventIndexSet.contains(snapshot.index) {
            eventsByDayIndices[snapshot.day, default: []].append(snapshot.index)
        }
        for day in eventsByDayIndices.keys {
            eventsByDayIndices[day]?.sort { lhs, rhs in
                guard eventSnapshots.indices.contains(lhs), eventSnapshots.indices.contains(rhs) else {
                    return lhs < rhs
                }
                let left = eventSnapshots[lhs]
                let right = eventSnapshots[rhs]
                if left.isAllDay != right.isAllDay {
                    return left.isAllDay
                }
                if left.startTime != right.startTime {
                    return left.startTime < right.startTime
                }
                return left.index < right.index
            }
        }

        let allDays = Set(diaryByDayIndices.keys).union(eventsByDayIndices.keys)
        let dayCellViewModelsByDay: [Date: CalendarDayCellComputation] = allDays.reduce(into: [:]) { partialResult, day in
            let eventIndices = eventsByDayIndices[day] ?? []
            let entryIndices = diaryByDayIndices[day] ?? []

            let eventPreviews = eventIndices.prefix(2).compactMap { index -> CalendarPreviewTextComputation? in
                guard eventSnapshots.indices.contains(index) else { return nil }
                return CalendarPreviewTextComputation(
                    id: "event-\(index)",
                    text: eventSnapshots[index].title
                )
            }
            let entryPreviews = entryIndices.prefix(2).compactMap { index -> CalendarPreviewTextComputation? in
                guard diarySnapshots.indices.contains(index) else { return nil }
                return CalendarPreviewTextComputation(
                    id: "entry-\(index)",
                    text: diarySnapshots[index].previewLabel
                )
            }
            let remainingCount = max(0, (eventIndices.count + entryIndices.count) - (eventPreviews.count + entryPreviews.count))

            partialResult[day] = CalendarDayCellComputation(
                eventPreviews: Array(eventPreviews),
                entryPreviews: Array(entryPreviews),
                remainingCount: remainingCount
            )
        }

        let upcomingEventIndices = eventSnapshots
            .filter { snapshot in
                guard filteredEventIndexSet.contains(snapshot.index) else { return false }
                return snapshot.date >= todayStart
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.index < rhs.index
                }
                return lhs.date < rhs.date
            }
            .map(\.index)

        return CalendarComputation(
            selectedClassIndex: selectedClassIndex,
            filteredDiaryIndices: filteredDiaryIndices,
            filteredEventIndices: filteredEventIndices,
            diaryByDayIndices: diaryByDayIndices,
            eventsByDayIndices: eventsByDayIndices,
            dayCellViewModelsByDay: dayCellViewModelsByDay,
            upcomingEventIndices: upcomingEventIndices
        )
    }

    private static func makeDerivedData(
        classes: [SchoolClass],
        diaryEntries: [ClassDiaryEntry],
        events: [CalendarEvent],
        eventSnapshots: [CalendarEventSnapshot],
        computation: CalendarComputation
    ) -> CalendarDerivedData {
        let selectedClass = computation.selectedClassIndex.flatMap { index in
            classes.indices.contains(index) ? classes[index] : nil
        }
        let filteredDiaryEntries = computation.filteredDiaryIndices.compactMap { index in
            diaryEntries.indices.contains(index) ? diaryEntries[index] : nil
        }
        let filteredEvents = computation.filteredEventIndices.compactMap { index in
            events.indices.contains(index) ? events[index] : nil
        }
        let diaryEntriesByDay = computation.diaryByDayIndices.mapValues { indices in
            indices.compactMap { index in
                diaryEntries.indices.contains(index) ? diaryEntries[index] : nil
            }
        }
        let eventsByDay = computation.eventsByDayIndices.mapValues { indices in
            indices.compactMap { index in
                events.indices.contains(index) ? events[index] : nil
            }
        }
        let dayCellViewModelsByDay = computation.dayCellViewModelsByDay.mapValues { model in
            CalendarDayCellViewModel(
                eventPreviews: model.eventPreviews.map { CalendarPreviewText(id: $0.id, text: $0.text) },
                entryPreviews: model.entryPreviews.map { CalendarPreviewText(id: $0.id, text: $0.text) },
                remainingCount: model.remainingCount
            )
        }
        let upcomingEvents = computation.upcomingEventIndices.compactMap { index in
            events.indices.contains(index) ? events[index] : nil
        }
        let upcomingEventViewModels = computation.upcomingEventIndices.compactMap { index -> CalendarUpcomingEventViewModel? in
            guard eventSnapshots.indices.contains(index) else { return nil }
            let snapshot = eventSnapshots[index]
            return CalendarUpcomingEventViewModel(
                id: "upcoming-\(index)",
                title: snapshot.title,
                date: snapshot.date,
                className: snapshot.className
            )
        }

        return CalendarDerivedData(
            selectedClass: selectedClass,
            filteredDiaryEntries: filteredDiaryEntries,
            filteredEvents: filteredEvents,
            diaryEntriesByDay: diaryEntriesByDay,
            eventsByDay: eventsByDay,
            dayCellViewModelsByDay: dayCellViewModelsByDay,
            upcomingEvents: upcomingEvents,
            upcomingEventViewModels: upcomingEventViewModels
        )
    }
}

private struct CalendarClassSnapshot: Sendable {
    let index: Int
    let classKey: String
}

private struct CalendarDiarySnapshot: Sendable {
    let index: Int
    let classKey: String?
    let day: Date
    let startTime: Date
    let className: String
    let previewLabel: String
}

private struct CalendarEventSnapshot: Sendable {
    let index: Int
    let classKey: String?
    let className: String?
    let date: Date
    let day: Date
    let startTime: Date
    let isAllDay: Bool
    let title: String
}

private struct CalendarPreviewTextComputation: Sendable {
    let id: String
    let text: String
}

private struct CalendarDayCellComputation: Sendable {
    let eventPreviews: [CalendarPreviewTextComputation]
    let entryPreviews: [CalendarPreviewTextComputation]
    let remainingCount: Int
}

private struct CalendarComputation: Sendable {
    let selectedClassIndex: Int?
    let filteredDiaryIndices: [Int]
    let filteredEventIndices: [Int]
    let diaryByDayIndices: [Date: [Int]]
    let eventsByDayIndices: [Date: [Int]]
    let dayCellViewModelsByDay: [Date: CalendarDayCellComputation]
    let upcomingEventIndices: [Int]
}
