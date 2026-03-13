import Foundation

enum AppPreferencesKeys {
    static let dateFormat = "preferences.dateFormat"
    static let timeFormat = "preferences.timeFormat"
    static let defaultLandingSection = "preferences.defaultLandingSection"
    static let motionProfile = "preferences.motionProfile"
    static let attentionRemindersEnabled = "preferences.attentionRemindersEnabled"
    static let attentionRemindersLastDismissedDay = "preferences.attentionRemindersLastDismissedDay"
    static let attentionNotificationsEnabled = "preferences.attentionNotificationsEnabled"
    static let attentionNotificationHour = "preferences.attentionNotificationHour"
    static let attentionNotificationMinute = "preferences.attentionNotificationMinute"
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

enum AppMotionProfile: String, CaseIterable, Identifiable, Codable {
    case full
    case subtle
    case reduced

    var id: String { rawValue }
}
