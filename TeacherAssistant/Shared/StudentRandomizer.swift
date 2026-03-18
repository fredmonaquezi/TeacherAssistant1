import CryptoKit
import Foundation

enum RandomPickerDefaultsKeys {
    static let fairHistoryData = "randomPickerFairHistoryData"
    static let roleCycleData = "randomPickerRoleCycleData"
}

struct StudentRandomizerRoleState {
    let availableIDs: Set<String>
    let usedIDs: Set<String>
}

enum StudentRandomizer {
    private struct FairHistoryStore: Codable {
        var scopes: [String: [String]] = [:]
    }

    private struct RoleCycleStore: Codable {
        var scopes: [String: [String]] = [:]
    }

    static func generalScope(for schoolClass: SchoolClass) -> String {
        "general::\(classScopeToken(for: schoolClass))"
    }

    static func roleScope(for schoolClass: SchoolClass, category: String) -> String {
        "role::\(classScopeToken(for: schoolClass))::\(normalizedToken(for: category))"
    }

    static func pickFairStudent(
        from students: [Student],
        scope: String,
        defaults: UserDefaults = .standard
    ) -> Student? {
        let roster = uniqueStudents(from: students)
        guard !roster.isEmpty else { return nil }

        var fairHistoryStore = loadFairHistory(from: defaults)
        let candidateIDs = roster.map(\.stableIDString)
        guard let pickedID = chooseCandidateID(from: candidateIDs, history: fairHistoryStore.scopes[scope] ?? []) else {
            return nil
        }

        fairHistoryStore.scopes[scope] = updatedHistory(
            appending: pickedID,
            to: fairHistoryStore.scopes[scope] ?? []
        )
        saveFairHistory(fairHistoryStore, to: defaults)
        return roster.first { $0.stableIDString == pickedID }
    }

    static func pickFairStudents(
        count: Int,
        from students: [Student],
        scope: String,
        defaults: UserDefaults = .standard
    ) -> [Student] {
        let roster = uniqueStudents(from: students)
        guard !roster.isEmpty else { return [] }

        let requestedCount = max(1, min(count, roster.count))
        var fairHistoryStore = loadFairHistory(from: defaults)
        var workingHistory = fairHistoryStore.scopes[scope] ?? []
        var remaining = roster
        var winners: [Student] = []

        for _ in 0..<requestedCount {
            let candidateIDs = remaining.map(\.stableIDString)
            guard let pickedID = chooseCandidateID(from: candidateIDs, history: workingHistory),
                  let pickedStudent = remaining.first(where: { $0.stableIDString == pickedID }) else {
                break
            }

            winners.append(pickedStudent)
            workingHistory = updatedHistory(appending: pickedID, to: workingHistory)
            remaining.removeAll { $0.stableIDString == pickedID }
        }

        fairHistoryStore.scopes[scope] = workingHistory
        saveFairHistory(fairHistoryStore, to: defaults)
        return winners
    }

    static func roleState(
        from students: [Student],
        scope: String,
        defaults: UserDefaults = .standard
    ) -> StudentRandomizerRoleState {
        let roster = uniqueStudents(from: students)
        let rosterIDs = Set(roster.map(\.stableIDString))
        let usedIDs = filteredRoleCycleIDs(for: scope, matching: rosterIDs, defaults: defaults)

        if usedIDs.count >= rosterIDs.count && !rosterIDs.isEmpty {
            return StudentRandomizerRoleState(availableIDs: [], usedIDs: rosterIDs)
        }

        let usedSet = Set(usedIDs)
        let availableIDs = Set(rosterIDs.subtracting(usedSet))
        return StudentRandomizerRoleState(availableIDs: availableIDs, usedIDs: usedSet)
    }

    static func pickNextRoleStudent(
        from students: [Student],
        scope: String,
        defaults: UserDefaults = .standard
    ) -> Student? {
        let roster = uniqueStudents(from: students)
        guard !roster.isEmpty else { return nil }

        var roleCycleStore = loadRoleCycles(from: defaults)
        let rosterIDs = Set(roster.map(\.stableIDString))
        var usedIDs = (roleCycleStore.scopes[scope] ?? []).filter { rosterIDs.contains($0) }

        if usedIDs.count >= roster.count {
            return nil
        }

        let usedSet = Set(usedIDs)
        let availableStudents = roster.filter { !usedSet.contains($0.stableIDString) }
        guard !availableStudents.isEmpty else { return nil }

        var fairHistoryStore = loadFairHistory(from: defaults)
        let candidateIDs = availableStudents.map(\.stableIDString)
        guard let pickedID = chooseCandidateID(from: candidateIDs, history: fairHistoryStore.scopes[scope] ?? []) else {
            return nil
        }

        usedIDs.append(pickedID)
        roleCycleStore.scopes[scope] = usedIDs
        fairHistoryStore.scopes[scope] = updatedHistory(appending: pickedID, to: fairHistoryStore.scopes[scope] ?? [])

        saveRoleCycles(roleCycleStore, to: defaults)
        saveFairHistory(fairHistoryStore, to: defaults)
        return availableStudents.first { $0.stableIDString == pickedID }
    }

    static func clearRoleCycle(
        scope: String,
        defaults: UserDefaults = .standard
    ) {
        var roleCycleStore = loadRoleCycles(from: defaults)
        roleCycleStore.scopes.removeValue(forKey: scope)
        saveRoleCycles(roleCycleStore, to: defaults)
    }

