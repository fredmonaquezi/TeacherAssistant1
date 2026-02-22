import Foundation

// MARK: - String Extension for Localization

extension String {
    /// Returns the localized version of this string based on the current language
    var localized: String {
        let languageCode = LanguageManager.persistedLanguageCode()
        
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to system localization
            return NSLocalizedString(self, comment: "")
        }
        
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
    
    /// Returns localized string with formatted arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Date/Time Formatting

enum AppDateTimeFormatter {
    static func formatDate(_ date: Date, systemStyle: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.persistedLocale()

        let preference = AppDateFormatPreference(
            rawValue: UserDefaults.standard.string(forKey: AppPreferencesKeys.dateFormat) ?? ""
        ) ?? .system

        switch preference {
        case .system:
            formatter.dateStyle = systemStyle
            formatter.timeStyle = .none
        case .monthDayYear:
            formatter.dateFormat = "MM/dd/yyyy"
        case .dayMonthYear:
            formatter.dateFormat = "dd/MM/yyyy"
        case .yearMonthDay:
            formatter.dateFormat = "yyyy-MM-dd"
        }

        return formatter.string(from: date)
    }

    static func formatTime(_ date: Date, systemStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.persistedLocale()

        let preference = AppTimeFormatPreference(
            rawValue: UserDefaults.standard.string(forKey: AppPreferencesKeys.timeFormat) ?? ""
        ) ?? .system

        switch preference {
        case .system:
            formatter.dateStyle = .none
            formatter.timeStyle = systemStyle
        case .twelveHour:
            formatter.dateFormat = "h:mm a"
        case .twentyFourHour:
            formatter.dateFormat = "HH:mm"
        }

        return formatter.string(from: date)
    }
}

extension Date {
    var appDateString: String {
        AppDateTimeFormatter.formatDate(self)
    }

    func appDateString(systemStyle: DateFormatter.Style) -> String {
        AppDateTimeFormatter.formatDate(self, systemStyle: systemStyle)
    }

    var appTimeString: String {
        AppDateTimeFormatter.formatTime(self)
    }

    func appTimeString(systemStyle: DateFormatter.Style) -> String {
        AppDateTimeFormatter.formatTime(self, systemStyle: systemStyle)
    }
}

// MARK: - Convenience Function

/// Short-hand function for localization
/// Usage: L("Student Name") instead of "Student Name".localized
func L(_ key: String) -> String {
    return key.localized
}
