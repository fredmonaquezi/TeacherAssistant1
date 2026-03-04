import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

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

    func appCardStyle(
        cornerRadius: CGFloat = PlatformSpacing.cardCornerRadius + 2,
        borderColor: Color = AppChrome.separator,
        lineWidth: CGFloat = 1,
        shadowOpacity: Double = 0.06,
        shadowRadius: CGFloat = 8,
        shadowY: CGFloat = 3,
        tint: Color? = nil
    ) -> some View {
        modifier(
            AppCardModifier(
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                lineWidth: lineWidth,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius,
                shadowY: shadowY,
                tint: tint
            )
        )
    }

    func appFieldStyle(tint: Color = .accentColor, isInvalid: Bool = false) -> some View {
        modifier(AppFieldModifier(tint: tint, isInvalid: isInvalid))
    }

    func appSheetBackground(tint: Color? = nil) -> some View {
        modifier(AppSheetBackgroundModifier(tint: tint))
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

enum AppChrome {
    static var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }

    static var elevatedBackground: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.tertiarySystemBackground)
        #endif
    }

    static var canvasBackground: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }

    static var separator: Color {
        Color.primary.opacity(0.09)
    }
}

enum AppTypography {
    static var sectionTitle: Font {
        .title3.weight(.semibold)
    }

    static var cardTitle: Font {
        .headline.weight(.semibold)
    }

    static var statValue: Font {
        .system(size: 30, weight: .bold, design: .rounded)
    }

    static var eyebrow: Font {
        .caption
    }
}

private struct AppCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderColor: Color
    let lineWidth: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                shape
                    .fill(AppChrome.cardBackground)
                    .overlay {
                        if let tint {
                            shape.fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.10),
                                        tint.opacity(0.03),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }
                    }
            }
            .overlay {
                shape
                    .stroke(borderColor, lineWidth: lineWidth)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
    }
}

private struct AppFieldModifier: ViewModifier {
    let tint: Color
    let isInvalid: Bool

    func body(content: Content) -> some View {
        let accent = isInvalid ? Color.red : tint
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return content
            .background {
                shape.fill(accent.opacity(isInvalid ? 0.10 : 0.08))
            }
            .overlay {
                shape
                    .stroke(accent.opacity(isInvalid ? 0.36 : 0.16), lineWidth: 1)
            }
    }
}

private struct AppSheetBackgroundModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                AppChrome.canvasBackground
                    .overlay {
                        if let tint {
                            LinearGradient(
                                colors: [tint.opacity(0.08), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .ignoresSafeArea()
            }
    }
}
