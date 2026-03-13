import Foundation
import UserNotifications
import Combine

enum AttentionNotificationDestinationKind: String, Codable {
    case assessment
    case assignment
    case studentOverview
    case studentFollowUp
}

enum AttentionNotificationMutationAction: String, Codable {
    case markFollowUpInProgress
    case resolveFollowUp
    case reviewAssignmentForToday
}

struct AttentionNotificationRoute: Equatable, Identifiable, Codable {
    let section: AppSection
    let destinationKind: AttentionNotificationDestinationKind
    let assessmentTitle: String?
    let assessmentDate: Date?
    let unitID: UUID?
    let assignmentID: UUID?
    let studentUUID: UUID?
    let interventionID: UUID?

    var id: String {
        [
            section.rawValue,
            destinationKind.rawValue,
            assessmentTitle ?? "",
            assessmentDate.map { String($0.timeIntervalSince1970) } ?? "",
            unitID?.uuidString ?? "",
            assignmentID?.uuidString ?? "",
            studentUUID?.uuidString ?? "",
            interventionID?.uuidString ?? "",
        ].joined(separator: "|")
    }
}

struct AttentionNotificationMutationRequest: Equatable, Identifiable, Codable {
    let id: UUID
    let action: AttentionNotificationMutationAction
    let route: AttentionNotificationRoute
}

struct AttentionNotificationSummary: Equatable {
    let title: String
    let body: String
    let route: AttentionNotificationRoute
}

extension Notification.Name {
    static let attentionNotificationRouteRequested = Notification.Name("AttentionNotificationRouteRequested")
    static let attentionNotificationMutationRequested = Notification.Name("AttentionNotificationMutationRequested")
}

