import SwiftUI
#if os(macOS)
import Combine
#endif

#if os(macOS)
final class MacNavigationState: ObservableObject {
    @Published private(set) var depth: Int = 0

    func reset() {
        if depth != 0 {
            depth = 0
        }
    }

    func push() {
        depth += 1
    }

    func pop() {
        depth = max(0, depth - 1)
    }
}

private struct MacNavigationRootModifier: ViewModifier {
    @EnvironmentObject private var macNavigationState: MacNavigationState

    func body(content: Content) -> some View {
        content.onAppear {
            macNavigationState.reset()
        }
    }
}

private struct MacNavigationDepthModifier: ViewModifier {
    @EnvironmentObject private var macNavigationState: MacNavigationState
    @State private var isCounted = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isCounted else { return }
                isCounted = true
                macNavigationState.push()
            }
            .onDisappear {
                guard isCounted else { return }
                isCounted = false
                macNavigationState.pop()
            }
    }
}

extension View {
    func macNavigationRoot() -> some View {
        modifier(MacNavigationRootModifier())
    }

    func macNavigationDepth() -> some View {
        modifier(MacNavigationDepthModifier())
    }
}
#else
extension View {
    func macNavigationRoot() -> some View {
        self
    }

    func macNavigationDepth() -> some View {
        self
    }
}
#endif
