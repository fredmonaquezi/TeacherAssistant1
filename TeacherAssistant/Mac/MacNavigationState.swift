import SwiftUI
import Combine

final class MacNavigationState: ObservableObject {
    @Published private(set) var depth: Int = 0
    @Published private(set) var popRequestCount: Int = 0

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

    func requestPop() {
        guard depth > 0 else { return }
        popRequestCount += 1
    }
}

#if os(macOS)
private struct MacNavigationRootModifier: ViewModifier {
    @EnvironmentObject private var macNavigationState: MacNavigationState

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .onAppear {
                macNavigationState.reset()
            }
    }
}

private struct MacNavigationDepthModifier: ViewModifier {
    @EnvironmentObject private var macNavigationState: MacNavigationState
    @Environment(\.dismiss) private var dismiss
    @State private var isCounted = false
    @State private var depthLevel = 0

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .onAppear {
                guard !isCounted else { return }
                isCounted = true
                macNavigationState.push()
                depthLevel = macNavigationState.depth
            }
            .onDisappear {
                guard isCounted else { return }
                isCounted = false
                depthLevel = 0
                macNavigationState.pop()
            }
            .onChange(of: macNavigationState.popRequestCount) { _, _ in
                guard isCounted else { return }
                guard depthLevel > 0 else { return }
                guard macNavigationState.depth == depthLevel else { return }
                dismiss()
            }
    }
}
#else
private struct MacNavigationRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct MacNavigationDepthModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif

extension View {
    func macNavigationRoot() -> some View {
        modifier(MacNavigationRootModifier())
    }

    func macNavigationDepth() -> some View {
        modifier(MacNavigationDepthModifier())
    }
}
