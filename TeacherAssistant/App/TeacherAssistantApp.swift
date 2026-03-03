import SwiftUI
import SwiftData

@main
struct TeacherAssistantApp: App {
    private static let primaryStoreName = "TeacherAssistant-V5-WithGroups"
    private static let recoveryStoreName = "TeacherAssistant-V6-RecoveredStore"
    
    @StateObject private var languageManager = LanguageManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SchoolClass.self,
            Student.self,
            Subject.self,
            Unit.self,
            Assessment.self,
            StudentResult.self,
            AssessmentCategory.self,
            AssessmentScore.self,
            AttendanceSession.self,
            AttendanceRecord.self,
            LibraryFolder.self,
            LibraryFile.self,
            RubricTemplate.self,
            RubricCategory.self,
            RubricCriterion.self,
            DevelopmentScore.self,
            RunningRecord.self,
            CalendarEvent.self,
            ClassDiaryEntry.self,
            UsefulLink.self,
        ])
        
        func makeConfiguration(named storeName: String) -> ModelConfiguration {
            ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }

        func createContainer(using configuration: ModelConfiguration) throws -> ModelContainer {
            try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        }

        do {
            return try createContainer(
                using: makeConfiguration(named: TeacherAssistantApp.primaryStoreName)
            )
        } catch {
            #if DEBUG
            print("❌ Failed to open primary ModelContainer:")
            print("Error: \(error)")
            print("Error description: \(error.localizedDescription)")
            #endif

            do {
                let fallbackContainer = try createContainer(
                    using: makeConfiguration(named: TeacherAssistantApp.recoveryStoreName)
                )
                #if DEBUG
                print("⚠️ Opened recovery ModelContainer: \(TeacherAssistantApp.recoveryStoreName)")
                #endif
                return fallbackContainer
            } catch {
                #if DEBUG
                print("❌ FATAL ERROR creating recovery ModelContainer:")
                print("Error: \(error)")
                print("Error description: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("Decoding error details: \(decodingError)")
                }
                #endif
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage.localeIdentifier))
                .task {
                    // Initialize default rubric templates asynchronously
                    await initializeDefaultRubrics()
                }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        #endif
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Initialize Default Rubrics
    
    func initializeDefaultRubrics() async {
        // Perform initialization on a background context to avoid blocking the main thread
        await Task.detached(priority: .utility) {
            let context = self.sharedModelContainer.mainContext
            await MainActor.run {
                createDefaultRubrics(context: context)
            }
        }.value
    }
}
