import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    @AppStorage(AppPreferencesKeys.dateFormat) private var dateFormatRawValue: String = AppDateFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.timeFormat) private var timeFormatRawValue: String = AppTimeFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.defaultLandingSection) private var defaultLandingSectionRawValue: String = AppSection.dashboard.rawValue

    private var dateFormatBinding: Binding<AppDateFormatPreference> {
        Binding(
            get: { AppDateFormatPreference(rawValue: dateFormatRawValue) ?? .system },
            set: { dateFormatRawValue = $0.rawValue }
        )
    }

    private var timeFormatBinding: Binding<AppTimeFormatPreference> {
        Binding(
            get: { AppTimeFormatPreference(rawValue: timeFormatRawValue) ?? .system },
            set: { timeFormatRawValue = $0.rawValue }
        )
    }

    private var landingSectionBinding: Binding<AppSection> {
        Binding(
            get: { AppSection(rawValue: defaultLandingSectionRawValue) ?? .dashboard },
            set: { defaultLandingSectionRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(languageManager.localized("Profile & Preferences")) {
                    Picker(languageManager.localized("Date Format"), selection: dateFormatBinding) {
                        ForEach(AppDateFormatPreference.allCases) { format in
                            Text(dateFormatLabel(format))
                                .tag(format)
                        }
                    }

                    Picker(languageManager.localized("Time Format"), selection: timeFormatBinding) {
                        ForEach(AppTimeFormatPreference.allCases) { format in
                            Text(timeFormatLabel(format))
                                .tag(format)
                        }
                    }

                    Picker(languageManager.localized("Default Landing Section"), selection: landingSectionBinding) {
                        ForEach(AppSection.allCases) { section in
                            Text(languageManager.localized(section.rawValue))
                                .tag(section)
                        }
                    }
                }

                Section {
                    Text(languageManager.localized("Date and time preferences are applied across screens that use app formatting helpers."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(languageManager.localized("Default landing section is used the next time the app opens."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(languageManager.localized("Preferences"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }

    private func dateFormatLabel(_ format: AppDateFormatPreference) -> String {
        switch format {
        case .system:
            return languageManager.localized("System Default")
        case .monthDayYear:
            return "MM/DD/YYYY"
        case .dayMonthYear:
            return "DD/MM/YYYY"
        case .yearMonthDay:
            return "YYYY-MM-DD"
        }
    }

    private func timeFormatLabel(_ format: AppTimeFormatPreference) -> String {
        switch format {
        case .system:
            return languageManager.localized("System Default")
        case .twelveHour:
            return "12-hour (3:45 PM)"
        case .twentyFourHour:
            return "24-hour (15:45)"
        }
    }
}
