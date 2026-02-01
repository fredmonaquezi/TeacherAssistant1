import Foundation

enum AttendanceStatus: String, Codable, CaseIterable, Identifiable {
    case absent = "Didn't come"
    case late = "Arrived late"
    case leftEarly = "Left early"
    case present = "Present"

    var id: String { rawValue }
}
