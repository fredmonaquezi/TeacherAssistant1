import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case classes = "Classes"
    case library = "Library"
    case attendance = "Attendance"
    case gradebook = "Gradebook"
    case rubrics = "Manage Rubrics"
    case groups = "Groups"
    case randomPicker = "Random Picker"
    case timer = "Timer"
    case runningRecords = "Running Records"
    case calendar = "Calendar"

    var id: String { rawValue }
}

struct ContentView: View {

    @State private var selectedSection: AppSection? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    @StateObject var timerManager = ClassroomTimerManager()
    @StateObject var backupReminderManager = BackupReminderManager()
    
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // SIDEBAR
                VStack(spacing: 0) {
                    List(selection: $selectedSection) {
                        ForEach(AppSection.allCases) { section in
                            Label(languageManager.localized(section.rawValue), systemImage: icon(for: section))
                                .tag(section)
                        }
                    }
                    
                    // Language selector at the bottom
                    Divider()
                    HStack {
                        Spacer()
                        LanguageToggleButton(languageManager: languageManager)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.05))
                }
                .navigationTitle(languageManager.localized("Teacher Assistant"))
                
            } detail: {
                // DETAIL AREA
                switch selectedSection {
                case .dashboard:
                    DashboardView(
                        timerManager: timerManager,
                        backupReminderManager: backupReminderManager,
                        selectedSection: $selectedSection
                    )

                case .classes:
                    ClassesView()
                    
                case .library:
                    NavigationStack {
                            LibraryRootView()
                        }

                case .attendance:
                    ClassPickerView(tool: .attendance)

                case .gradebook:
                    ClassPickerView(tool: .gradebook)
                    
                case .rubrics:
                    RubricTemplateManagerView()

                case .groups:
                    ClassPickerView(tool: .groups)

                case .randomPicker:
                    ClassPickerView(tool: .randomPicker)

                case .timer:
                    TimerPickerView(timer: timerManager)
                
                case .runningRecords:
                    RunningRecordsView()
                    
                case .calendar:
                    CalendarRootView()

                case .none:
                    Text(languageManager.localized("Select a section"))
                }
            }
            // ✅ When user selects something, collapse sidebar automatically
            .onChange(of: selectedSection) { _, _ in
                columnVisibility = .detailOnly
            }
            .onChange(of: timerManager.isRunning) { _, isRunning in
                if !isRunning {
                    // 🔒 Force staying in Timer section when timer stops
                    selectedSection = .timer
                }
            }
            .onChange(of: timerManager.isExpanded) { _, isExpanded in
                if !isExpanded && timerManager.isRunning {
                    // When user minimizes the timer, go back to Dashboard
                    selectedSection = .dashboard
                }
            }


            // ⏱️ TIMER OVERLAY LAYER
            if timerManager.isRunning {
                if timerManager.isExpanded {
                    TimerOverlayView(timer: timerManager)
                } else {
                    VStack {
                        Spacer()
                        MiniTimerView(timer: timerManager)
                    }
                }
            }

            // ⏰ TIME'S UP OVERLAY
            if timerManager.showTimesUp {
                TimesUpView {
                    timerManager.dismissTimesUpAndReset()
                    selectedSection = .timer   // 👈 FORCE staying in Timer section
                }
            }

        }
    }

    // MARK: - Sidebar Icons

    func icon(for section: AppSection) -> String {
        switch section {
        case .dashboard: return "house"
        case .library: return "books.vertical"
        case .classes: return "person.3.fill"
        case .attendance: return "checklist"
        case .gradebook: return "tablecells"
        case .rubrics: return "doc.text.fill"
        case .groups: return "person.2.fill"
        case .randomPicker: return "die.face.5.fill"
        case .timer: return "timer"
        case .runningRecords: return "doc.text.magnifyingglass"
        case .calendar: return "calendar"
        }
    }
}

#Preview {
    ContentView()
}
