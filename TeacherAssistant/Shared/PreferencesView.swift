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
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    VStack(alignment: .leading, spacing: 16) {
                        Text(languageManager.localized("Profile & Preferences"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        preferencePickerRow(
                            title: languageManager.localized("Date Format"),
                            systemImage: "calendar",
                            color: .blue
                        ) {
                            Picker(languageManager.localized("Date Format"), selection: dateFormatBinding) {
                                ForEach(AppDateFormatPreference.allCases) { format in
                                    Text(dateFormatLabel(format))
                                        .tag(format)
                                }
                            }
                        }

                        preferencePickerRow(
                            title: languageManager.localized("Time Format"),
                            systemImage: "clock",
                            color: .green
                        ) {
                            Picker(languageManager.localized("Time Format"), selection: timeFormatBinding) {
                                ForEach(AppTimeFormatPreference.allCases) { format in
                                    Text(timeFormatLabel(format))
                                        .tag(format)
                                }
                            }
                        }

                        preferencePickerRow(
                            title: languageManager.localized("Default Landing Section"),
                            systemImage: "square.grid.2x2.fill",
                            color: .indigo
                        ) {
                            Picker(languageManager.localized("Default Landing Section"), selection: landingSectionBinding) {
                                ForEach(AppSection.allCases) { section in
                                    Text(languageManager.localized(section.rawValue))
                                        .tag(section)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            languageManager.localized("Helpful Notes"),
                            systemImage: "info.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.blue)

                        Text(languageManager.localized("Date and time preferences are applied across screens that use app formatting helpers."))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(languageManager.localized("Default landing section is used the next time the app opens."))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)
                }
                .padding()
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
        .frame(minWidth: 560, minHeight: 460)
        #endif
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundColor(.indigo)

            Text(languageManager.localized("Preferences"))
                .font(.title2)
                .fontWeight(.bold)

            Text(languageManager.localized("Customize date, time, and startup behavior for your workflow."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func preferencePickerRow<PickerContent: View>(
        title: String,
        systemImage: String,
        color: Color,
        @ViewBuilder picker: () -> PickerContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            picker()
                .labelsHidden()
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.12))
                .cornerRadius(10)
        }
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
