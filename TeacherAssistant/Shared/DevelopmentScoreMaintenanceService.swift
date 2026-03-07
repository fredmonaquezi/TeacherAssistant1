import Foundation
import SwiftData

struct DevelopmentScoreMaintenanceReport {
    let totalScores: Int
    let repairedCriterionReferenceCount: Int
    let readyForBackupCount: Int
    let missingStudentReferenceCount: Int
    let missingCriterionReferenceCount: Int

    var summaryMessage: String {
        var lines: [String] = [
            "Development score maintenance completed.",
            "",
            "Total scores scanned: \(totalScores)",
            "Criterion references repaired: \(repairedCriterionReferenceCount)",
            "Scores ready for backup: \(readyForBackupCount)",
            "Scores still missing student references: \(missingStudentReferenceCount)",
            "Scores still missing criterion references: \(missingCriterionReferenceCount)",
        ]

        if missingStudentReferenceCount > 0 {
            lines.append("")
            lines.append(
                "Scores missing student references will still be skipped during backup until they are reopened through a healthy in-app path or recreated."
            )
        }

        return lines.joined(separator: "\n")
    }
}

enum DevelopmentScoreMaintenanceError: LocalizedError {
    private static let fallbackMessage = "Your latest changes could not be saved. Please try again."

    case saveFailed(details: String?)

    var errorDescription: String? {
        switch self {
        case let .saveFailed(details):
            return details ?? Self.fallbackMessage
        }
    }
}

@MainActor
enum DevelopmentScoreMaintenanceService {
    static func run(context: ModelContext) throws -> DevelopmentScoreMaintenanceReport {
        let allScores = try context.fetch(FetchDescriptor<DevelopmentScore>())

        var repairedCriterionReferenceCount = 0
        var readyForBackupCount = 0
        var missingStudentReferenceCount = 0
        var missingCriterionReferenceCount = 0

        for score in allScores {
            // The known historical crash path is the stale DevelopmentScore->Student
            // relationship. Only repair the criterion-side cache here, which is already
            // traversed safely in normal UI paths.
            if score.storedCriterionID == nil,
               let criterion = score.criterion,
               score.cacheStableReferences(criterion: criterion)
            {
                repairedCriterionReferenceCount += 1
            }

            if score.storedStudentUUID == nil {
                missingStudentReferenceCount += 1
            }

            if score.storedCriterionID == nil {
                missingCriterionReferenceCount += 1
            }

            if score.hasStableReferenceCache {
                readyForBackupCount += 1
            }
        }

        if context.hasChanges {
            let saveResult = SaveCoordinator.saveResult(
                context: context,
                reason: "Run development score maintenance"
            )

            if !saveResult.didSave {
                throw DevelopmentScoreMaintenanceError.saveFailed(details: saveResult.errorDescription)
            }
        }

        return DevelopmentScoreMaintenanceReport(
            totalScores: allScores.count,
            repairedCriterionReferenceCount: repairedCriterionReferenceCount,
            readyForBackupCount: readyForBackupCount,
            missingStudentReferenceCount: missingStudentReferenceCount,
            missingCriterionReferenceCount: missingCriterionReferenceCount
        )
    }
}
