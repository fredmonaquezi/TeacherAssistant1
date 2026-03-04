import SwiftUI
import SwiftData

@main
struct TeacherAssistantApp: App {
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var bootstrapCoordinator = AppBootstrapCoordinator()

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
                    initializeDefaultRubrics(in: activeContainer)
                }
                .modelContainer(activeContainer)
        } else {
            RecoveryModeView(coordinator: bootstrapCoordinator)
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage.localeIdentifier))
        }
    }
    
    // MARK: - Initialize Default Rubrics
    
    func initializeDefaultRubrics(in container: ModelContainer) {
        createDefaultRubrics(context: container.mainContext)
    }
}
