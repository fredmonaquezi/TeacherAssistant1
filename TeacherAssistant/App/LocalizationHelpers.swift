import Foundation

// MARK: - String Extension for Localization

extension String {
    /// Returns the localized version of this string based on the current language
    var localized: String {
        // Get the LanguageManager's current language
        let languageCode = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        
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

// MARK: - Convenience Function

/// Short-hand function for localization
/// Usage: L("Student Name") instead of "Student Name".localized
func L(_ key: String) -> String {
    return key.localized
}
