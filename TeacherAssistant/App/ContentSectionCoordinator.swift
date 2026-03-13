import SwiftUI

enum ContentSectionCoordinator {
    static func icon(for section: AppSection) -> String {
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
        case .usefulLinks: return "link"
        case .calendar: return "calendar"
        }
    }

    static func forcedSectionForTimerState(
        isRunning: Bool,
        isExpanded: Bool
    ) -> AppSection? {
        if !isRunning {
            return .timer
        }

        if !isExpanded {
            return .dashboard
        }

        return nil
    }

    @ViewBuilder
    static func destination(
        for section: AppSection?,
        timerManager: ClassroomTimerManager,
        backupReminderManager: BackupReminderManager,
        selectedSection: Binding<AppSection?>
    ) -> some View {
        switch section {
        case .dashboard:
            DashboardView(
                timerManager: timerManager,
                backupReminderManager: backupReminderManager,
                selectedSection: selectedSection
            )
            .macNavigationRoot()

        case .classes:
            ClassesView(timerManager: timerManager)
                .macNavigationRoot()

        case .library:
            LibraryRootView()
                .macNavigationRoot()

        case .attendance:
            ClassPickerView(tool: .attendance)
                .macNavigationRoot()

        case .gradebook:
            AssessmentsView()
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

        case .usefulLinks:
            UsefulLinksView()
                .macNavigationRoot()

        case .calendar:
            CalendarRootView()
                .macNavigationRoot()

        case .none:
            Text("Select a section".localized)
                .macNavigationRoot()
        }
    }
}
