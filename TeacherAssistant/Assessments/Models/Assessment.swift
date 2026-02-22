import Foundation
import SwiftData

@Model
class Assessment {
    static let defaultMaxScore: Double = 10

    var title: String
    var details: String
    var date: Date
    var maxScore: Double = 10
    var sortOrder: Int

    var unit: Unit?

    @Relationship(deleteRule: .cascade, inverse: \StudentResult.assessment)
    var results: [StudentResult] = []

    init(
        title: String,
        details: String = "",
        date: Date = Date(),
        maxScore: Double = 10,
        results: [StudentResult] = []
    ) {
        self.title = title
        self.details = details
        self.date = date
        self.maxScore = maxScore
        self.results = results
        self.unit = nil
        self.sortOrder = 0
    }

    var safeMaxScore: Double {
        guard maxScore.isFinite else { return Self.defaultMaxScore }
        return Swift.min(Swift.max(maxScore, 1), 1000)
    }

    func clampedScore(_ score: Double) -> Double {
        SecurityHelpers.validateScore(score, min: 0, max: safeMaxScore)
    }

    func normalizedScoreOutOfTen(_ score: Double) -> Double {
        guard score > 0 else { return 0 }
        return (clampedScore(score) / safeMaxScore) * 10
    }

    func scorePercent(_ score: Double) -> Double {
        guard score > 0 else { return 0 }
        return (clampedScore(score) / safeMaxScore) * 100
    }
}
