import Foundation
import SwiftData

@Model
class AttendanceRecord {
    @Relationship(deleteRule: .nullify)
    var student: Student?

    var statusRaw: String
    var notes: String = ""

    var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? .present }
        set { statusRaw = newValue.rawValue }
    }

    init(student: Student? = nil, status: AttendanceStatus = .present, notes: String = "") {
        self.student = student
        self.statusRaw = status.rawValue
        self.notes = notes
    }
}
