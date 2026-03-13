import SwiftUI

struct NavigationHeaderView: View {
    @Binding var selectedSection: AppSection?
    var onNavigate: (() -> Void)? = nil
    var onBack: (() -> Void)? = nil
    var showBackButton: Bool = false
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appMotionContext) private var motion
    @Namespace private var selectionNamespace

    private let barHeight: CGFloat = 44
    private var backButtonVisible: Bool { showBackButton && onBack != nil }
    private var leadingInset: CGFloat {
        #if os(macOS)
        78
        #else
        12
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(backButtonVisible ? 1 : 0)
                .disabled(!backButtonVisible)
                .allowsHitTesting(backButtonVisible)
                .animation(motion.animation(.quick), value: backButtonVisible)
                .help(languageManager.localized("Back"))

                Text("Digital TA")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Divider()
                    .frame(height: 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        headerButton(
                            title: languageManager.localized("Home"),
                            icon: "house.fill",
                            section: .dashboard
                        )

                        headerButton(
                            title: languageManager.localized("Classes"),
                            icon: "person.3.fill",
                            section: .classes
                        )

                        headerButton(
                            title: languageManager.localized("Calendar"),
                            icon: "calendar",
                            section: .calendar
                        )

                        headerButton(
                            title: languageManager.localized("Attendance"),
                            icon: "checklist",
                            section: .attendance
                        )

                        headerButton(
                            title: languageManager.localized("Gradebook"),
                            icon: "tablecells",
                            section: .gradebook
                        )

                        headerButton(
                            title: languageManager.localized("Rubrics"),
                            icon: "doc.text.fill",
                            section: .rubrics
                        )

                        headerButton(
                            title: languageManager.localized("Group Generator"),
                            icon: "person.2.fill",
                            section: .groups
                        )

                        headerButton(
                            title: languageManager.localized("Random Picker"),
                            icon: "die.face.5.fill",
                            section: .randomPicker
                        )

                        headerButton(
                            title: languageManager.localized("Running Records"),
                            icon: "doc.text.magnifyingglass",
                            section: .runningRecords
                        )

                        headerButton(
                            title: languageManager.localized("Useful Links"),
                            icon: "link",
                            section: .usefulLinks
                        )

                        headerButton(
                            title: languageManager.localized("Timer"),
                            icon: "timer",
                            section: .timer
                        )
                    }
                    .padding(.vertical, 2)
                }

                Spacer()

                Divider()
                    .frame(height: 22)

                Button(action: {
                    languageManager.toggleLanguage()
                }) {
                    HStack(spacing: 5) {
                        Text(languageManager.currentLanguage.flag)
                            .font(.system(size: 13, weight: .medium))
                        Text(languageManager.currentLanguage == .english ? "EN" : "PT")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Toggle Language"))
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, 12)
            .frame(height: barHeight)
            .background(.thinMaterial)
            .animation(motion.animation(.standard), value: selectedSection)
            #if os(macOS)
            .gesture(WindowDragGesture())
            #endif
            
            Divider()
        }
    }
    
    private func headerButton(title: String, icon: String, section: AppSection) -> some View {
        Button(action: {
            withAnimation(motion.animation(.standard)) {
                onNavigate?()
                selectedSection = section
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(selectedSection == section ? .accentColor : .primary.opacity(0.85))
        .background {
            if selectedSection == section {
                Capsule()
                    .fill(Color.accentColor.opacity(0.16))
                    .matchedGeometryEffect(id: "navigation-header-selection", in: selectionNamespace)
                    .transition(motion.transition(.inlineChange))
            }
        }
        .clipShape(Capsule())
        .scaleEffect(selectedSection == section && !motion.isReduced ? 1.01 : 1)
        .help(title)
    }
}

#Preview {
    @Previewable @State var selectedSection: AppSection? = .dashboard
    
    NavigationHeaderView(selectedSection: $selectedSection)
        .environmentObject(LanguageManager())
}
