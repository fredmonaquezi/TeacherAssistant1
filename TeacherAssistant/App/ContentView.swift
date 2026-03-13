import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
import Combine
#elseif os(iOS)
import UIKit
#endif

enum AppSection: String, CaseIterable, Identifiable, Codable {
    case dashboard = "Dashboard"
    case classes = "Classes"
    case library = "Library"
    case attendance = "Attendance"
    case liveCheckIn = "Live Check-In"
    case gradebook = "Gradebook"
    case rubrics = "Manage Rubrics"
    case groups = "Groups"
    case randomPicker = "Random Picker"
    case timer = "Timer"
    case runningRecords = "Running Records"
    case usefulLinks = "Useful Links"
    case calendar = "Calendar"

    var id: String { rawValue }

    static var allCases: [AppSection] {
        [
            .dashboard,
            .classes,
            .attendance,
            .liveCheckIn,
            .gradebook,
            .rubrics,
            .groups,
            .randomPicker,
            .timer,
            .runningRecords,
            .usefulLinks,
            .calendar,
        ]
    }

    static func availableSection(from rawValue: String?) -> AppSection {
        guard let rawValue, let section = AppSection(rawValue: rawValue), allCases.contains(section) else {
            return .dashboard
        }
        return section
    }
}

struct ContentView: View {

