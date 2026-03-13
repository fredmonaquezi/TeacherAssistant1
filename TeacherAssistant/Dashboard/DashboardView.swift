import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {

    @ObservedObject var timerManager: ClassroomTimerManager
    @ObservedObject var backupReminderManager: BackupReminderManager
    @Binding var selectedSection: AppSection?
    
    @EnvironmentObject var languageManager: LanguageManager

    @Environment(\.modelContext) private var context

    @State private var showingExporter = false
    @State private var exportURL: URL?

    @State private var showingImporter = false
    @State private var pendingImportURL: URL?

    @State private var showingRestoreConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingPreferences = false
    @ObservedObject var attentionNotificationManager = AttentionNotificationManager.shared

    var body: some View {
        #if os(macOS)
        // macOS: No NavigationStack needed, header navigation handles it
        dashboardContent
        #else
        // iOS: Keep NavigationStack for proper navigation
        NavigationStack {
            dashboardContent
        }
        #endif
    }
    
    var dashboardContent: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                TodayDashboardCard(
                    timerManager: timerManager,
                    selectedSection: $selectedSection
                )

                workspacePanels
            }
            
            // MARK: - Backup Reminder Banner
            
            BackupReminderBanner(reminderManager: backupReminderManager)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        #if !os(macOS)
        .navigationTitle("Dashboard".localized)
        #endif
        .onAppear {
            backupReminderManager.checkIfReminderNeeded()
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(attentionNotificationManager: attentionNotificationManager)
        }

        // MARK: - iOS Exporter

        .fileExporter(
            isPresented: $showingExporter,
            document: BackupDocument(url: exportURL),
            contentType: .data,
            defaultFilename: "TeacherAssistant.backup"
        ) { result in
            exportURL = nil
            showingExporter = false

            if case .failure(let error) = result {
                let appError = AppError.backup(stage: .export, underlyingError: error)
                errorMessage = appError.messageForAlert
                showingErrorAlert = true
            }
        }

        // MARK: - Import

        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data]
        ) { result in
            do {
                let url = try result.get()

                // 🔐 VERY IMPORTANT: request permission to access the file
                let canAccess = url.startAccessingSecurityScopedResource()
                if !canAccess {
                    errorMessage = "No permission to access the selected file."
                    showingErrorAlert = true
                    return
                }

                pendingImportURL = url
                showingRestoreConfirmation = true

            } catch {
                let appError = AppError.recovery(
                    action: .selectBackupFile,
                    underlyingError: error
                )
                errorMessage = appError.messageForAlert
                showingErrorAlert = true
            }
        }


        // MARK: - Restore Confirmation

        .alert("Restore Backup?".localized, isPresented: $showingRestoreConfirmation) {
            Button("Cancel".localized, role: .cancel) {
                pendingImportURL = nil
            }

            Button("Restore".localized, role: .destructive) {
                do {
                    if let url = pendingImportURL {
                        try BackupManager.importBackup(from: url, context: context)
                        showingSuccessAlert = true

                        // 🔓 Release permission
                        url.stopAccessingSecurityScopedResource()
                    }
                } catch {
                    let appError = AppError.backup(stage: .import, underlyingError: error)
                    errorMessage = appError.messageForAlert
                    showingErrorAlert = true
                }

                pendingImportURL = nil
            }

        } message: {
            Text("This will DELETE all current data and replace it with the backup. This cannot be undone.".localized)
        }

        // MARK: - Alerts

        .alert("Restore Complete".localized, isPresented: $showingSuccessAlert) {
            Button("OK".localized) { }
        } message: {
            Text("Your data has been successfully restored.".localized)
        }

        .alert("Error".localized, isPresented: $showingErrorAlert) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var workspacePanels: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workspaces".localized)
                    .font(AppTypography.sectionTitle)

                Text("Daily priorities stay in Today. These panels keep the rest of the app close without crowding the dashboard.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                workspaceCard(
                    title: "Planning & Classes".localized,
                    subtitle: "Move into the class, schedule, and grading views you use most.".localized,
                    tint: .blue
                ) {
                    dashboardActionRow(
                        title: "Classes".localized,
                        subtitle: "subjects, units, assignments".localized,
                        icon: "person.3.fill",
                        tint: .blue
                    ) {
                        selectedSection = .classes
                    }

                    dashboardActionRow(
                        title: "Calendar".localized,
                        subtitle: "events and class diary".localized,
                        icon: "calendar",
                        tint: .teal
                    ) {
                        selectedSection = .calendar
                    }

                    dashboardActionRow(
                        title: "Attendance".localized,
                        subtitle: "daily sessions and rosters".localized,
                        icon: "checklist",
                        tint: .green
                    ) {
                        selectedSection = .attendance
                    }

                    dashboardActionRow(
                        title: "Gradebook".localized,
                        subtitle: "assessments and bulk grading".localized,
                        icon: "tablecells",
                        tint: .orange
                    ) {
                        selectedSection = .gradebook
                    }
                }

                workspaceCard(
                    title: "Classroom Tools".localized,
                    subtitle: "Live lesson tools that support grouping, pacing, and participation.".localized,
                    tint: .pink
                ) {
                    dashboardActionRow(
                        title: "Live Check-In".localized,
                        subtitle: "in-class snapshots and checklist evidence".localized,
                        icon: "waveform.path.ecg.rectangle",
                        tint: .indigo
                    ) {
                        selectedSection = .liveCheckIn
                    }

                    dashboardActionRow(
                        title: "Groups".localized,
                        subtitle: "saved and generated groups".localized,
                        icon: "person.2.fill",
                        tint: .purple
                    ) {
                        selectedSection = .groups
                    }

                    dashboardActionRow(
                        title: "Random Picker".localized,
                        subtitle: "choose the next student".localized,
                        icon: "die.face.5.fill",
                        tint: .pink
                    ) {
                        selectedSection = .randomPicker
                    }

                    dashboardActionRow(
                        title: "Timer".localized,
                        subtitle: "lesson pacing and countdowns".localized,
                        icon: "timer",
                        tint: .red
                    ) {
                        selectedSection = .timer
                    }
                }

                workspaceCard(
                    title: "Progress & Resources".localized,
                    subtitle: "Assessment support, reference tools, and student evidence.".localized,
                    tint: .cyan
                ) {
                    dashboardActionRow(
                        title: "Manage Rubrics".localized,
                        subtitle: "criteria and scoring tools".localized,
                        icon: "doc.text.fill",
                        tint: .purple
                    ) {
                        selectedSection = .rubrics
                    }

                    dashboardActionRow(
                        title: "Running Records".localized,
                        subtitle: "reading evidence and notes".localized,
                        icon: "doc.text.magnifyingglass",
                        tint: .cyan
                    ) {
                        selectedSection = .runningRecords
                    }

                    dashboardActionRow(
                        title: "Useful Links".localized,
                        subtitle: "reference sites and resources".localized,
                        icon: "link",
                        tint: .mint
                    ) {
                        selectedSection = .usefulLinks
                    }
                }

                workspaceCard(
                    title: "Settings & Safety".localized,
                    subtitle: "Preferences, backup, and restore live together here.".localized,
                    tint: .indigo
                ) {
                    dashboardActionRow(
                        title: "Preferences".localized,
                        subtitle: "notifications and app defaults".localized,
                        icon: "gearshape.fill",
                        tint: .indigo
                    ) {
                        showingPreferences = true
                    }

                    dashboardActionRow(
                        title: "Backup".localized,
                        subtitle: "export a fresh safety snapshot".localized,
                        icon: "externaldrive.fill",
                        tint: .gray
                    ) {
                        handleBackupAction()
                    }

                    dashboardActionRow(
                        title: "Restore".localized,
                        subtitle: "recover from an earlier backup".localized,
                        icon: "arrow.clockwise.icloud",
                        tint: .gray
                    ) {
                        handleRestoreAction()
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func workspaceCard<Content: View>(
        title: String,
        subtitle: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: tint.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 6,
            shadowY: 3,
            tint: tint
        )
    }

    private func dashboardActionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleBackupAction() {
    #if os(macOS)
        Task { @MainActor in
            MacBackupManager.backup(context: context)
        }
    #else
        do {
            exportURL = try BackupManager.exportBackup(context: context)
            showingExporter = true
        } catch {
            let appError = AppError.backup(stage: .export, underlyingError: error)
            errorMessage = appError.messageForAlert
            showingErrorAlert = true
        }
    #endif
    }

    private func handleRestoreAction() {
    #if os(macOS)
        Task { @MainActor in
            MacBackupManager.restore(context: context)
        }
    #else
        showingImporter = true
    #endif
    }
}
