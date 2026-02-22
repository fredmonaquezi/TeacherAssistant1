import Foundation

struct GroupingEngineStudent: Hashable, Identifiable {
    let id: String
    let name: String
    let gender: String
    let needsHelp: Bool
    let isSupportPartner: Bool
    let separationIDs: [String]
}

struct GroupingEngineOptions {
    var balanceGender: Bool
    var balanceAbility: Bool
    var pairSupportPartners: Bool
    var respectSeparations: Bool
    var maxAttempts: Int = 32
}

enum GroupingEngineStrategy {
    case strict
    case relaxedConstraints
    case forcedPlacement
    case failed
}

struct GroupingEngineResult {
    let groups: [[GroupingEngineStudent]]
    let strategy: GroupingEngineStrategy
    let separationConflicts: Int
    let unassignedCount: Int
}

enum GroupingEngine {
    static func generateGroups(
        students: [GroupingEngineStudent],
        preferredGroupSize: Int,
        options: GroupingEngineOptions
    ) -> GroupingEngineResult {
        guard !students.isEmpty else {
            return GroupingEngineResult(
                groups: [],
                strategy: .strict,
                separationConflicts: 0,
                unassignedCount: 0
            )
        }

        let normalizedGroupSize = min(max(preferredGroupSize, 2), 10)
        let targetSizes = targetGroupSizes(studentCount: students.count, preferredSize: normalizedGroupSize)
        let constraints = buildConstraintSet(from: students, enabled: options.respectSeparations)
        let attempts = max(1, options.maxAttempts)

        var bestStrict = CandidateResult.worst
        for _ in 0..<attempts {
            let candidate = buildCandidate(
                students: students,
                targetSizes: targetSizes,
                constraints: constraints,
                options: options,
                allowSeparationConflicts: false,
                forcePlacement: false
            )
            if candidate.isBetter(than: bestStrict) {
                bestStrict = candidate
            }
        }

        if bestStrict.unassignedCount == 0 {
            return GroupingEngineResult(
                groups: bestStrict.groups,
                strategy: .strict,
                separationConflicts: bestStrict.separationConflicts,
                unassignedCount: 0
            )
        }

        var bestRelaxed = CandidateResult.worst
        for _ in 0..<attempts {
            let candidate = buildCandidate(
                students: students,
                targetSizes: targetSizes,
                constraints: constraints,
                options: options,
                allowSeparationConflicts: true,
                forcePlacement: false
            )
            if candidate.isBetter(than: bestRelaxed) {
                bestRelaxed = candidate
            }
        }

        if bestRelaxed.unassignedCount == 0 {
            return GroupingEngineResult(
                groups: bestRelaxed.groups,
                strategy: .relaxedConstraints,
                separationConflicts: bestRelaxed.separationConflicts,
                unassignedCount: 0
            )
        }

        var bestForced = CandidateResult.worst
        for _ in 0..<attempts {
            let candidate = buildCandidate(
                students: students,
                targetSizes: targetSizes,
                constraints: constraints,
                options: options,
                allowSeparationConflicts: true,
                forcePlacement: true
            )
            if candidate.isBetter(than: bestForced) {
                bestForced = candidate
            }
        }

        if bestForced.unassignedCount == 0 {
            return GroupingEngineResult(
                groups: bestForced.groups,
                strategy: .forcedPlacement,
                separationConflicts: bestForced.separationConflicts,
                unassignedCount: 0
            )
        }

        return GroupingEngineResult(
            groups: bestForced.groups,
            strategy: .failed,
            separationConflicts: bestForced.separationConflicts,
            unassignedCount: bestForced.unassignedCount
        )
    }
}

private struct CandidateResult {
    let groups: [[GroupingEngineStudent]]
    let unassignedCount: Int
    let separationConflicts: Int
    let supportPartnerPenalty: Double
    let genderPenalty: Double
    let abilityPenalty: Double

    static let worst = CandidateResult(
        groups: [],
        unassignedCount: Int.max,
        separationConflicts: Int.max,
        supportPartnerPenalty: Double.greatestFiniteMagnitude,
        genderPenalty: Double.greatestFiniteMagnitude,
        abilityPenalty: Double.greatestFiniteMagnitude
    )

    func isBetter(than other: CandidateResult) -> Bool {
        if unassignedCount != other.unassignedCount { return unassignedCount < other.unassignedCount }
        if separationConflicts != other.separationConflicts { return separationConflicts < other.separationConflicts }
        if supportPartnerPenalty != other.supportPartnerPenalty { return supportPartnerPenalty < other.supportPartnerPenalty }
        if genderPenalty != other.genderPenalty { return genderPenalty < other.genderPenalty }
        return abilityPenalty < other.abilityPenalty
    }
}

private struct GeneratedGroup {
    var students: [GroupingEngineStudent] = []
    let targetSize: Int
}

private struct ConstraintPair: Hashable {
    let first: String
    let second: String