@MainActor
final class AttentionNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AttentionNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let requestIdentifier = "teacherassistant.attention.daily"
    private let openActionIdentifier = "teacherassistant.attention.open"
    private let markReviewedActionIdentifier = "teacherassistant.attention.markReviewed"
    private let markFollowUpInProgressActionIdentifier = "teacherassistant.attention.followUp.inProgress"
    private let resolveFollowUpActionIdentifier = "teacherassistant.attention.followUp.resolve"
    private let reviewAssignmentForTodayActionIdentifier = "teacherassistant.attention.assignment.reviewedToday"
    private let followUpCategoryIdentifier = "teacherassistant.attention.followUp"
    private let assignmentCategoryIdentifier = "teacherassistant.attention.assignment"
    private let assessmentCategoryIdentifier = "teacherassistant.attention.assessment"
    private let studentCategoryIdentifier = "teacherassistant.attention.student"
    private let dashboardCategoryIdentifier = "teacherassistant.attention.dashboard"
    private let pendingMutationRequestDefaultsKey = "teacherassistant.attention.pendingMutationRequest"
    nonisolated private static let routeSectionKey = "routeSection"
    nonisolated private static let routeDestinationKindKey = "routeDestinationKind"
    nonisolated private static let routeAssessmentTitleKey = "routeAssessmentTitle"
    nonisolated private static let routeAssessmentDateKey = "routeAssessmentDate"
    nonisolated private static let routeUnitIDKey = "routeUnitID"
    nonisolated private static let routeAssignmentIDKey = "routeAssignmentID"
    nonisolated private static let routeStudentUUIDKey = "routeStudentUUID"
    nonisolated private static let routeInterventionIDKey = "routeInterventionID"

    private override init() {
        super.init()
        center.delegate = self
        registerNotificationCategories()
    }

    private var isAuthorizedForScheduling: Bool {
        switch authorizationStatus {
        case .authorized, .provisional:
            return true
        #if !os(macOS)
        case .ephemeral:
            return true
        #endif
        default:
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional:
            return true
        #if !os(macOS)
        case .ephemeral:
            return true
        #endif
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
                return granted
            } catch {
                await refreshAuthorizationStatus()
                return false
            }
        @unknown default:
            return false
        }
    }

    func clearScheduledNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
    }

    func consumePendingMutationRequest() -> AttentionNotificationMutationRequest? {
        guard let data = UserDefaults.standard.data(forKey: pendingMutationRequestDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(AttentionNotificationMutationRequest.self, from: data)
    }

    func clearPendingMutationRequest() {
        UserDefaults.standard.removeObject(forKey: pendingMutationRequestDefaultsKey)
    }

    func configureNotifications(
        enabled: Bool,
        summary: AttentionNotificationSummary?,
        hour: Int,
        minute: Int
    ) async {
        guard enabled else {
            await clearScheduledNotifications()
            return
        }

        await refreshAuthorizationStatus()
        guard isAuthorizedForScheduling else {
            await clearScheduledNotifications()
            return
        }

        guard let summary else {
            await clearScheduledNotifications()
            return
        }

        await clearScheduledNotifications()

        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.body = summary.body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier(for: summary.route)
        content.userInfo = userInfo(for: summary.route)

        var dateComponents = DateComponents()
        dateComponents.hour = min(max(hour, 0), 23)
        dateComponents.minute = min(max(minute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let routeSectionRawValue = userInfo[Self.routeSectionKey] as? String
        let route = Self.route(from: userInfo)

        Task { @MainActor in
            switch response.actionIdentifier {
            case markReviewedActionIdentifier:
                markReviewedForToday()
                center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
            case markFollowUpInProgressActionIdentifier, resolveFollowUpActionIdentifier, reviewAssignmentForTodayActionIdentifier:
                guard let route,
                      let action = mutationAction(for: response.actionIdentifier) else {
                    completionHandler()
                    return
                }

                let request = AttentionNotificationMutationRequest(
                    id: UUID(),
                    action: action,
                    route: route
                )
                persistPendingMutationRequest(request)
                NotificationCenter.default.post(
                    name: .attentionNotificationMutationRequested,
                    object: nil,
                    userInfo: ["mutationRequest": request]
                )
                center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
            case UNNotificationDismissActionIdentifier:
                break
            default:
                NotificationCenter.default.post(
                    name: .attentionNotificationRouteRequested,
                    object: nil,
                    userInfo: [
                        "route": route as Any,
                        Self.routeSectionKey: routeSectionRawValue as Any
                    ]
                )
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    private func userInfo(for route: AttentionNotificationRoute) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            Self.routeSectionKey: route.section.rawValue,
            Self.routeDestinationKindKey: route.destinationKind.rawValue,
        ]

        if let assessmentTitle = route.assessmentTitle {
            userInfo[Self.routeAssessmentTitleKey] = assessmentTitle
        }
        if let assessmentDate = route.assessmentDate {
            userInfo[Self.routeAssessmentDateKey] = assessmentDate.timeIntervalSince1970
        }
        if let unitID = route.unitID {
            userInfo[Self.routeUnitIDKey] = unitID.uuidString
        }
        if let assignmentID = route.assignmentID {
            userInfo[Self.routeAssignmentIDKey] = assignmentID.uuidString
        }
        if let studentUUID = route.studentUUID {
            userInfo[Self.routeStudentUUIDKey] = studentUUID.uuidString
        }
        if let interventionID = route.interventionID {
            userInfo[Self.routeInterventionIDKey] = interventionID.uuidString
        }

        return userInfo
    }

    private func categoryIdentifier(for route: AttentionNotificationRoute) -> String {
        if route.section == .dashboard,
           route.assignmentID == nil,
           route.studentUUID == nil,
           route.assessmentTitle == nil {
            return dashboardCategoryIdentifier
        }

        switch route.destinationKind {
        case .studentFollowUp:
            return followUpCategoryIdentifier
        case .assignment:
            return assignmentCategoryIdentifier
        case .assessment:
            return assessmentCategoryIdentifier
        case .studentOverview:
            return studentCategoryIdentifier
        }
    }

    private func registerNotificationCategories() {
        let markReviewedAction = UNNotificationAction(
            identifier: markReviewedActionIdentifier,
            title: "Mark Reviewed".localized
        )
        let reviewAssignmentTodayAction = UNNotificationAction(
            identifier: reviewAssignmentForTodayActionIdentifier,
            title: "Reviewed Today".localized
        )
        let markInProgressAction = UNNotificationAction(
            identifier: markFollowUpInProgressActionIdentifier,
            title: "In Progress".localized
        )
        let resolveFollowUpAction = UNNotificationAction(
            identifier: resolveFollowUpActionIdentifier,
            title: "Resolve".localized
        )

        let categories: Set<UNNotificationCategory> = [
            followUpNotificationCategory(
                identifier: followUpCategoryIdentifier,
                openTitle: "Open Follow-Up".localized,
                actions: [markInProgressAction, resolveFollowUpAction]
            ),
            assignmentNotificationCategory(
                identifier: assignmentCategoryIdentifier,
                openTitle: "Open Assignment".localized,
                reviewAction: reviewAssignmentTodayAction
            ),
            notificationCategory(
                identifier: assessmentCategoryIdentifier,
                openTitle: "Open Assessment".localized,
                markReviewedAction: markReviewedAction
            ),
            notificationCategory(
                identifier: studentCategoryIdentifier,
                openTitle: "Open Student".localized,
                markReviewedAction: markReviewedAction
            ),
            notificationCategory(
                identifier: dashboardCategoryIdentifier,
                openTitle: "Open Dashboard".localized,
                markReviewedAction: markReviewedAction
            ),
        ]

        center.setNotificationCategories(categories)
    }

    private func notificationCategory(
        identifier: String,
        openTitle: String,
        markReviewedAction: UNNotificationAction
    ) -> UNNotificationCategory {
        let openAction = UNNotificationAction(
            identifier: openActionIdentifier,
            title: openTitle,
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: identifier,
            actions: [openAction, markReviewedAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private func assignmentNotificationCategory(
        identifier: String,
        openTitle: String,
        reviewAction: UNNotificationAction
    ) -> UNNotificationCategory {
        let openAction = UNNotificationAction(
            identifier: openActionIdentifier,
            title: openTitle,
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: identifier,
            actions: [openAction, reviewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private func followUpNotificationCategory(
        identifier: String,
        openTitle: String,
        actions: [UNNotificationAction]
    ) -> UNNotificationCategory {
        let openAction = UNNotificationAction(
            identifier: openActionIdentifier,
            title: openTitle,
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: identifier,
            actions: [openAction] + actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private func markReviewedForToday(now: Date = Date(), calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: now))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let dayKey = String(format: "%04d-%02d-%02d", year, month, day)
        UserDefaults.standard.set(dayKey, forKey: AppPreferencesKeys.attentionRemindersLastDismissedDay)
    }

    private func mutationAction(for actionIdentifier: String) -> AttentionNotificationMutationAction? {
        switch actionIdentifier {
        case markFollowUpInProgressActionIdentifier:
            return .markFollowUpInProgress
        case resolveFollowUpActionIdentifier:
            return .resolveFollowUp
        case reviewAssignmentForTodayActionIdentifier:
            return .reviewAssignmentForToday
        default:
            return nil
        }
    }

    private func persistPendingMutationRequest(_ request: AttentionNotificationMutationRequest) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        UserDefaults.standard.set(data, forKey: pendingMutationRequestDefaultsKey)
    }

    nonisolated private static func route(from userInfo: [AnyHashable: Any]) -> AttentionNotificationRoute? {
        guard let sectionRawValue = userInfo[routeSectionKey] as? String else { return nil }
        guard let destinationRawValue = userInfo[routeDestinationKindKey] as? String else { return nil }
        guard let destinationKind = AttentionNotificationDestinationKind(rawValue: destinationRawValue) else { return nil }

        let assessmentTitle = userInfo[routeAssessmentTitleKey] as? String
        let assessmentDate = (userInfo[routeAssessmentDateKey] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        let unitID = (userInfo[routeUnitIDKey] as? String).flatMap(UUID.init(uuidString:))
        let assignmentID = (userInfo[routeAssignmentIDKey] as? String).flatMap(UUID.init(uuidString:))
        let studentUUID = (userInfo[routeStudentUUIDKey] as? String).flatMap(UUID.init(uuidString:))
        let interventionID = (userInfo[routeInterventionIDKey] as? String).flatMap(UUID.init(uuidString:))

        let section: AppSection
        switch sectionRawValue {
        case AppSection.classes.rawValue:
            section = .classes
        case AppSection.attendance.rawValue:
            section = .attendance
        case AppSection.gradebook.rawValue:
            section = .gradebook
        case AppSection.rubrics.rawValue:
            section = .rubrics
        case AppSection.groups.rawValue:
            section = .groups
        case AppSection.randomPicker.rawValue:
            section = .randomPicker
        case AppSection.timer.rawValue:
            section = .timer
        case AppSection.runningRecords.rawValue:
            section = .runningRecords
        case AppSection.usefulLinks.rawValue:
            section = .usefulLinks
        case AppSection.calendar.rawValue:
            section = .calendar
        default:
            section = .dashboard
        }

        return AttentionNotificationRoute(
            section: section,
            destinationKind: destinationKind,
            assessmentTitle: assessmentTitle,
            assessmentDate: assessmentDate,
            unitID: unitID,
            assignmentID: assignmentID,
            studentUUID: studentUUID,
            interventionID: interventionID
        )
    }
}
