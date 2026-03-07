import Foundation

struct StudentProgressActionCoordinator {
    let onSelectTab: (StudentProgressView.ProgressTab) -> Void
    let onExportFullReport: () -> Void
    let onExportCurrentTab: () -> Void

    func selectTab(_ tab: StudentProgressView.ProgressTab) {
        onSelectTab(tab)
    }

    func exportFullReport() {
        onExportFullReport()
    }

    func exportCurrentTab() {
        onExportCurrentTab()
    }
}
