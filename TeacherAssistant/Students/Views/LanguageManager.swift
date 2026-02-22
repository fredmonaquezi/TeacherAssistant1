import SwiftUI
import Combine

/// Manages the app's display language
class LanguageManager: ObservableObject {
    static let languageStorageKey = "appLanguage"
    
    enum Language: String, CaseIterable {
        case english = "en"
        case portuguese = "pt-BR"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .portuguese: return "Português"
            }
        }

        var localeIdentifier: String {
            rawValue
        }
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .portuguese: return "🇧🇷"
            }
        }
    }
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageStorageKey)
            // Force UI refresh
            objectWillChange.send()
        }
    }
    
    init() {
        // Load saved language preference
        let normalized = Self.normalizedLanguageCode(UserDefaults.standard.string(forKey: Self.languageStorageKey))
        self.currentLanguage = Language(rawValue: normalized) ?? .english
    }
    
    func toggleLanguage() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentLanguage = (currentLanguage == .english) ? .portuguese : .english
        }
    }
    
    /// Get localized string for current language
    func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    var currentLocale: Locale {
        Locale(identifier: currentLanguage.localeIdentifier)
    }

    static func persistedLocale() -> Locale {
        Locale(identifier: persistedLanguageCode())
    }

    static func persistedLanguageCode() -> String {
        normalizedLanguageCode(UserDefaults.standard.string(forKey: languageStorageKey))
    }

    private static func normalizedLanguageCode(_ rawValue: String?) -> String {
        let savedLanguage = rawValue ?? Language.english.rawValue
        return savedLanguage == "pt" ? Language.portuguese.rawValue : savedLanguage
    }
}
