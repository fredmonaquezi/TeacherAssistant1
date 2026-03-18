import SwiftUI

enum SectionNavigationMode {
    case standalone
    case embedded

    var ownsNavigationStack: Bool {
        self == .standalone
    }
}

private struct SectionNavigationModeKey: EnvironmentKey {
    static let defaultValue: SectionNavigationMode = .standalone
}

extension EnvironmentValues {
    var sectionNavigationMode: SectionNavigationMode {
        get { self[SectionNavigationModeKey.self] }
        set { self[SectionNavigationModeKey.self] = newValue }
    }
}

extension View {
    func sectionNavigationMode(_ mode: SectionNavigationMode) -> some View {
        environment(\.sectionNavigationMode, mode)
    }
}

struct SectionNavigationContainer<Content: View>: View {
    @Environment(\.sectionNavigationMode) private var navigationMode

    @ViewBuilder let content: () -> Content

    var body: some View {
        if navigationMode.ownsNavigationStack {
            NavigationStack {
                content()
            }
        } else {
            content()
        }
    }
}
