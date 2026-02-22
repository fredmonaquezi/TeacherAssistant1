import Foundation
import SwiftUI

enum PerformanceBand {
    case excellent
    case satisfactory
    case needsWork
    case ungraded
}

enum AssessmentPercentMetrics {
    static let excellentThresholdPercent: Double = 70
    static let satisfactoryThresholdPercent: Double = 50

    static func percent(score: Double, maxScore: Double) -> Double? {
        guard score > 0 else { return nil }
        let sanitizedMax = SecurityHelpers.validateScore(maxScore, min: 1, max: 1000)
        let sanitizedScore = SecurityHelpers.validateScore(score, min: 0, max: sanitizedMax)
        return (sanitizedScore / sanitizedMax) * 100
    }

    static func averagePercent(from results: [StudentResult]) -> Double {
        let valid = results.compactMap { percent(for: $0) }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    static func normalizedOutOfTen(fromPercent percent: Double) -> Double {
        guard percent.isFinite else { return 0 }
        return Swift.max(0, percent) / 10
    }

    static func percentFromNormalizedOutOfTen(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.max(0, value) * 10
    }

    static func band(for percent: Double?) -> PerformanceBand {
        guard let percent else { return .ungraded }
        if percent >= excellentThresholdPercent { return .excellent }
        if percent >= satisfactoryThresholdPercent { return .satisfactory }
        return .needsWork
    }

    static func color(for percent: Double?) -> Color {
        switch band(for: percent) {
        case .excellent: return .green
        case .satisfactory: return .orange
        case .needsWork: return .red
        case .ungraded: return .gray
        }
    }

    static func tintColor(for percent: Double?) -> Color {
        switch band(for: percent) {
        case .excellent: return Color.green.opacity(0.1)
        case .satisfactory: return Color.orange.opacity(0.1)
        case .needsWork: return Color.red.opacity(0.1)
        case .ungraded: return Color.gray.opacity(0.05)
        }
    }

    static func percent(for result: StudentResult) -> Double? {
        let maxScore = result.assessment?.safeMaxScore ?? Assessment.defaultMaxScore
        return percent(score: result.score, maxScore: maxScore)
    }
}

extension Array where Element == StudentResult {
    var averageScore: Double {
        AssessmentPercentMetrics.normalizedOutOfTen(fromPercent: averagePercent)
    }

    var averagePercent: Double {
        AssessmentPercentMetrics.averagePercent(from: self)
    }
}

extension StudentResult {
    var normalizedScoreOutOfTen: Double {
        guard let percent = AssessmentPercentMetrics.percent(for: self) else { return 0 }
        return AssessmentPercentMetrics.normalizedOutOfTen(fromPercent: percent)
    }

    var scorePercent: Double {
        AssessmentPercentMetrics.percent(for: self) ?? 0
    }
}
