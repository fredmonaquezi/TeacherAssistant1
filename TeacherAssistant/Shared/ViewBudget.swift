import Foundation

enum ViewBudget {
    static let keyScreenInteractiveMilliseconds: Double = 1000
    static let smoothFrameRateLowerBound: Double = 55
    static let smoothFrameRateTarget: Double = 60
    static let heavyDerivationWarningMilliseconds: Double = 45
    static let filterDerivationDebounceMilliseconds: UInt64 = 180
    static let sectionSwitchInteractiveMilliseconds: Double = 250
    static let dashboardDerivationWarningMilliseconds: Double = 55
    static let attentionDerivationWarningMilliseconds: Double = 40
}