    @AppStorage(AppPreferencesKeys.dateFormat) private var dateFormatRawValue: String = AppDateFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.timeFormat) private var timeFormatRawValue: String = AppTimeFormatPreference.system.rawValue
    @AppStorage(AppPreferencesKeys.defaultLandingSection) private var defaultLandingSectionRawValue: String = AppSection.dashboard.rawValue
    @AppStorage(AppPreferencesKeys.motionProfile) private var motionProfileRawValue: String = AppMotionProfile.full.rawValue
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allAssessments: [Assessment]
    @Query private var allAssignments: [Assignment]
    @Query private var allInterventions: [Intervention]
    @Query private var allStudents: [Student]
    @State private var selectedSection: AppSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var navigationStackResetID = UUID()
    @State private var appViewResetID = UUID()
    @StateObject private var macNavigationState = MacNavigationState()
    @State private var saveFailureMessage: String?
    @State private var activeNotificationRoute: AttentionNotificationRoute?
    @State private var handledAttentionMutationIDs: Set<UUID> = []
    
    @StateObject var timerManager = ClassroomTimerManager()
    @StateObject var backupReminderManager = BackupReminderManager()
    @StateObject private var attentionNotificationManager = AttentionNotificationManager.shared
    
    @EnvironmentObject var languageManager: LanguageManager

    init() {
        let defaultSectionRawValue = UserDefaults.standard.string(forKey: AppPreferencesKeys.defaultLandingSection) ?? AppSection.dashboard.rawValue
        _selectedSection = State(initialValue: AppSection.availableSection(from: defaultSectionRawValue))
    }

    private var preferredMotionProfile: AppMotionProfile {
        AppMotionProfile(rawValue: motionProfileRawValue) ?? .full
    }

    private var appMotionContext: AppMotionContext {
        AppMotionContext(
            profile: preferredMotionProfile,
            reduceMotionEnabled: accessibilityReduceMotion,
            prefersDesktopSpacing: {
                #if os(macOS)
                true
                #else
                false
                #endif
            }()
        )
    }

    var body: some View {
        ZStack {
            mainNavigationLayout
                .id(appViewResetID)


            // ⏱️ TIMER OVERLAY LAYER
            if timerManager.isRunning {
                if timerManager.isExpanded {
                    TimerOverlayView(timer: timerManager)
                        .transition(appMotionContext.transition(.overlay))
                } else {
                    VStack {
                        Spacer()
                        MiniTimerView(timer: timerManager)
                    }
                    .transition(appMotionContext.transition(.overlay))
                }
            }

            // ⏰ TIME'S UP OVERLAY
            if timerManager.showTimesUp {
                TimesUpView {
                    timerManager.dismissTimesUpAndReset()
                    selectedSection = .timer   // 👈 FORCE staying in Timer section
                }
                .transition(appMotionContext.transition(.overlay))
            }

        }
        .environment(\.appMotionContext, appMotionContext)
        .animation(appMotionContext.animation(.standard), value: timerManager.isRunning)
        .animation(appMotionContext.animation(.standard), value: timerManager.isExpanded)
        .animation(appMotionContext.animation(.emphasis), value: timerManager.showTimesUp)
        .onReceive(NotificationCenter.default.publisher(for: .backupRestoreDidComplete)) { _ in
            handleBackupRestoreCompleted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .persistenceSaveFailed)) { notification in
            handlePersistenceSaveFailed(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .attentionNotificationRouteRequested)) { notification in
            handleAttentionNotificationRoute(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .attentionNotificationMutationRequested)) { notification in
            handleAttentionNotificationMutation(notification)
        }
        .onChange(of: scenePhase) { _, newValue in
            handleScenePhaseChanged(newValue)
        }
        .onChange(of: allInterventions.count) { _, _ in
            handlePendingAttentionNotificationMutationIfNeeded()
        }
        .onChange(of: defaultLandingSectionRawValue) { _, newValue in
            if selectedSection == nil {
                selectedSection = AppSection.availableSection(from: newValue)
            }
        }
        .onChange(of: dateFormatRawValue) { _, _ in
            refreshForPreferenceChange()
        }
        .onChange(of: timeFormatRawValue) { _, _ in
            refreshForPreferenceChange()
        }
        .alert(
            "Save Failed".localized,
            isPresented: Binding(
                get: { saveFailureMessage != nil },
                set: { if !$0 { saveFailureMessage = nil } }
            )
        ) {
            Button("OK".localized, role: .cancel) { }
        } message: {
            Text(saveFailureMessage ?? "")
        }
        .sheet(item: $activeNotificationRoute) { route in
            notificationDestinationSheet(for: route)
        }
        .task {
            handlePendingAttentionNotificationMutationIfNeeded()
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
                detailContainer
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
            handleTimerRouteChange(isRunning: isRunning, isExpanded: timerManager.isExpanded)
        }
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            handleTimerRouteChange(isRunning: timerManager.isRunning, isExpanded: isExpanded)
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
                        Label(
                            languageManager.localized(section.rawValue),
                            systemImage: ContentSectionCoordinator.icon(for: section)
                        )
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
            detailContainer
        }
        .onChange(of: selectedSection) { _, _ in
            columnVisibility = .detailOnly
        }
        .onChange(of: timerManager.isRunning) { _, isRunning in
            handleTimerRouteChange(isRunning: isRunning, isExpanded: timerManager.isExpanded)
        }
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            handleTimerRouteChange(isRunning: timerManager.isRunning, isExpanded: isExpanded)
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        ContentSectionCoordinator.destination(
            for: selectedSection,
            timerManager: timerManager,
            backupReminderManager: backupReminderManager,
            selectedSection: $selectedSection
        )
    }

    private var detailContainer: some View {
        VStack(spacing: 0) {
            AttentionNotificationScheduler(notificationManager: attentionNotificationManager)
            AttentionReminderBanner(selectedSection: $selectedSection)
            ZStack {
                detailView
                    .id(selectedSection?.rawValue ?? AppSection.dashboard.rawValue)
                    .transition(appMotionContext.transition(.sectionSwitch))
            }
            .animation(appMotionContext.animation(.standard), value: selectedSection)
        }
    }

    // MARK: - Sidebar Navigation

    private func goBack() {
        #if os(macOS)
        if macNavigationState.depth > 0 {
            macNavigationState.requestPop()
        }
        #endif
    }

    private func handleTimerRouteChange(isRunning: Bool, isExpanded: Bool) {
        guard let forcedSection = ContentSectionCoordinator.forcedSectionForTimerState(
            isRunning: isRunning,
            isExpanded: isExpanded
        ) else {
            return
        }
        selectedSection = forcedSection
    }

    private func handleBackupRestoreCompleted() {
        selectedSection = AppSection.availableSection(from: defaultLandingSectionRawValue)
        appViewResetID = UUID()
        navigationStackResetID = UUID()
        #if os(macOS)
        macNavigationState.reset()
        #endif
    }

    private func refreshForPreferenceChange() {
        appViewResetID = UUID()
        navigationStackResetID = UUID()
        #if os(macOS)
        macNavigationState.reset()
        #endif
    }

    private func handlePersistenceSaveFailed(_ notification: Notification) {
        let fallbackMessage = "Your latest changes could not be saved. Please try again.".localized
        let message = (notification.userInfo?[SaveFailureNotificationKeys.message] as? String)?.localized ?? fallbackMessage
        let technicalDetails = (notification.userInfo?[SaveFailureNotificationKeys.appErrorTechnicalDetails] as? String)
            ?? (notification.userInfo?[SaveFailureNotificationKeys.errorDescription] as? String)

        if let technicalDetails, !technicalDetails.isEmpty {
            saveFailureMessage = "\(message)\n\n\(technicalDetails)"
        } else {
            saveFailureMessage = message
        }
    }

    private func handleAttentionNotificationRoute(_ notification: Notification) {
        let route = notification.userInfo?["route"] as? AttentionNotificationRoute
        let rawValue = notification.userInfo?["routeSection"] as? String
        let section = route?.section ?? AppSection.availableSection(from: rawValue)
        selectedSection = section
        navigationStackResetID = UUID()
        #if os(macOS)
        macNavigationState.reset()
        #endif
        activeNotificationRoute = route
    }

    private func handleAttentionNotificationMutation(_ notification: Notification) {
        guard let request = notification.userInfo?["mutationRequest"] as? AttentionNotificationMutationRequest else { return }
        applyAttentionMutation(request)
    }

    private func handlePendingAttentionNotificationMutationIfNeeded() {
        guard let request = attentionNotificationManager.consumePendingMutationRequest() else { return }
        applyAttentionMutation(request)
    }

    private func applyAttentionMutation(_ request: AttentionNotificationMutationRequest) {
        guard handledAttentionMutationIDs.insert(request.id).inserted else { return }

        switch request.action {
        case .reviewAssignmentForToday:
            guard let assignmentID = request.route.assignmentID else {
                handledAttentionMutationIDs.remove(request.id)
                return
            }

            attentionNotificationManager.clearPendingMutationRequest()
            AttentionAssignmentReviewStore.markReviewedToday(assignmentID: assignmentID)

        case .markFollowUpInProgress, .resolveFollowUp:
            guard let interventionID = request.route.interventionID,
                  let intervention = allInterventions.first(where: { $0.id == interventionID }) else {
                handledAttentionMutationIDs.remove(request.id)
                return
            }

            attentionNotificationManager.clearPendingMutationRequest()

            Task {
                await PersistenceWriteCoordinator.shared.perform(
                    context: modelContext,
                    reason: attentionMutationReason(for: request.action)
                ) {
                    switch request.action {
                    case .markFollowUpInProgress:
                        intervention.status = .inProgress
                        intervention.updatedAt = Date()
                    case .resolveFollowUp:
                        intervention.status = .resolved
                        intervention.followUpDate = nil
                        intervention.updatedAt = Date()
                    case .reviewAssignmentForToday:
                        break
                    }
                }
            }
        }
    }

    private func attentionMutationReason(for action: AttentionNotificationMutationAction) -> String {
        switch action {
        case .markFollowUpInProgress:
            return "Notification follow-up marked in progress"
        case .resolveFollowUp:
            return "Notification follow-up resolved"
        case .reviewAssignmentForToday:
            return "Assignment reminder reviewed for today"
        }
    }

    @ViewBuilder
    private func notificationDestinationSheet(for route: AttentionNotificationRoute) -> some View {
        switch route.destinationKind {
        case .assessment:
            if let assessment = resolvedAssessment(for: route) {
                NavigationStack {
                    AssessmentDetailView(assessment: assessment)
                }
            } else {
                unresolvedRouteView
            }
        case .assignment:
            if let assignment = resolvedAssignment(for: route) {
                NavigationStack {
                    AssignmentDetailView(assignment: assignment, showsDismissButton: true)
                }
            } else {
                unresolvedRouteView
            }
        case .studentOverview:
            if let student = resolvedStudent(for: route) {
                NavigationStack {
                    StudentDetailView(student: student)
                }
            } else {
                unresolvedRouteView
            }
        case .studentFollowUp:
            if let student = resolvedStudent(for: route) {
                NavigationStack {
                    StudentDetailView(student: student, initiallyShowingInterventions: true)
                }
            } else {
                unresolvedRouteView
            }
        }
    }

    private var unresolvedRouteView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(.orange)

            Text("Item Not Found".localized)
                .font(.headline)

            Text("The linked item could not be opened. It may have been deleted or changed since the reminder was scheduled.".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(minWidth: 320, minHeight: 220)
    }

    private func resolvedAssessment(for route: AttentionNotificationRoute) -> Assessment? {
        allAssessments.first { assessment in
            guard assessment.title == route.assessmentTitle else { return false }

            if let routeDate = route.assessmentDate,
               !Calendar.current.isDate(assessment.date, inSameDayAs: routeDate) {
                return false
            }

            if let routeUnitID = route.unitID {
                return assessment.unit?.id == routeUnitID
            }

            return true
        }
    }

    private func resolvedAssignment(for route: AttentionNotificationRoute) -> Assignment? {
        guard let assignmentID = route.assignmentID else { return nil }
        return allAssignments.first { $0.id == assignmentID }
    }

    private func resolvedStudent(for route: AttentionNotificationRoute) -> Student? {
        guard let studentUUID = route.studentUUID else { return nil }
        return allStudents.first { $0.uuid == studentUUID }
    }

    private func handleScenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .inactive:
            SnapshotManager.shared.captureLifecycleSnapshotIfNeeded(
                context: modelContext,
                trigger: "scene-inactive"
            )
        case .background:
            SnapshotManager.shared.captureLifecycleSnapshotIfNeeded(
                context: modelContext,
                trigger: "scene-background"
            )
        case .active:
            handlePendingAttentionNotificationMutationIfNeeded()
        @unknown default:
            break
        }
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
