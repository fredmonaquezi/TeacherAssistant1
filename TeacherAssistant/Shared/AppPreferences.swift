import Foundation

enum AppPreferencesKeys {
    static let dateFormat = "preferences.dateFormat"
    static let timeFormat = "preferences.timeFormat"
    static let defaultLandingSection = "preferences.defaultLandingSection"
    static let offDeviceBackupBookmark = "preferences.offDeviceBackupBookmark"
    static let offDeviceBackupPath = "preferences.offDeviceBackupPath"
}

enum AppDateFormatPreference: String, CaseIterable, Identifiable, Codable {
    case system
    case monthDayYear
    case dayMonthYear
    case yearMonthDay

    var id: String { rawValue }
}

enum AppTimeFormatPreference: String, CaseIterable, Identifiable, Codable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }
}
