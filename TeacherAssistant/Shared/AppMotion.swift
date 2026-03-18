import SwiftUI

enum AppMotionTiming {
    case quick
    case standard
    case emphasis
}

enum AppMotionTransition {
    case sectionSwitch
    case cardReveal
    case overlay
    case inlineChange
    case sheetContent
}

struct AppMotionContext: Equatable {
    let configuredProfile: AppMotionProfile
    let reduceMotionEnabled: Bool
    let prefersDesktopSpacing: Bool
    let prefersLightweightScrollingEffects: Bool

    init(
        profile: AppMotionProfile = .full,
        reduceMotionEnabled: Bool = false,
        prefersDesktopSpacing: Bool = false,
        prefersLightweightScrollingEffects: Bool = false
    ) {
        self.configuredProfile = profile
        self.reduceMotionEnabled = reduceMotionEnabled
        self.prefersDesktopSpacing = prefersDesktopSpacing
        self.prefersLightweightScrollingEffects = prefersLightweightScrollingEffects
    }

    var effectiveProfile: AppMotionProfile {
        reduceMotionEnabled ? .reduced : configuredProfile
    }

    var isReduced: Bool {
        effectiveProfile == .reduced
    }

    var pressScale: CGFloat {
        switch effectiveProfile {
        case .full:
            return prefersDesktopSpacing ? 0.988 : 0.976
        case .subtle:
            return prefersDesktopSpacing ? 0.992 : 0.984
        case .reduced:
            return 1
        }
    }

    var pressOpacity: Double {
        isReduced ? 1 : 0.96
    }

    private var standardOffset: CGFloat {
        switch effectiveProfile {
        case .full:
            return prefersDesktopSpacing ? 12 : 20
        case .subtle:
            return prefersDesktopSpacing ? 8 : 12
        case .reduced:
            return 0
        }
    }

    func animation(
        _ timing: AppMotionTiming = .standard,
        interactive: Bool = false
    ) -> Animation {
        switch effectiveProfile {
        case .full:
            if interactive {
                switch timing {
                case .quick:
                    return .spring(response: prefersDesktopSpacing ? 0.22 : 0.26, dampingFraction: 0.88)
                case .standard:
                    return .spring(response: prefersDesktopSpacing ? 0.28 : 0.34, dampingFraction: 0.86)
                case .emphasis:
                    return .spring(response: prefersDesktopSpacing ? 0.34 : 0.40, dampingFraction: 0.84)
                }
            }

            switch timing {
            case .quick:
                return .snappy(duration: prefersDesktopSpacing ? 0.18 : 0.22, extraBounce: prefersDesktopSpacing ? 0.02 : 0.05)
            case .standard:
                return .snappy(duration: prefersDesktopSpacing ? 0.24 : 0.30, extraBounce: prefersDesktopSpacing ? 0.03 : 0.08)
            case .emphasis:
                return .snappy(duration: prefersDesktopSpacing ? 0.30 : 0.36, extraBounce: prefersDesktopSpacing ? 0.05 : 0.10)
            }
        case .subtle:
            if interactive {
                switch timing {
                case .quick:
                    return .easeInOut(duration: 0.16)
                case .standard:
                    return .easeInOut(duration: 0.20)
                case .emphasis:
                    return .easeInOut(duration: 0.24)
                }
            }

            switch timing {
            case .quick:
                return .easeInOut(duration: 0.16)
            case .standard:
                return .easeInOut(duration: 0.20)
            case .emphasis:
                return .easeInOut(duration: 0.24)
            }
        case .reduced:
            switch timing {
            case .quick:
                return .linear(duration: 0.10)
            case .standard:
                return .linear(duration: 0.14)
            case .emphasis:
                return .linear(duration: 0.18)
            }
        }
    }

    func transition(_ kind: AppMotionTransition) -> AnyTransition {
        switch kind {
        case .sectionSwitch:
            if isReduced {
                return .opacity
            }
            if prefersLightweightScrollingEffects {
                return .opacity
            }
            if prefersDesktopSpacing {
                return .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.995)),
                    removal: .opacity
                )
            }
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity
            )
        case .cardReveal:
            if isReduced {
                return .opacity
            }
            return .opacity.combined(with: .offset(y: standardOffset))
        case .overlay:
            if isReduced {
                return .opacity
            }
            return .move(edge: .top).combined(with: .opacity)
        case .inlineChange:
            if isReduced {
                return .opacity
            }
            return .opacity.combined(with: .scale(scale: prefersDesktopSpacing ? 0.992 : 0.97))
        case .sheetContent:
            if isReduced {
                return .opacity
            }
            return .opacity.combined(with: .offset(y: prefersDesktopSpacing ? 10 : 18))
        }
    }

    func revealOffset(for axis: Axis) -> CGSize {
        guard !isReduced else { return .zero }
        switch axis {
        case .horizontal:
            return CGSize(width: standardOffset, height: 0)
        case .vertical:
            return CGSize(width: 0, height: standardOffset)
        }
    }
}

private struct AppMotionContextKey: EnvironmentKey {
    static let defaultValue = AppMotionContext()
}

extension EnvironmentValues {
    var appMotionContext: AppMotionContext {
        get { self[AppMotionContextKey.self] }
        set { self[AppMotionContextKey.self] = newValue }
    }
}

extension View {
    func appSheetMotion() -> some View {
        modifier(AppSheetMotionModifier())
    }

    func appMotionReveal(index: Int = 0, axis: Axis = .vertical) -> some View {
        modifier(AppMotionRevealModifier(index: index, axis: axis))
    }
}

struct AppPressableButtonStyle: ButtonStyle {
    @Environment(\.appMotionContext) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? motion.pressScale : 1)
            .opacity(configuration.isPressed ? motion.pressOpacity : 1)
            .animation(motion.animation(.quick, interactive: true), value: configuration.isPressed)
    }
}

private struct AppMotionRevealModifier: ViewModifier {
    @Environment(\.appMotionContext) private var motion
    let index: Int
    let axis: Axis

    @State private var isVisible = false

    func body(content: Content) -> some View {
        let revealOffset = motion.revealOffset(for: axis).applyingVisibility(isVisible)
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: revealOffset.width, y: revealOffset.height)
            .onAppear {
                guard !isVisible else { return }
                guard !motion.prefersLightweightScrollingEffects else {
                    isVisible = true
                    return
                }
                let delay = motion.isReduced ? 0 : min(Double(index), 5) * 0.035
                if delay == 0 {
                    withAnimation(motion.animation(.standard)) {
                        isVisible = true
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        guard !isVisible else { return }
                        withAnimation(motion.animation(.standard)) {
                            isVisible = true
                        }
                    }
                }
            }
    }
}

private struct AppSheetMotionModifier: ViewModifier {
    @Environment(\.appMotionContext) private var motion
    @State private var isPresented = false

    func body(content: Content) -> some View {
        let revealOffset = motion.revealOffset(for: .vertical).applyingVisibility(isPresented)
        content
            .opacity(isPresented ? 1 : 0)
            .offset(x: revealOffset.width, y: revealOffset.height)
            .onAppear {
                guard !isPresented else { return }
                withAnimation(motion.animation(.standard)) {
                    isPresented = true
                }
            }
    }
}

private extension CGSize {
    func applyingVisibility(_ isVisible: Bool) -> CGSize {
        guard !isVisible else { return .zero }
        return self
    }
}