    init(_ idA: String, _ idB: String) {
        if idA < idB {
            first = idA
            second = idB
        } else {
            first = idB
            second = idA
        }
    }
}

private func buildCandidate(
    students: [GroupingEngineStudent],
    targetSizes: [Int],
    constraints: Set<ConstraintPair>,
    options: GroupingEngineOptions,
    allowSeparationConflicts: Bool,
    forcePlacement: Bool
) -> CandidateResult {
    var groups = targetSizes.map { GeneratedGroup(targetSize: $0) }
    var unassigned: [GroupingEngineStudent] = []

    let genderRatios = genderTargetRatios(for: students)
    let needsHelpTarget = needsHelpTargetRatio(for: students)
    let orderedStudents = orderedStudentsForGrouping(
        students: students,
        constraints: constraints,
        options: options
    )

    for student in orderedStudents {
        if let targetIndex = bestGroupIndex(
            for: student,
            in: groups,
            constraints: constraints,
            options: options,
            genderRatios: genderRatios,
            needsHelpTargetRatio: needsHelpTarget,
            allowSeparationConflicts: allowSeparationConflicts,
            allowOverfill: false
        ) {
            groups[targetIndex].students.append(student)
        } else {
            unassigned.append(student)
        }
    }

    if forcePlacement, !unassigned.isEmpty {
        for student in unassigned {
            if let leastFilledIndex = leastFilledGroupIndex(in: groups) {
                groups[leastFilledIndex].students.append(student)
            }
        }
        unassigned = []
    }

    let finalGroups = groups.map(\.students).filter { !$0.isEmpty }
    let conflicts = countSeparationConflicts(in: finalGroups, constraints: constraints)

    return CandidateResult(
        groups: finalGroups,
        unassignedCount: unassigned.count,
        separationConflicts: conflicts,
        supportPartnerPenalty: supportPartnerPenalty(in: finalGroups, enabled: options.pairSupportPartners),
        genderPenalty: genderBalancePenalty(in: finalGroups, targetRatios: genderRatios, enabled: options.balanceGender),
        abilityPenalty: abilityBalancePenalty(in: finalGroups, targetRatio: needsHelpTarget, enabled: options.balanceAbility)
    )
}

private func targetGroupSizes(studentCount: Int, preferredSize: Int) -> [Int] {
    guard studentCount > 0 else { return [] }

    let groupCount = max(1, Int(ceil(Double(studentCount) / Double(preferredSize))))
    let baseSize = studentCount / groupCount
    let remainder = studentCount % groupCount

    return (0..<groupCount).map { index in
        baseSize + (index < remainder ? 1 : 0)
    }
}

private func buildConstraintSet(
    from students: [GroupingEngineStudent],
    enabled: Bool
) -> Set<ConstraintPair> {
    guard enabled else { return [] }

    let knownIDs = Set(students.map(\.id))
    var constraints: Set<ConstraintPair> = []

    for student in students {
        for separatedID in student.separationIDs where knownIDs.contains(separatedID) && separatedID != student.id {
            constraints.insert(ConstraintPair(student.id, separatedID))
        }
    }

    return constraints
}

private func orderedStudentsForGrouping(
    students: [GroupingEngineStudent],
    constraints: Set<ConstraintPair>,
    options: GroupingEngineOptions
) -> [GroupingEngineStudent] {
    let shuffled = students.shuffled()
    let randomRank = Dictionary(uniqueKeysWithValues: shuffled.enumerated().map { ($1.id, $0) })
    let separationDegree = separationDegreeMap(from: constraints)

    return shuffled.sorted { lhs, rhs in
        let lhsDegree = separationDegree[lhs.id] ?? 0
        let rhsDegree = separationDegree[rhs.id] ?? 0
        if lhsDegree != rhsDegree {
            return lhsDegree > rhsDegree
        }

        if (options.balanceAbility || options.pairSupportPartners), lhs.needsHelp != rhs.needsHelp {
            return lhs.needsHelp && !rhs.needsHelp
        }

        if options.pairSupportPartners, lhs.isSupportPartner != rhs.isSupportPartner {
            return lhs.isSupportPartner && !rhs.isSupportPartner
        }

        return (randomRank[lhs.id] ?? 0) < (randomRank[rhs.id] ?? 0)
    }
}

private func separationDegreeMap(from constraints: Set<ConstraintPair>) -> [String: Int] {
    var degree: [String: Int] = [:]
    for pair in constraints {
        degree[pair.first, default: 0] += 1
        degree[pair.second, default: 0] += 1
    }
    return degree
}

