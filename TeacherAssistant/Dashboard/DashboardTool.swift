import Foundation

enum DashboardTool: Identifiable {
    case attendance
    case liveCheckIn
    case gradebook
    case groups
    case randomPicker
    
    var id: String {
        switch self {
        case .attendance: return "attendance"
        case .liveCheckIn: return "liveCheckIn"
        case .gradebook: return "gradebook"
        case .groups: return "groups"
        case .randomPicker: return "randomPicker"
        }
    }
}
