import SwiftUI
import SwiftData

@main
struct TeacherAssistantApp: App {
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var bootstrapCoordinator = AppBootstrapCoordinator()

    init() {
        _ = AttentionNotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        #endif
    }

    @ViewBuilder
    private var rootView: some View {
        if let activeContainer = bootstrapCoordinator.activeContainer {
            ContentView()
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage.localeIdentifier))
                .task {
                    let token = await PerformanceMonitor.shared.beginInterval(.appLaunch)
                    await initializeDefaultRubrics(in: activeContainer)
                    await PerformanceMonitor.shared.endInterval(token, success: true)
                }
                .modelContainer(activeContainer)
        } else {
            RecoveryModeView(coordinator: bootstrapCoordinator)
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage.localeIdentifier))
        }
    }
    
    // MARK: - Initialize Default Rubrics
    
    func initializeDefaultRubrics(in container: ModelContainer) async {
        await createDefaultRubrics(context: container.mainContext)
    }
}
