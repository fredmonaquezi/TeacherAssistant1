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
        guard score.isFinite else { return 0 }
        return (clampedScore(score) / safeMaxScore) * 10
    }

    func scorePercent(_ score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return (clampedScore(score) / safeMaxScore) * 100
    }
}

extension Assessment {
    func canonicalResult(for student: Student) -> StudentResult? {
        let matches = results.filter { $0.student?.id == student.id }
        return Self.preferredResult(in: matches)
    }

    @discardableResult
    func ensureCanonicalResult(for student: Student, context: ModelContext) -> StudentResult {
        _ = removeDuplicateResultReferences()

        let matches = results.filter { $0.student?.id == student.id }
        if let keeper = Self.preferredResult(in: matches) {
            collapse(matches: matches, keeping: keeper, context: context)
            return keeper
        }

        let newResult = StudentResult(student: student)
        newResult.assessment = self
        results.append(newResult)
        _ = removeDuplicateResultReferences()
        return newResult
    }

    @discardableResult
    func collapseDuplicateResults(context: ModelContext) -> Int {
        var removedCount = removeDuplicateResultReferences()
        var grouped: [PersistentIdentifier: [StudentResult]] = [:]

        for result in results {
            guard let studentID = result.student?.id else { continue }
            grouped[studentID, default: []].append(result)
        }

        for group in grouped.values where group.count > 1 {
            guard let keeper = Self.preferredResult(in: group) else { continue }
            removedCount += group.count - 1
            collapse(matches: group, keeping: keeper, context: context)
        }

        return removedCount
    }

    private func collapse(
        matches: [StudentResult],
        keeping keeper: StudentResult,
        context: ModelContext
    ) {
        let mergedNotes = Self.mergeNotes(from: matches)
        if !mergedNotes.isEmpty {
            keeper.notes = mergedNotes
        }

        for duplicate in matches where duplicate.id != keeper.id {
            if duplicate.isScored, (!keeper.isScored || duplicate.score > keeper.score) {
                keeper.score = duplicate.score
                keeper.hasScore = duplicate.hasScore
            } else if duplicate.hasScore {
                keeper.hasScore = true
            }

            results.removeAll { $0.id == duplicate.id }
            context.delete(duplicate)
        }
    }

    private func removeDuplicateResultReferences() -> Int {
        var seen: Set<PersistentIdentifier> = []
        let originalCount = results.count
        results = results.filter { seen.insert($0.id).inserted }
        return originalCount - results.count
    }

    private static func preferredResult(in results: [StudentResult]) -> StudentResult? {
        results.sorted {
            if $0.isScored != $1.isScored {
                return $0.isScored && !$1.isScored
            }
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            if $0.notes.count != $1.notes.count {
                return $0.notes.count > $1.notes.count
            }
            return String(describing: $0.id) < String(describing: $1.id)
        }.first
    }

    private static func mergeNotes(from results: [StudentResult]) -> String {
        var seen: Set<String> = []
        let notes = results
            .map { $0.notes.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
        return notes.joined(separator: "\n\n")
    }
}
