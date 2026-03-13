import Foundation
import SwiftData
import SwiftUI

enum AssignmentEntryStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case excused = "excused"
}

enum AssignmentTrackingState {
    case pending
    case completedOnTime
    case completedLate
    case missing
    case excused

    var title: String {
        switch self {
        case .pending:
            return "Pending".localized
        case .completedOnTime:
            return "Completed".localized
        case .completedLate:
            return "Late".localized
        case .missing:
            return "Missing".localized
        case .excused:
            return "Excused".localized
        }
    }

    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .completedOnTime:
            return .green
        case .completedLate:
            return .yellow
        case .missing:
            return .red
        case .excused:
            return .teal
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .completedOnTime:
            return "checkmark.circle.fill"
        case .completedLate:
            return "exclamationmark.circle.fill"
        case .missing:
            return "xmark.circle.fill"
        case .excused:
            return "checkmark.seal.fill"
        }
    }
}

@Model
class Assignment {
    var id: UUID
    var title: String
    var details: String
    var dueDate: Date
    var createdAt: Date
    var sortOrder: Int

    var unit: Unit?

    @Relationship(deleteRule: .cascade, inverse: \StudentAssignment.assignment)
    var entries: [StudentAssignment] = []

    @Relationship(inverse: \CalendarEvent.assignment)
    var linkedCalendarEvents: [CalendarEvent] = []

    @Relationship(inverse: \ClassDiaryEntry.assignment)
    var linkedDiaryEntries: [ClassDiaryEntry] = []

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        dueDate: Date = Date(),
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        entries: [StudentAssignment] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.entries = entries
    }
}

@Model
class StudentAssignment {
    var student: Student?
    var assignment: Assignment?
    var statusRaw: String
    var submittedAt: Date?
    var notes: String

    init(
        student: Student,
        assignment: Assignment? = nil,
        status: AssignmentEntryStatus = .pending,
        submittedAt: Date? = nil,
        notes: String = ""
    ) {
        self.student = student
        self.assignment = assignment
        self.statusRaw = status.rawValue
        self.submittedAt = submittedAt
        self.notes = notes
    }

    var status: AssignmentEntryStatus {
        get { AssignmentEntryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    func markCompleted(at date: Date = Date()) {
        status = .completed
        submittedAt = date
    }

    func markPending() {
        status = .pending
        submittedAt = nil
    }

    func markExcused() {
        status = .excused
        submittedAt = nil
    }

    func trackingState(relativeTo dueDate: Date, now: Date = Date()) -> AssignmentTrackingState {
        switch status {
        case .excused:
            return .excused
        case .completed:
            guard let submittedAt else { return .completedOnTime }
            return submittedAt > dueDate ? .completedLate : .completedOnTime
        case .pending:
            return dueDate < Calendar.current.startOfDay(for: now) ? .missing : .pending
        }
    }
}

struct AssignmentProgressSummary {
    let totalCount: Int
    let pendingCount: Int
    let completedCount: Int
    let lateCount: Int
    let missingCount: Int
    let excusedCount: Int

    var resolvedCount: Int {
        completedCount + lateCount + excusedCount
    }
}

extension Assignment {
    func ensureEntries(for students: [Student], context: ModelContext) {
        var seenStudentIDs: Set<PersistentIdentifier> = []
        entries = entries.filter { entry in
            guard let studentID = entry.student?.id else { return false }
            return seenStudentIDs.insert(studentID).inserted
        }

        let existingStudentIDs = Set(entries.compactMap { $0.student?.id })
        let orderedStudents = students.sorted { $0.sortOrder < $1.sortOrder }

        for student in orderedStudents where !existingStudentIDs.contains(student.id) {
            let entry = StudentAssignment(student: student, assignment: self)
            entries.append(entry)
            student.assignmentEntries.append(entry)
            context.insert(entry)
        }
    }

    func progressSummary(now: Date = Date()) -> AssignmentProgressSummary {
        var pendingCount = 0
        var completedCount = 0
        var lateCount = 0
        var missingCount = 0
        var excusedCount = 0

        for entry in entries {
            switch entry.trackingState(relativeTo: dueDate, now: now) {
            case .pending:
                pendingCount += 1
            case .completedOnTime:
                completedCount += 1
            case .completedLate:
                lateCount += 1
            case .missing:
                missingCount += 1
            case .excused:
                excusedCount += 1
            }
        }

        return AssignmentProgressSummary(
            totalCount: entries.count,
            pendingCount: pendingCount,
            completedCount: completedCount,
            lateCount: lateCount,
            missingCount: missingCount,
            excusedCount: excusedCount
        )
    }
}
