import SwiftUI
#if os(macOS)
import AppKit
import Combine
#endif

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
    #if os(macOS)
    @State private var navigationStackResetID = UUID()
    @StateObject private var macNavigationState = MacNavigationState()
    #endif
    
    @StateObject var timerManager = ClassroomTimerManager()
    @StateObject var backupReminderManager = BackupReminderManager()
    
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ZStack {
            #if os(macOS)
            // macOS: Custom header navigation
            VStack(spacing: 0) {
                NavigationHeaderView(
                    selectedSection: $selectedSection,
                    onNavigate: {
                        // Single-shot reset so top navigation always works
                        // from deep pushed screens without multiple rebuilds.
                        navigationStackResetID = UUID()
                        macNavigationState.reset()
                    },
                    onBack: goBack,
                    showBackButton: macNavigationState.depth > 0
                )

                // DETAIL AREA
                NavigationStack {
                    detailView
                }
                .id(navigationStackResetID)
                .toolbar(.hidden, for: .windowToolbar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environmentObject(macNavigationState)
            .background(MacWindowToolbarCleaner())
            .frame(minWidth: 900, minHeight: 650)
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
            .onAppear {
                macNavigationState.reset()
            }
            .onChange(of: selectedSection) { _, _ in
                macNavigationState.reset()
            }
            #else
            // iOS/iPadOS: Traditional sidebar navigation
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
                detailView
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
            #endif


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
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(
                timerManager: timerManager,
                backupReminderManager: backupReminderManager,
                selectedSection: $selectedSection
            )
            .macNavigationRoot()

        case .classes:
            ClassesView()
                .macNavigationRoot()
            
        case .library:
            #if os(macOS)
            LibraryRootView()
                .macNavigationRoot()
            #else
            NavigationStack {
                LibraryRootView()
            }
            #endif

        case .attendance:
            ClassPickerView(tool: .attendance)
                .macNavigationRoot()

        case .gradebook:
            ClassPickerView(tool: .gradebook)
                .macNavigationRoot()
            
        case .rubrics:
            RubricTemplateManagerView()
                .macNavigationRoot()

        case .groups:
            ClassPickerView(tool: .groups)
                .macNavigationRoot()

        case .randomPicker:
            ClassPickerView(tool: .randomPicker)
                .macNavigationRoot()

        case .timer:
            TimerPickerView(timer: timerManager)
                .macNavigationRoot()
        
        case .runningRecords:
            RunningRecordsView()
                .macNavigationRoot()
            
        case .calendar:
            CalendarRootView()
                .macNavigationRoot()

        case .none:
            Text(languageManager.localized("Select a section"))
                .macNavigationRoot()
        }
    }

    // MARK: - Sidebar Icons

    #if os(macOS)
    private func goBack() {
        let backActions: [Selector] = [
            Selector(("dismiss:")),
            Selector(("goBack:"))
        ]

        var handled = false
        for action in backActions {
            if NSApp.sendAction(action, to: nil, from: nil) {
                handled = true
                break
            }

            if let responder = NSApp.keyWindow?.firstResponder,
               NSApp.sendAction(action, to: nil, from: responder) {
                handled = true
                break
            }
        }

        // Fallback for cases where SwiftUI does not expose an action target.
        if !handled, macNavigationState.depth > 0 {
            navigationStackResetID = UUID()
            macNavigationState.reset()
        }
    }
    #endif

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

#if os(macOS)
private struct MacWindowToolbarCleaner: NSViewRepresentable {
    final class Coordinator {
        var observer: NSObjectProtocol?
        weak var observedWindow: NSWindow?

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            clean(window)

            guard context.coordinator.observedWindow !== window else { return }
            context.coordinator.observedWindow = window

            if let observer = context.coordinator.observer {
                NotificationCenter.default.removeObserver(observer)
            }
            context.coordinator.observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { _ in
                clean(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            clean(window)
        }
    }

    private func clean(_ window: NSWindow) {
        if window.toolbar != nil {
            window.toolbar = nil
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }
}
#endif
