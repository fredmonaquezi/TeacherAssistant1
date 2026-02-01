import Foundation

enum DashboardTool: Identifiable {
    case attendance
    case gradebook
    case groups
    case randomPicker
    
    var id: String {
        switch self {
        case .attendance: return "attendance"
        case .gradebook: return "gradebook"
        case .groups: return "groups"
        case .randomPicker: return "randomPicker"
        }
    }
}