private func bestGroupIndex(
    for student: GroupingEngineStudent,
    in groups: [GeneratedGroup],
    constraints: Set<ConstraintPair>,
    options: GroupingEngineOptions,
    genderRatios: [String: Double],
    needsHelpTargetRatio: Double,
    allowSeparationConflicts: Bool,
    allowOverfill: Bool
) -> Int? {
    var bestIndex: Int?
    var bestScore = Double.greatestFiniteMagnitude

    for (index, group) in groups.enumerated() {
        if !allowOverfill, group.students.count >= group.targetSize {
            continue
        }

        let conflictCount = group.students.reduce(0) { partialResult, existing in
            partialResult + (constraints.contains(ConstraintPair(existing.id, student.id)) ? 1 : 0)
        }

        if !allowSeparationConflicts, conflictCount > 0 {
            continue
        }

        var score = 0.0

        score += Double(group.students.count) / Double(max(group.targetSize, 1)) * 5
        score += Double(conflictCount) * 1000

        if options.balanceAbility {
            let currentNeedsHelpCount = group.students.filter(\.needsHelp).count
            let projectedNeedsHelpCount = currentNeedsHelpCount + (student.needsHelp ? 1 : 0)
            let projectedSize = group.students.count + 1
            let projectedRatio = Double(projectedNeedsHelpCount) / Double(max(projectedSize, 1))
            score += abs(projectedRatio - needsHelpTargetRatio) * 100
        }

        if options.balanceGender {
            let targetForGender = (genderRatios[student.gender] ?? 0) * Double(group.targetSize)
            let currentGenderCount = group.students.filter { $0.gender == student.gender }.count
            let projectedGenderCount = currentGenderCount + 1
            score += abs(Double(projectedGenderCount) - targetForGender) * 20

            let allowedForGender = Int(ceil(targetForGender))
            if projectedGenderCount > allowedForGender {
                score += 200 + Double(projectedGenderCount - allowedForGender) * 120
            }
        }

        if options.pairSupportPartners {
            let projectedGroup = group.students + [student]
            let projectedHasNeedsHelp = projectedGroup.contains(where: \.needsHelp)
            let projectedHasSupportPartner = projectedGroup.contains(where: \.isSupportPartner)

            if projectedHasNeedsHelp && !projectedHasSupportPartner {
                score += 180
            }

            let groupHasNeedsHelp = group.students.contains(where: \.needsHelp)
            let groupHasSupportPartner = group.students.contains(where: \.isSupportPartner)
            if student.isSupportPartner && groupHasNeedsHelp && !groupHasSupportPartner {
                score -= 90
            }
            if student.needsHelp && groupHasSupportPartner {
                score -= 60
            }
        }

        if score < bestScore {
            bestScore = score
            bestIndex = index
        }
    }

    return bestIndex
}

private func countSeparationConflicts(
    in groups: [[GroupingEngineStudent]],
    constraints: Set<ConstraintPair>
) -> Int {
    guard !constraints.isEmpty else { return 0 }

    var conflicts = 0
    for group in groups where group.count > 1 {
        for i in 0..<(group.count - 1) {
            for j in (i + 1)..<group.count {
                if constraints.contains(ConstraintPair(group[i].id, group[j].id)) {
                    conflicts += 1
                }
            }
        }
    }

    return conflicts
}

private func supportPartnerPenalty(
    in groups: [[GroupingEngineStudent]],
    enabled: Bool
) -> Double {
    guard enabled else { return 0 }

    var penalty = 0.0
    for group in groups where !group.isEmpty {
        let hasNeedsHelp = group.contains(where: \.needsHelp)
        let hasSupportPartner = group.contains(where: \.isSupportPartner)
        if hasNeedsHelp && !hasSupportPartner {
            penalty += 1
        }
    }

    return penalty
}

private func genderBalancePenalty(
    in groups: [[GroupingEngineStudent]],
    targetRatios: [String: Double],
    enabled: Bool
) -> Double {
    guard enabled else { return 0 }

    var penalty = 0.0
    for group in groups where !group.isEmpty {
        for (gender, ratio) in targetRatios {
            let target = ratio * Double(group.count)
            let actual = Double(group.filter { $0.gender == gender }.count)
            penalty += abs(actual - target)
        }
    }

    return penalty
}

private func abilityBalancePenalty(
    in groups: [[GroupingEngineStudent]],
    targetRatio: Double,
    enabled: Bool
) -> Double {
    guard enabled else { return 0 }

    var penalty = 0.0
    for group in groups where !group.isEmpty {
        let actualRatio = Double(group.filter(\.needsHelp).count) / Double(group.count)
        penalty += abs(actualRatio - targetRatio)
    }

    return penalty
}

private func needsHelpTargetRatio(for students: [GroupingEngineStudent]) -> Double {
    guard !students.isEmpty else { return 0 }
    return Double(students.filter(\.needsHelp).count) / Double(students.count)
}

private func genderTargetRatios(for students: [GroupingEngineStudent]) -> [String: Double] {
    guard !students.isEmpty else { return [:] }
    let grouped = Dictionary(grouping: students) { $0.gender }
    return grouped.reduce(into: [:]) { partialResult, pair in
        partialResult[pair.key] = Double(pair.value.count) / Double(students.count)
    }
}

private func leastFilledGroupIndex(in groups: [GeneratedGroup]) -> Int? {
    groups.enumerated().min { lhs, rhs in
        lhs.element.students.count < rhs.element.students.count
    }?.offset
}
