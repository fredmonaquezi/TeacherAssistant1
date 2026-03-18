import Foundation
import os

enum PerformanceMetric: String {
    case appLaunch = "app.launch"
    case sectionSwitch = "navigation.sectionSwitch"
    case saveOperation = "persistence.save"
    case backupExport = "backup.export"
    case backupImport = "backup.import"
    case dashboardDerive = "dashboard.derive"
    case attentionDerive = "attention.derive"
    case runningRecordsDerive = "runningRecords.derive"
    case calendarDerive = "calendar.derive"
    case libraryDerive = "library.derive"
    case libraryThumbnailRender = "library.thumbnail.render"
    case studentProgressDerive = "studentProgress.derive"
    case studentDetailDerive = "studentDetail.derive"
}

struct PerformanceSpanToken {
    let metric: PerformanceMetric
    let signpostID: OSSignpostID
    let startedAt: ContinuousClock.Instant
}

actor PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private let log: OSLog
    private let clock = ContinuousClock()
    private var counters: [PerformanceMetric: Int] = [:]

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "TeacherAssistant"
        log = OSLog(subsystem: subsystem, category: "Performance")
    }

    func beginInterval(_ metric: PerformanceMetric, metadata: String? = nil) -> PerformanceSpanToken {
        let signpostID = OSSignpostID(log: log)
        if let metadata, !metadata.isEmpty {
            os_signpost(.begin, log: log, name: "PerformanceSpan", signpostID: signpostID, "%{public}s | %{public}s", metric.rawValue, metadata)
        } else {
            os_signpost(.begin, log: log, name: "PerformanceSpan", signpostID: signpostID, "%{public}s", metric.rawValue)
        }
        return PerformanceSpanToken(metric: metric, signpostID: signpostID, startedAt: clock.now)
    }

    @discardableResult
    func endInterval(_ token: PerformanceSpanToken, success: Bool) -> Duration {
        let elapsed = token.startedAt.duration(to: clock.now)
        let milliseconds = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
        let outcome = success ? "success" : "failure"

        os_signpost(
            .end,
            log: log,
            name: "PerformanceSpan",
            signpostID: token.signpostID,
            "%{public}s | %{public}s | %.2fms",
            token.metric.rawValue,
            outcome,
            milliseconds
        )

        counters[token.metric, default: 0] += 1
        return elapsed
    }

    func incrementCounter(_ metric: PerformanceMetric) {
        counters[metric, default: 0] += 1
    }

    func counterValue(for metric: PerformanceMetric) -> Int {
        counters[metric, default: 0]
    }
}
