import SwiftUI
#if os(macOS)
import AppKit
import Combine
#elseif os(iOS)
import UIKit
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

    @AppStorage(AppPreferencesKeys.defaultLandingSection) private var defaultLandingSectionRawValue: String = AppSection.dashboard.rawValue
    @State private var selectedSection: AppSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var navigationStackResetID = UUID()
    @State private var appViewResetID = UUID()
    @StateObject private var macNavigationState = MacNavigationState()
    
    @StateObject var timerManager = ClassroomTimerManager()
    @StateObject var backupReminderManager = BackupReminderManager()
    
    @EnvironmentObject var languageManager: LanguageManager

    init() {
        let defaultSectionRawValue = UserDefaults.standard.string(forKey: AppPreferencesKeys.defaultLandingSection) ?? AppSection.dashboard.rawValue
        _selectedSection = State(initialValue: AppSection(rawValue: defaultSectionRawValue) ?? .dashboard)
    }

    var body: some View {
        ZStack {
            mainNavigationLayout
                .id(appViewResetID)


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
        .onReceive(NotificationCenter.default.publisher(for: .backupRestoreDidComplete)) { _ in
            handleBackupRestoreCompleted()
        }
        .onChange(of: defaultLandingSectionRawValue) { _, newValue in
            if selectedSection == nil {
                selectedSection = AppSection(rawValue: newValue) ?? .dashboard
            }
        }
    }
    
    // MARK: - Detail View

    @ViewBuilder
    private var mainNavigationLayout: some View {
        #if os(macOS)
        topHeaderLayout(showBackButton: macNavigationState.depth > 0, backAction: goBack)
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            topHeaderLayout(showBackButton: false, backAction: nil)
        } else {
            iPhoneLayout
        }
        #else
        iPhoneLayout
        #endif
    }

    private func topHeaderLayout(showBackButton: Bool, backAction: (() -> Void)?) -> some View {
        VStack(spacing: 0) {
            NavigationHeaderView(
                selectedSection: $selectedSection,
                onNavigate: {
                    // Single-shot reset so top navigation always works
                    // from deep pushed screens without multiple rebuilds.
                    navigationStackResetID = UUID()
                    macNavigationState.reset()
                },
                onBack: backAction,
                showBackButton: showBackButton
            )

            NavigationStack {
                detailView
            }
            .id(navigationStackResetID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(macNavigationState)
        #if os(macOS)
        .background(MacWindowToolbarCleaner())
        .frame(minWidth: 900, minHeight: 650)
        #endif
        .onChange(of: timerManager.isRunning) { _, isRunning in
            if !isRunning {
                selectedSection = .timer
            }
        }
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            if !isExpanded && timerManager.isRunning {
                selectedSection = .dashboard
            }
        }
        .onAppear {
            macNavigationState.reset()
        }
        .onChange(of: selectedSection) { _, _ in
            macNavigationState.reset()
        }
    }

    private var iPhoneLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selectedSection) {
                    ForEach(AppSection.allCases) { section in
                        Label(languageManager.localized(section.rawValue), systemImage: icon(for: section))
                            .tag(section)
                    }
                }

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
            detailView
        }
        .onChange(of: selectedSection) { _, _ in
            columnVisibility = .detailOnly
        }
        .onChange(of: timerManager.isRunning) { _, isRunning in
            if !isRunning {
                selectedSection = .timer
            }
        }
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            if !isExpanded && timerManager.isRunning {
                selectedSection = .dashboard
            }
        }
    }
    
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

    private func goBack() {
        #if os(macOS)
        if macNavigationState.depth > 0 {
            macNavigationState.requestPop()
        }
        #endif
    }

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

    private func handleBackupRestoreCompleted() {
        appViewResetID = UUID()
        navigationStackResetID = UUID()
        #if os(macOS)
        macNavigationState.reset()
        #endif
    }
}

#Preview {
    ContentView()
}

#if os(macOS)
private struct MacWindowToolbarCleaner: NSViewRepresentable {
    final class Coordinator {
        weak var observedWindow: NSWindow?
        var hasConfiguredWindow = false

        deinit {}
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if context.coordinator.observedWindow !== window {
                context.coordinator.observedWindow = window
                context.coordinator.hasConfiguredWindow = false
            }
            configureWindowIfNeeded(window, coordinator: context.coordinator)
            enforceTitleHidden(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if context.coordinator.observedWindow !== window {
                context.coordinator.observedWindow = window
                context.coordinator.hasConfiguredWindow = false
            }
            configureWindowIfNeeded(window, coordinator: context.coordinator)
            enforceTitleHidden(window)
        }
    }

    private func configureWindowIfNeeded(_ window: NSWindow, coordinator: Coordinator) {
        guard !coordinator.hasConfiguredWindow else { return }
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        if window.toolbar != nil {
            window.toolbar = nil
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 900, height: 650)

        // Keep standard macOS traffic-light controls visible with custom header UI.
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for buttonType in buttons {
            guard let button = window.standardWindowButton(buttonType) else { continue }
            button.isHidden = false
            button.alphaValue = 1.0
        }
        coordinator.hasConfiguredWindow = true
    }

    private func enforceTitleHidden(_ window: NSWindow) {
        if window.minSize.width < 900 || window.minSize.height < 650 {
            window.minSize = NSSize(width: 900, height: 650)
        }
        if window.titleVisibility != .hidden {
            window.titleVisibility = .hidden
        }
        if !window.titlebarAppearsTransparent {
            window.titlebarAppearsTransparent = true
        }
        if !window.title.isEmpty {
            window.title = ""
        }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for buttonType in buttons {
            guard let button = window.standardWindowButton(buttonType), button.isHidden else { continue }
            button.isHidden = false
            button.alphaValue = 1.0
        }
    }
}
#endif
