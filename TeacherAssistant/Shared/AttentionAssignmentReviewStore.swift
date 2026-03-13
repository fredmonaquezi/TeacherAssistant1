import Foundation

extension Notification.Name {
    static let attentionAssignmentReviewStateChanged = Notification.Name("AttentionAssignmentReviewStateChanged")
}

enum AttentionAssignmentReviewStore {
    private static let reviewedDayKey = "teacherassistant.attention.reviewedAssignments.day"
    private static let reviewedAssignmentIDsKey = "teacherassistant.attention.reviewedAssignments.ids"

    static func reviewedAssignmentIDsForToday(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Set<UUID> {
        cleanupIfNeeded(now: now, calendar: calendar)

        guard let data = UserDefaults.standard.data(forKey: reviewedAssignmentIDsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }

        return Set(ids)
    }

    static func isReviewedToday(
        assignmentID: UUID,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        reviewedAssignmentIDsForToday(now: now, calendar: calendar).contains(assignmentID)
    }

    static func markReviewedToday(
        assignmentID: UUID,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let dayKey = self.dayKey(now: now, calendar: calendar)
        var reviewedIDs = reviewedAssignmentIDsForToday(now: now, calendar: calendar)
        reviewedIDs.insert(assignmentID)

        guard let data = try? JSONEncoder().encode(Array(reviewedIDs)) else { return }

        UserDefaults.standard.set(dayKey, forKey: reviewedDayKey)
        UserDefaults.standard.set(data, forKey: reviewedAssignmentIDsKey)
        NotificationCenter.default.post(name: .attentionAssignmentReviewStateChanged, object: nil)
    }

    static func clearReviewedToday(
        assignmentID: UUID,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        var reviewedIDs = reviewedAssignmentIDsForToday(now: now, calendar: calendar)
        reviewedIDs.remove(assignmentID)

        if reviewedIDs.isEmpty {
            UserDefaults.standard.removeObject(forKey: reviewedDayKey)
            UserDefaults.standard.removeObject(forKey: reviewedAssignmentIDsKey)
        } else if let data = try? JSONEncoder().encode(Array(reviewedIDs)) {
            let dayKey = self.dayKey(now: now, calendar: calendar)
            UserDefaults.standard.set(dayKey, forKey: reviewedDayKey)
            UserDefaults.standard.set(data, forKey: reviewedAssignmentIDsKey)
        }

        NotificationCenter.default.post(name: .attentionAssignmentReviewStateChanged, object: nil)
    }

    private static func cleanupIfNeeded(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let todayKey = dayKey(now: now, calendar: calendar)
        let storedDayKey = UserDefaults.standard.string(forKey: reviewedDayKey)

        guard storedDayKey != nil, storedDayKey != todayKey else { return }

        UserDefaults.standard.removeObject(forKey: reviewedDayKey)
        UserDefaults.standard.removeObject(forKey: reviewedAssignmentIDsKey)
    }

    private static func dayKey(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: now))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
