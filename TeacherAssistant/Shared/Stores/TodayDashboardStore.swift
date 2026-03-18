import Foundation
import SwiftData

struct TodayDashboardScheduleItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let timeLabel: String
    let sortDate: Date
    let icon: String
    let isAllDay: Bool
}

struct TodayDashboardBacklogItem: Identifiable {
    let assessment: Assessment
    let remainingCount: Int
    let className: String
    let unitName: String

    var id: PersistentIdentifier {
        assessment.persistentModelID
    }
}

struct TodayDashboardAssignmentItem: Identifiable {
    let assignment: Assignment
    let pendingCount: Int
    let missingCount: Int
    let className: String
    let unitName: String
    let isOverdue: Bool
    let dueLabel: String

    var id: PersistentIdentifier {
        assignment.persistentModelID
    }
}

struct TodayDashboardInterventionItem: Identifiable {
    let intervention: Intervention
    let student: Student
    let followUpDate: Date
    let className: String
    let isOverdue: Bool
    let dueLabel: String

    var id: PersistentIdentifier {
        intervention.persistentModelID
    }
}

struct TodayDashboardDerivedData {
    let scheduleItems: [TodayDashboardScheduleItem]
    let classesNeedingAttendance: [SchoolClass]
    let backlogItems: [TodayDashboardBacklogItem]
    let upcomingAssessments: [Assessment]
    let pendingGradesCount: Int
    let assignmentItems: [TodayDashboardAssignmentItem]
    let dueSoonAssignmentsCount: Int
    let missingAssignmentsCount: Int
    let interventionItems: [TodayDashboardInterventionItem]
    let followUpsCount: Int
    let overdueFollowUpsCount: Int

    static let empty = TodayDashboardDerivedData(
        scheduleItems: [],
        classesNeedingAttendance: [],
        backlogItems: [],
        upcomingAssessments: [],
        pendingGradesCount: 0,
        assignmentItems: [],
        dueSoonAssignmentsCount: 0,
        missingAssignmentsCount: 0,
        interventionItems: [],
        followUpsCount: 0,
        overdueFollowUpsCount: 0
    )
}

