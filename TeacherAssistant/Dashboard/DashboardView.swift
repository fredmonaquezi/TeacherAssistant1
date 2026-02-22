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
    @State private var showingCleanupConfirmation = false
    @State private var showingCleanupReportAlert = false
    @State private var cleanupReportMessage = ""
    @State private var cleanupInProgress = false
    @State private var duplicateCleanupCompleted = DuplicateStudentCleanupService.hasCompleted

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
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                spacing: 16
            ) {

                DashboardButton(title: "Classes".localized, systemImage: "person.3.fill", color: .blue) {
                    selectedSection = .classes
                }

                DashboardButton(title: "Calendar".localized, systemImage: "calendar", color: .teal) {
                    selectedSection = .calendar
                }

                DashboardButton(title: "Attendance".localized, systemImage: "checklist", color: .green) {
                    selectedSection = .attendance
                }

                DashboardButton(title: "Gradebook".localized, systemImage: "tablecells", color: .orange) {
                    selectedSection = .gradebook
                }
                
                DashboardButton(title: "Manage Rubrics".localized, systemImage: "doc.text.fill", color: .purple) {
                    selectedSection = .rubrics
                }

                DashboardButton(title: "Groups".localized, systemImage: "person.2.fill", color: .purple) {
                    selectedSection = .groups
                }

                DashboardButton(title: "Random Picker".localized, systemImage: "die.face.5.fill", color: .pink) {
                    selectedSection = .randomPicker
                }

                DashboardButton(title: "Timer".localized, systemImage: "timer", color: .red) {
                    selectedSection = .timer
                }

                DashboardButton(title: "Library".localized, systemImage: "books.vertical", color: .brown) {
                    selectedSection = .library
                }
                
                DashboardButton(title: "Running Records".localized, systemImage: "doc.text.magnifyingglass", color: .cyan) {
                    selectedSection = .runningRecords
                }

                DashboardButton(title: "Preferences".localized, systemImage: "gearshape.fill", color: .indigo) {
                    showingPreferences = true
                }

                // MARK: - Backup

                DashboardButton(title: "Backup".localized, systemImage: "externaldrive.fill", color: .gray) {
#if os(macOS)
                    Task { @MainActor in
                        MacBackupManager.backup(context: context)
                    }
#else
                    do {
                        exportURL = try BackupManager.exportBackup(context: context)
                        showingExporter = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingErrorAlert = true
                    }
#endif
                }

                // MARK: - Restore

                DashboardButton(title: "Restore".localized, systemImage: "arrow.clockwise.icloud", color: .gray) {
#if os(macOS)
                    Task { @MainActor in
                        MacBackupManager.restore(context: context)
                    }
#else
                    showingImporter = true
#endif
                }

                DashboardButton(
                    title: duplicateCleanupCompleted ? "Cleanup Duplicates (Done)" : "Cleanup Duplicates",
                    systemImage: "person.2.badge.gearshape.fill",
                    color: .gray
                ) {
                    showingCleanupConfirmation = true
                }
                .disabled(cleanupInProgress || duplicateCleanupCompleted)

            }
            .padding()
            
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
            PreferencesView()
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
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }

                pendingImportURL = nil
            }

        } message: {
            Text("This will DELETE all current data and replace it with the backup. This cannot be undone.".localized)
        }

        .alert("Cleanup Duplicate Students?".localized, isPresented: $showingCleanupConfirmation) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Run Cleanup".localized, role: .destructive) {
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
        } message: {
            Text("One-time safe cleanup: merges duplicate students within each class, keeps linked records, removes extra entries, and skips ambiguous same-name students that both contain data.".localized)
        }

        // MARK: - Alerts

        .alert("Restore Complete".localized, isPresented: $showingSuccessAlert) {
            Button("OK".localized) { }
        } message: {
            Text("Your data has been successfully restored.".localized)
        }

        .alert("Duplicate Cleanup Report".localized, isPresented: $showingCleanupReportAlert) {
            Button("OK".localized) { }
        } message: {
            Text(cleanupReportMessage)
        }

        .alert("Error".localized, isPresented: $showingErrorAlert) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
    }
}