    static func undoRolePick(
        studentID: String,
        scope: String,
        defaults: UserDefaults = .standard
    ) {
        var roleCycleStore = loadRoleCycles(from: defaults)
        if var usedIDs = roleCycleStore.scopes[scope],
           let index = usedIDs.lastIndex(of: studentID) {
            usedIDs.remove(at: index)
            if usedIDs.isEmpty {
                roleCycleStore.scopes.removeValue(forKey: scope)
            } else {
                roleCycleStore.scopes[scope] = usedIDs
            }
            saveRoleCycles(roleCycleStore, to: defaults)
        }

        var fairHistoryStore = loadFairHistory(from: defaults)
        if var history = fairHistoryStore.scopes[scope],
           let index = history.lastIndex(of: studentID) {
            history.remove(at: index)
            if history.isEmpty {
                fairHistoryStore.scopes.removeValue(forKey: scope)
            } else {
                fairHistoryStore.scopes[scope] = history
            }
            saveFairHistory(fairHistoryStore, to: defaults)
        }
    }

    static func importLegacyRoleCycle(
        ids: [String],
        scope: String,
        defaults: UserDefaults = .standard
    ) {
        let sanitized = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sanitized.isEmpty else { return }

        var roleCycleStore = loadRoleCycles(from: defaults)
        guard roleCycleStore.scopes[scope].map({ !$0.isEmpty }) != true else { return }
        roleCycleStore.scopes[scope] = sanitized
        saveRoleCycles(roleCycleStore, to: defaults)
    }

    private static func classScopeToken(for schoolClass: SchoolClass) -> String {
        let descriptor = [
            schoolClass.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            schoolClass.grade.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            (schoolClass.schoolYear ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(descriptor.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedToken(for value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "|", with: "-")
            .replacingOccurrences(of: "::", with: "-")
    }

    private static func uniqueStudents(from students: [Student]) -> [Student] {
        var seen: Set<String> = []
        var unique: [Student] = []

        for student in students {
            let id = student.stableIDString
            guard seen.insert(id).inserted else { continue }
            unique.append(student)
        }

        return unique
    }

    private static func chooseCandidateID(from candidateIDs: [String], history: [String]) -> String? {
        guard !candidateIDs.isEmpty else { return nil }

        let candidateSet = Set(candidateIDs)
        var lastSeenByID: [String: Int] = [:]
        for (index, id) in history.enumerated() where candidateSet.contains(id) {
            lastSeenByID[id] = index
        }

        let lastPickedID = history.last
        let immediateRepeatSafePool = candidateIDs.count > 1
            ? candidateIDs.filter { $0 != lastPickedID }
            : candidateIDs
        let pool = immediateRepeatSafePool.isEmpty ? candidateIDs : immediateRepeatSafePool

        let unseenCandidates = pool.filter { lastSeenByID[$0] == nil }
        if !unseenCandidates.isEmpty {
            return unseenCandidates.randomElement()
        }

        let oldestSeenIndex = pool.compactMap { lastSeenByID[$0] }.min() ?? 0
        let oldestCandidates = pool.filter { lastSeenByID[$0] == oldestSeenIndex }
        return oldestCandidates.randomElement()
    }

    private static func updatedHistory(appending pickedID: String, to history: [String]) -> [String] {
        var updated = history
        updated.removeAll { $0 == pickedID }
        updated.append(pickedID)

        let maxHistoryLength = 256
        if updated.count > maxHistoryLength {
            updated.removeFirst(updated.count - maxHistoryLength)
        }
        return updated
    }

    private static func filteredRoleCycleIDs(
        for scope: String,
        matching rosterIDs: Set<String>,
        defaults: UserDefaults
    ) -> [String] {
        let roleCycleStore = loadRoleCycles(from: defaults)
        return (roleCycleStore.scopes[scope] ?? []).filter { rosterIDs.contains($0) }
    }

    private static func loadFairHistory(from defaults: UserDefaults) -> FairHistoryStore {
        decodeStore(
            FairHistoryStore.self,
            forKey: RandomPickerDefaultsKeys.fairHistoryData,
            defaults: defaults
        ) ?? FairHistoryStore()
    }

    private static func saveFairHistory(_ store: FairHistoryStore, to defaults: UserDefaults) {
        encodeStore(store, forKey: RandomPickerDefaultsKeys.fairHistoryData, defaults: defaults)
    }

    private static func loadRoleCycles(from defaults: UserDefaults) -> RoleCycleStore {
        decodeStore(
            RoleCycleStore.self,
            forKey: RandomPickerDefaultsKeys.roleCycleData,
            defaults: defaults
        ) ?? RoleCycleStore()
    }

    private static func saveRoleCycles(_ store: RoleCycleStore, to defaults: UserDefaults) {
        encodeStore(store, forKey: RandomPickerDefaultsKeys.roleCycleData, defaults: defaults)
    }

    private static func decodeStore<T: Decodable>(
        _ type: T.Type,
        forKey key: String,
        defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) ?? defaults.string(forKey: key)?.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encodeStore<T: Encodable>(
        _ value: T,
        forKey key: String,
        defaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        defaults.set(string, forKey: key)
    }
}
