import Foundation

struct GroupingAbilityProfile {
    let averagePercent: Double?
    let abilityRank: Int
    let isSupportPartner: Bool
}

enum GroupingAbilityProfileBuilder {
    private static let supportPartnerPercentThreshold: Double = 75

    static func buildProfiles(for schoolClass: SchoolClass) -> [String: GroupingAbilityProfile] {
        let classAssessments = schoolClass.subjects
            .flatMap(\.units)
            .flatMap(\.assessments)

        return buildProfiles(
            for: schoolClass.students,
            assessments: classAssessments
        )
    }

    static func buildProfiles(
        for students: [Student],
        assessments: [Assessment]
    ) -> [String: GroupingAbilityProfile] {
        let studentIDs = Set(students.map(\.stableIDString))
        var percentSamplesByStudentID: [String: [Double]] = [:]

        for assessment in assessments {
            let maxScore = assessment.safeMaxScore
            for result in assessment.results {
                guard result.isScored else { continue }
                guard let student = result.student else { continue }
                let studentID = student.stableIDString
                guard studentIDs.contains(studentID) else { continue }
                guard let percent = scorePercent(score: result.score, maxScore: maxScore) else { continue }
                percentSamplesByStudentID[studentID, default: []].append(percent)
            }
        }

        let sortedAverages = students
            .compactMap { averagePercent(from: percentSamplesByStudentID[$0.stableIDString] ?? []) }
            .sorted()

        let lowerThreshold = percentileThreshold(in: sortedAverages, percentile: 0.33)
        let upperThreshold = percentileThreshold(in: sortedAverages, percentile: 0.66)

        return Dictionary(uniqueKeysWithValues: students.map { student in
            let studentID = student.stableIDString
            let averagePercent = averagePercent(from: percentSamplesByStudentID[studentID] ?? [])
            let abilityRank = abilityRank(
                for: averagePercent,
                lowerThreshold: lowerThreshold,
                upperThreshold: upperThreshold
            )
            let isSupportPartner =
                !student.needsHelp &&
                averagePercent != nil &&
                (abilityRank == 2 || (averagePercent ?? 0) >= supportPartnerPercentThreshold)

            return (
                studentID,
                GroupingAbilityProfile(
                    averagePercent: averagePercent,
                    abilityRank: abilityRank,
                    isSupportPartner: isSupportPartner
                )
            )
        })
    }

    private static func scorePercent(score: Double, maxScore: Double) -> Double? {
        guard score.isFinite else { return nil }

        let sanitizedMax = Swift.min(Swift.max(maxScore, 1), 1000)
        let sanitizedScore = Swift.min(Swift.max(score, 0), sanitizedMax)
        return (sanitizedScore / sanitizedMax) * 100
    }

    private static func averagePercent(from samples: [Double]) -> Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    private static func percentileThreshold(in sortedValues: [Double], percentile: Double) -> Double? {
        guard !sortedValues.isEmpty else { return nil }

        let clampedPercentile = Swift.min(Swift.max(percentile, 0), 1)
        let index = Int(floor(Double(sortedValues.count - 1) * clampedPercentile))
        return sortedValues[max(0, index)]
    }

    private static func abilityRank(
        for averagePercent: Double?,
        lowerThreshold: Double?,
        upperThreshold: Double?
    ) -> Int {
        guard let averagePercent else { return 1 }
        guard let lowerThreshold, let upperThreshold else { return 1 }

        if averagePercent <= lowerThreshold { return 0 }
        if averagePercent >= upperThreshold { return 2 }
        return 1
    }
}
