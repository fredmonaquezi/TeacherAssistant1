import Foundation
import SwiftData

@MainActor
enum AssignmentEntryMaintenanceService {
    static func syncAllAssignments(context: ModelContext) -> Int {
        let assignments = (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
        var updatedAssignments = 0

        for assignment in assignments {
            guard let classStudents = assignment.unit?.subject?.schoolClass?.students else { continue }
            let previousEntryCount = assignment.entries.count
            assignment.ensureEntries(for: classStudents, context: context)
            if assignment.entries.count != previousEntryCount {
                updatedAssignments += 1
            }
        }

        return updatedAssignments
    }
}