enum TodayDashboardStore {
    static func derive(
        classes: [SchoolClass],
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        calendarEvents: [CalendarEvent],
        diaryEntries: [ClassDiaryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayDashboardDerivedData {
        let classSnapshots = makeClassSnapshots(classes: classes)
        let assessmentSnapshots = makeAssessmentSnapshots(assessments: assessments)
        let assignmentSnapshots = makeAssignmentSnapshots(assignments: assignments, now: now, calendar: calendar)
        let interventionSnapshots = makeInterventionSnapshots(interventions: interventions, now: now, calendar: calendar)
        let scheduleSnapshots = makeScheduleSnapshots(events: calendarEvents, diaryEntries: diaryEntries)
        let computation = compute(
            classSnapshots: classSnapshots,
            assessmentSnapshots: assessmentSnapshots,
            assignmentSnapshots: assignmentSnapshots,
            interventionSnapshots: interventionSnapshots,
            scheduleSnapshots: scheduleSnapshots,
            now: now,
            calendar: calendar
        )

        return makeDerivedData(
            classes: classes,
            assessments: assessments,
            assignments: assignments,
            interventions: interventions,
            assessmentSnapshots: assessmentSnapshots,
            assignmentSnapshots: assignmentSnapshots,
            interventionSnapshots: interventionSnapshots,
            scheduleSnapshots: scheduleSnapshots,
            computation: computation
        )
    }

    static func deriveAsync(
        classes: [SchoolClass],
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        calendarEvents: [CalendarEvent],
        diaryEntries: [ClassDiaryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> TodayDashboardDerivedData {
        let classSnapshots = makeClassSnapshots(classes: classes)
        let assessmentSnapshots = makeAssessmentSnapshots(assessments: assessments)
        let assignmentSnapshots = makeAssignmentSnapshots(assignments: assignments, now: now, calendar: calendar)
        let interventionSnapshots = makeInterventionSnapshots(interventions: interventions, now: now, calendar: calendar)
        let scheduleSnapshots = makeScheduleSnapshots(events: calendarEvents, diaryEntries: diaryEntries)

        return await DerivationRunner.runAsync(
            compute: {
                compute(
                    classSnapshots: classSnapshots,
                    assessmentSnapshots: assessmentSnapshots,
                    assignmentSnapshots: assignmentSnapshots,
                    interventionSnapshots: interventionSnapshots,
                    scheduleSnapshots: scheduleSnapshots,
                    now: now,
                    calendar: calendar
                )
            },
            cancelledResult: .empty
        ) { computation in
            makeDerivedData(
                classes: classes,
                assessments: assessments,
                assignments: assignments,
                interventions: interventions,
                assessmentSnapshots: assessmentSnapshots,
                assignmentSnapshots: assignmentSnapshots,
                interventionSnapshots: interventionSnapshots,
                scheduleSnapshots: scheduleSnapshots,
                computation: computation
            )
        }
    }

    private static func makeClassSnapshots(classes: [SchoolClass]) -> [TodayDashboardClassSnapshot] {
        classes.enumerated().map { index, schoolClass in
            TodayDashboardClassSnapshot(
                index: index,
                sortOrder: schoolClass.sortOrder,
                attendanceDates: schoolClass.attendanceSessions.map(\.date)
            )
        }
    }

    private static func makeAssessmentSnapshots(assessments: [Assessment]) -> [TodayDashboardAssessmentSnapshot] {
        assessments.enumerated().map { index, assessment in
            TodayDashboardAssessmentSnapshot(
                index: index,
                date: assessment.date,
                title: assessment.title,
                remainingCount: max(assessment.results.count - assessment.results.filter(\.isResolved).count, 0),
                className: assessment.unit?.subject?.schoolClass?.name ?? "",
                unitName: assessment.unit?.name ?? ""
            )
        }
    }

    private static func makeAssignmentSnapshots(
        assignments: [Assignment],
        now: Date,
        calendar: Calendar
    ) -> [TodayDashboardAssignmentSnapshot] {
        assignments.enumerated().map { index, assignment in
            let progress = assignment.progressSummary(now: now)
            return TodayDashboardAssignmentSnapshot(
                index: index,
                dueDate: assignment.dueDate,
                title: assignment.title,
                pendingCount: progress.pendingCount,
                missingCount: progress.missingCount,
                className: assignment.unit?.subject?.schoolClass?.name ?? "",
                unitName: assignment.unit?.name ?? "",
                startOfToday: calendar.startOfDay(for: now)
            )
        }
    }

    private static func makeInterventionSnapshots(
        interventions: [Intervention],
        now: Date,
        calendar: Calendar
    ) -> [TodayDashboardInterventionSnapshot] {
        let startOfToday = calendar.startOfDay(for: now)
        return interventions.enumerated().compactMap { index, intervention in
            guard intervention.status != .resolved,
                  let followUpDate = intervention.followUpDate,
                  let student = intervention.student else {
                return nil
            }

            return TodayDashboardInterventionSnapshot(
                index: index,
                title: intervention.title,
                studentName: student.name,
                className: student.schoolClass?.name ?? "",
                followUpDate: followUpDate,
                isOpen: intervention.status == .open,
                startOfToday: startOfToday
            )
        }
    }

    private static func makeScheduleSnapshots(
        events: [CalendarEvent],
        diaryEntries: [ClassDiaryEntry]
    ) -> [TodayDashboardScheduleSnapshot] {
        let eventSnapshots = events.map { event in
            TodayDashboardScheduleSnapshot(
                title: event.title,
                detail: contextLine(
                    className: event.schoolClass?.name,
                    secondary: contextualDetail(
                        primary: event.assignment?.title,
                        secondary: event.details
                    )
                ),
                date: event.date,
                startTime: event.startTime,
                endTime: event.endTime,
                isAllDay: event.isAllDay,
                icon: event.isAllDay ? "calendar" : "clock"
            )
        }

        let diarySnapshots = diaryEntries.map { entry in
            TodayDashboardScheduleSnapshot(
                title: firstNonEmpty(entry.plan, fallback: "Class Diary"),
                detail: contextLine(
                    className: entry.schoolClass?.name,
                    secondary: contextualDetail(
                        primary: entry.assignment?.title,
                        secondary: entry.subject?.name ?? entry.unit?.name ?? entry.notes
                    )
                ),
                date: entry.date,
                startTime: entry.startTime,
                endTime: entry.endTime,
                isAllDay: false,
                icon: "text.book.closed"
            )
        }

        return eventSnapshots + diarySnapshots
    }

    nonisolated private static func compute(
        classSnapshots: [TodayDashboardClassSnapshot],
        assessmentSnapshots: [TodayDashboardAssessmentSnapshot],
        assignmentSnapshots: [TodayDashboardAssignmentSnapshot],
        interventionSnapshots: [TodayDashboardInterventionSnapshot],
        scheduleSnapshots: [TodayDashboardScheduleSnapshot],
        now: Date,
        calendar: Calendar
    ) -> TodayDashboardComputation {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let nextWeekBoundary = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfTomorrow

        let classesNeedingAttendanceIndices = classSnapshots
            .filter { snapshot in
                !snapshot.attendanceDates.contains { calendar.isDate($0, inSameDayAs: startOfToday) }
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.index < rhs.index
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map(\.index)

        let scheduleItems = scheduleSnapshots
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .map { snapshot in
                TodayDashboardScheduleComputation(
                    title: snapshot.title,
                    detail: snapshot.detail,
                    timeLabel: formattedTimeRange(
                        date: snapshot.date,
                        startTime: snapshot.startTime,
                        endTime: snapshot.endTime,
                        isAllDay: snapshot.isAllDay,
                        fallback: "Planned class"
                    ),
                    sortDate: combinedDate(for: snapshot.date, time: snapshot.startTime, calendar: calendar),
                    icon: snapshot.icon,
                    isAllDay: snapshot.isAllDay
                )
            }
            .sorted { lhs, rhs in
                if lhs.sortDate != rhs.sortDate {
                    return lhs.sortDate < rhs.sortDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        let backlogIndices = assessmentSnapshots
            .filter { $0.remainingCount > 0 }
            .sorted { lhs, rhs in
                if lhs.remainingCount != rhs.remainingCount {
                    return lhs.remainingCount > rhs.remainingCount
                }
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        let upcomingAssessmentIndices = assessmentSnapshots
            .filter { $0.date >= startOfToday && $0.date < nextWeekBoundary }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        let assignmentIndices = assignmentSnapshots
            .filter { $0.outstandingCount > 0 && $0.dueDate < nextWeekBoundary }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue && !rhs.isOverdue
                }
                if lhs.missingCount != rhs.missingCount {
                    return lhs.missingCount > rhs.missingCount
                }
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.index)

        let interventionIndices = interventionSnapshots
            .filter { $0.followUpDate < nextWeekBoundary }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue && !rhs.isOverdue
                }
                if lhs.followUpDate != rhs.followUpDate {
                    return lhs.followUpDate < rhs.followUpDate
                }
                if lhs.isOpen != rhs.isOpen {
                    return lhs.isOpen
                }
                return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
            }
            .map(\.index)

        let missingAssignmentsCount = assignmentSnapshots.reduce(0) { $0 + $1.missingCount }
        let followUpsCount = interventionIndices.count
        let overdueFollowUpsCount = interventionSnapshots.filter(\.isOverdue).count
        let pendingGradesCount = assessmentSnapshots.reduce(0) { $0 + $1.remainingCount }
        let dueSoonAssignmentsCount = assignmentSnapshots.filter { !$0.isOverdue && $0.outstandingCount > 0 && $0.dueDate < nextWeekBoundary }.count

        return TodayDashboardComputation(
            scheduleItems: scheduleItems,
            classesNeedingAttendanceIndices: classesNeedingAttendanceIndices,
            backlogIndices: backlogIndices,
            upcomingAssessmentIndices: upcomingAssessmentIndices,
            pendingGradesCount: pendingGradesCount,
            assignmentIndices: assignmentIndices,
            dueSoonAssignmentsCount: dueSoonAssignmentsCount,
            missingAssignmentsCount: missingAssignmentsCount,
            interventionIndices: interventionIndices,
            followUpsCount: followUpsCount,
            overdueFollowUpsCount: overdueFollowUpsCount
        )
    }

    private static func makeDerivedData(
        classes: [SchoolClass],
        assessments: [Assessment],
        assignments: [Assignment],
        interventions: [Intervention],
        assessmentSnapshots: [TodayDashboardAssessmentSnapshot],
        assignmentSnapshots: [TodayDashboardAssignmentSnapshot],
        interventionSnapshots: [TodayDashboardInterventionSnapshot],
        scheduleSnapshots: [TodayDashboardScheduleSnapshot],
        computation: TodayDashboardComputation
    ) -> TodayDashboardDerivedData {
        let classesNeedingAttendance = computation.classesNeedingAttendanceIndices.compactMap { classes[safe: $0] }
        let backlogItems = computation.backlogIndices.compactMap { index -> TodayDashboardBacklogItem? in
            guard let assessment = assessments[safe: index],
                  let snapshot = assessmentSnapshots[safe: index] else {
                return nil
            }
            return TodayDashboardBacklogItem(
                assessment: assessment,
                remainingCount: snapshot.remainingCount,
                className: snapshot.className,
                unitName: snapshot.unitName
            )
        }
        let upcomingAssessments = computation.upcomingAssessmentIndices.compactMap { assessments[safe: $0] }
        let assignmentItems = computation.assignmentIndices.compactMap { index -> TodayDashboardAssignmentItem? in
            guard let assignment = assignments[safe: index],
                  let snapshot = assignmentSnapshots[safe: index] else {
                return nil
            }
            return TodayDashboardAssignmentItem(
                assignment: assignment,
                pendingCount: snapshot.pendingCount,
                missingCount: snapshot.missingCount,
                className: snapshot.className,
                unitName: snapshot.unitName,
                isOverdue: snapshot.isOverdue,
                dueLabel: assignmentDueLabel(
                    dueDate: snapshot.dueDate,
                    startOfToday: snapshot.startOfToday,
                    calendar: .current
                )
            )
        }
        let interventionItems = computation.interventionIndices.compactMap { index -> TodayDashboardInterventionItem? in
            guard let intervention = interventions[safe: index],
                  let snapshot = interventionSnapshots.first(where: { $0.index == index }),
                  let student = intervention.student else {
                return nil
            }
            return TodayDashboardInterventionItem(
                intervention: intervention,
                student: student,
                followUpDate: snapshot.followUpDate,
                className: snapshot.className,
                isOverdue: snapshot.isOverdue,
                dueLabel: interventionFollowUpLabel(
                    followUpDate: snapshot.followUpDate,
                    startOfToday: snapshot.startOfToday,
                    calendar: .current
                )
            )
        }

        return TodayDashboardDerivedData(
            scheduleItems: computation.scheduleItems.map {
                TodayDashboardScheduleItem(
                    title: $0.title,
                    detail: $0.detail,
                    timeLabel: $0.timeLabel,
                    sortDate: $0.sortDate,
                    icon: $0.icon,
                    isAllDay: $0.isAllDay
                )
            },
            classesNeedingAttendance: classesNeedingAttendance,
            backlogItems: backlogItems,
            upcomingAssessments: upcomingAssessments,
            pendingGradesCount: computation.pendingGradesCount,
            assignmentItems: assignmentItems,
            dueSoonAssignmentsCount: computation.dueSoonAssignmentsCount,
            missingAssignmentsCount: computation.missingAssignmentsCount,
            interventionItems: interventionItems,
            followUpsCount: computation.followUpsCount,
            overdueFollowUpsCount: computation.overdueFollowUpsCount
        )
    }

    nonisolated private static func combinedDate(for date: Date, time: Date?, calendar: Calendar) -> Date {
        guard let time else { return date }
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    nonisolated private static func formattedTimeRange(
        date: Date,
        startTime: Date?,
        endTime: Date?,
        isAllDay: Bool,
        fallback: String
    ) -> String {
        if isAllDay {
            return "All day".localized
        }
        if let startTime, let endTime {
            let start = combinedDate(for: date, time: startTime, calendar: .current)
            let end = combinedDate(for: date, time: endTime, calendar: .current)
            return "\(start.appTimeString(systemStyle: .short)) - \(end.appTimeString(systemStyle: .short))"
        }
        if let startTime {
            return combinedDate(for: date, time: startTime, calendar: .current).appTimeString(systemStyle: .short)
        }
        return fallback.localized
    }

    nonisolated private static func contextLine(className: String?, secondary: String?) -> String {
        [className, cleanedSnippet(secondary)]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    nonisolated private static func cleanedSnippet(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= 48 {
            return trimmed
        }
        return String(trimmed.prefix(45)) + "..."
    }

    nonisolated private static func contextualDetail(primary: String?, secondary: String?) -> String? {
        let combined = [cleanedSnippet(primary), cleanedSnippet(secondary)]
            .compactMap { $0 }
            .joined(separator: " • ")
        return combined.isEmpty ? nil : combined
    }

    nonisolated private static func firstNonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback.localized : trimmed
    }

    nonisolated private static func assignmentDueLabel(
        dueDate: Date,
        startOfToday: Date,
        calendar: Calendar
    ) -> String {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        if dueDate < startOfToday {
            return "Overdue".localized
        }
        if calendar.isDate(dueDate, inSameDayAs: startOfToday) {
            return "Due Today".localized
        }
        if calendar.isDate(dueDate, inSameDayAs: startOfTomorrow) {
            return "Due Tomorrow".localized
        }
        return "Due Soon".localized
    }

    nonisolated private static func interventionFollowUpLabel(
        followUpDate: Date,
        startOfToday: Date,
        calendar: Calendar
    ) -> String {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        if followUpDate < startOfToday {
            return "Overdue".localized
        }
        if calendar.isDate(followUpDate, inSameDayAs: startOfToday) {
            return "Today".localized
        }
        if calendar.isDate(followUpDate, inSameDayAs: startOfTomorrow) {
            return "Tomorrow".localized
        }
        return "This Week".localized
    }
}

private struct TodayDashboardClassSnapshot: Sendable {
    let index: Int
    let sortOrder: Int
    let attendanceDates: [Date]
}

private struct TodayDashboardAssessmentSnapshot: Sendable {
    let index: Int
    let date: Date
    let title: String
    let remainingCount: Int
    let className: String
    let unitName: String
}

private struct TodayDashboardAssignmentSnapshot: Sendable {
    let index: Int
    let dueDate: Date
    let title: String
    let pendingCount: Int
    let missingCount: Int
    let className: String
    let unitName: String
    let startOfToday: Date

    nonisolated var outstandingCount: Int {
        pendingCount + missingCount
    }

    nonisolated var isOverdue: Bool {
        dueDate < startOfToday
    }
}

private struct TodayDashboardInterventionSnapshot: Sendable {
    let index: Int
    let title: String
    let studentName: String
    let className: String
    let followUpDate: Date
    let isOpen: Bool
    let startOfToday: Date

    nonisolated var isOverdue: Bool {
        followUpDate < startOfToday
    }
}

private struct TodayDashboardScheduleSnapshot: Sendable {
    let title: String
    let detail: String
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let isAllDay: Bool
    let icon: String
}

private struct TodayDashboardScheduleComputation: Sendable {
    let title: String
    let detail: String
    let timeLabel: String
    let sortDate: Date
    let icon: String
    let isAllDay: Bool
}

private struct TodayDashboardComputation: Sendable {
    let scheduleItems: [TodayDashboardScheduleComputation]
    let classesNeedingAttendanceIndices: [Int]
    let backlogIndices: [Int]
    let upcomingAssessmentIndices: [Int]
    let pendingGradesCount: Int
    let assignmentIndices: [Int]
    let dueSoonAssignmentsCount: Int
    let missingAssignmentsCount: Int
    let interventionIndices: [Int]
    let followUpsCount: Int
    let overdueFollowUpsCount: Int
}
