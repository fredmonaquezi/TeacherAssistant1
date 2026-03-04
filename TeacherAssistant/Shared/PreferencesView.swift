import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager

    @AppStorage(AppPreferencesKeys.dateFormat) private var dateFormatRawValue: String = AppDateFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.timeFormat) private var timeFormatRawValue: String = AppTimeFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.defaultLandingSection) private var defaultLandingSectionRawValue: String = AppSection.dashboard.rawValue
    @State private var showingCleanupConfirmation = false
    @State private var showingCleanupReportAlert = false
    @State private var cleanupReportMessage = ""
    @State private var cleanupInProgress = false
    @State private var duplicateCleanupCompleted = DuplicateStudentCleanupService.hasCompleted
    @State private var showingDevelopmentScoreMaintenanceConfirmation = false
    @State private var showingDevelopmentScoreMaintenanceReportAlert = false
    @State private var developmentScoreMaintenanceReportMessage = ""
    @State private var developmentScoreMaintenanceInProgress = false
    @State private var offDeviceBackupFolderPath = OffDeviceBackupManager.shared.destinationDisplayPath ?? ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

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
            get: { AppSection.availableSection(from: defaultLandingSectionRawValue) },
            set: { defaultLandingSectionRawValue = $0.rawValue }
        )
    }

    private var previewDate: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 3
        components.hour = 15
        components.minute = 45
        return calendar.date(from: components) ?? Date()
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

                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            languageManager.localized("Format Preview"),
                            systemImage: "eye.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.green)

                        HStack {
                            Text(languageManager.localized("Date"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(AppDateTimeFormatter.formatDate(previewDate, systemStyle: .full))
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text(languageManager.localized("Time"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(AppDateTimeFormatter.formatTime(previewDate, systemStyle: .short))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            languageManager.localized("Helpful Notes"),
                            systemImage: "info.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.blue)

                        Text(languageManager.localized("Date and time changes refresh the app immediately and apply to screens that use the shared formatting helpers."))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(languageManager.localized("Default landing section is used on next launch and is also re-applied after a restore."))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)

                    #if os(macOS)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(languageManager.localized("Off-Device Backup"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                languageManager.localized("External Backup Folder"),
                                systemImage: "externaldrive.badge.checkmark"
                            )
                            .font(.subheadline)
                            .foregroundColor(.teal)

                            Text(
                                offDeviceBackupFolderPath.isEmpty
                                    ? languageManager.localized("Not configured")
                                    : offDeviceBackupFolderPath
                            )
                            .font(.footnote)
                            .foregroundColor(offDeviceBackupFolderPath.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)

                            Text(
                                languageManager.localized(
                                    "Automatic local snapshots will also be copied here. Keep this folder in iCloud Drive, on an external disk, or another synced location."
                                )
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button(languageManager.localized("Choose Folder")) {
                                chooseOffDeviceBackupFolder()
                            }

                            if !offDeviceBackupFolderPath.isEmpty {
                                Button(languageManager.localized("Clear Folder"), role: .destructive) {
                                    clearOffDeviceBackupFolder()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.teal.opacity(0.08))
                    .cornerRadius(16)
                    #endif

                    VStack(alignment: .leading, spacing: 16) {
                        Text(languageManager.localized("Data Maintenance"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        maintenanceActionRow(
                            title: duplicateCleanupCompleted
                                ? languageManager.localized("Cleanup Duplicates (Done)")
                                : languageManager.localized("Cleanup Duplicates"),
                            detail: languageManager.localized(
                                "One-time safe cleanup that merges duplicate students and preserves linked records."
                            ),
                            systemImage: "person.2.badge.gearshape.fill",
                            tint: .orange,
                            isDisabled: cleanupInProgress || duplicateCleanupCompleted
                        ) {
                            showingCleanupConfirmation = true
                        }

                        maintenanceActionRow(
                            title: languageManager.localized("Repair Dev Scores"),
                            detail: languageManager.localized(
                                "Repairs cached development-score references and reports any scores still missing backup-safe IDs."
                            ),
                            systemImage: "cross.case.fill",
                            tint: .pink,
                            isDisabled: developmentScoreMaintenanceInProgress
                        ) {
                            showingDevelopmentScoreMaintenanceConfirmation = true
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
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
            .alert("Cleanup Duplicate Students?".localized, isPresented: $showingCleanupConfirmation) {
                Button("Cancel".localized, role: .cancel) { }
                Button("Run Cleanup".localized, role: .destructive) {
                    runDuplicateCleanup()
                }
            } message: {
                Text("One-time safe cleanup: merges duplicate students within each class, keeps linked records, removes extra entries, and skips ambiguous same-name students that both contain data.".localized)
            }
            .alert("Duplicate Cleanup Report".localized, isPresented: $showingCleanupReportAlert) {
                Button("OK".localized) { }
            } message: {
                Text(cleanupReportMessage)
            }
            .alert("Repair Development Scores?".localized, isPresented: $showingDevelopmentScoreMaintenanceConfirmation) {
                Button("Cancel".localized, role: .cancel) { }
                Button("Run Repair".localized) {
                    runDevelopmentScoreMaintenance()
                }
            } message: {
                Text(
                    "This safe maintenance pass repairs cached criterion references for development scores and reports any legacy scores that still cannot be backed up because they are missing student references."
                        .localized
                )
            }
            .alert("Development Score Maintenance".localized, isPresented: $showingDevelopmentScoreMaintenanceReportAlert) {
                Button("OK".localized) { }
            } message: {
                Text(developmentScoreMaintenanceReportMessage)
            }
            .alert("Error".localized, isPresented: $showingErrorAlert) {
                Button("OK".localized) { }
            } message: {
                Text(errorMessage)
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 580)
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

    private func maintenanceActionRow(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }

    private func runDuplicateCleanup() {
        cleanupInProgress = true
        defer { cleanupInProgress = false }

        do {
            let report = try DuplicateStudentCleanupService.run(context: context)
            cleanupReportMessage = report.summaryMessage
            duplicateCleanupCompleted = DuplicateStudentCleanupService.hasCompleted
            showingCleanupReportAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func runDevelopmentScoreMaintenance() {
        developmentScoreMaintenanceInProgress = true
        defer { developmentScoreMaintenanceInProgress = false }

        do {
            let report = try DevelopmentScoreMaintenanceService.run(context: context)
            developmentScoreMaintenanceReportMessage = report.summaryMessage
            showingDevelopmentScoreMaintenanceReportAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    #if os(macOS)
    private func chooseOffDeviceBackupFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = languageManager.localized("Choose Backup Folder")
        openPanel.message = languageManager.localized("Choose a folder where automatic snapshots should also be copied.")
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false

        guard openPanel.runModal() == .OK, let selectedURL = openPanel.url else {
            return
        }

        do {
            try OffDeviceBackupManager.shared.storeDestination(url: selectedURL)
            offDeviceBackupFolderPath = OffDeviceBackupManager.shared.destinationDisplayPath ?? ""

            if let latestSnapshotURL = BackupManager.latestLocalSnapshotURL() {
                OffDeviceBackupManager.shared.mirrorSnapshotIfEnabled(
                    snapshotURL: latestSnapshotURL,
                    trigger: "preferences-enable"
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func clearOffDeviceBackupFolder() {
        OffDeviceBackupManager.shared.clearDestination()
        offDeviceBackupFolderPath = ""
    }
    #endif
}
