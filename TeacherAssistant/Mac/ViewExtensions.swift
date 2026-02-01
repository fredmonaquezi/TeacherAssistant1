import SwiftUI

// MARK: - Mac Sizing Extension

extension View {
    func macOSSized() -> some View {
        #if os(macOS)
        return self
            .font(.body) // Ensures base font is used
            .environment(\.dynamicTypeSize, .large) // Slightly larger text
        #else
        return self
        #endif
    }
}

// MARK: - Platform-specific spacing

struct PlatformSpacing {
    static var cardPadding: CGFloat {
        #if os(macOS)
        return 20
        #else
        return 16
        #endif
    }
    
    static var sectionSpacing: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 16
        #endif
    }
    
    static var minButtonHeight: CGFloat {
        #if os(macOS)
        return 36
        #else
        return 44
        #endif
    }
    
    static var cardCornerRadius: CGFloat {
        #if os(macOS)
        return 12
        #else
        return 10
        #endif
    }
}
