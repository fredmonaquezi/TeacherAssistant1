import SwiftUI
import SwiftData

enum LiveWorkspaceSection: String, CaseIterable, Identifiable, Hashable {
    case session
    case checkIn
    case attendance
    case seating
    case assignments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session:
            return "Session".localized
        case .checkIn:
            return "Live Check-In".localized
        case .attendance:
            return "Attendance".localized
        case .seating:
            return "Seating Chart".localized
        case .assignments:
            return "Assignments".localized
        }
    }

    var subtitle: String {
        switch self {
        case .session:
            return "Run the lesson, keep time, and capture what is happening live.".localized
        case .checkIn:
            return "Assess student understanding and support needs in the moment.".localized
        case .attendance:
            return "Mark today's roster and review previous attendance sessions.".localized
        case .seating:
            return "Adjust room format, seat students, and keep the live layout aligned.".localized
        case .assignments:
            return "Track classwork, missing work, and due dates without leaving the workspace.".localized
        }
    }

    var systemImage: String {
        switch self {
        case .session:
            return "play.rectangle.fill"
        case .checkIn:
            return "waveform.path.ecg.rectangle"
        case .attendance:
            return "checklist"
        case .seating:
            return "chair.fill"
        case .assignments:
            return "list.clipboard"
        }
    }

    var tint: Color {
        switch self {
        case .session:
            return .red
        case .checkIn:
            return .indigo
        case .attendance:
            return .blue
        case .seating:
            return .purple
        case .assignments:
            return .teal
        }
    }
}

struct LiveWorkspaceView: View {
    @Bindable var schoolClass: SchoolClass
    @StateObject private var timerManager: ClassroomTimerManager

    @Environment(\.appMotionContext) private var motion
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var selectedSection: LiveWorkspaceSection

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    init(
        schoolClass: SchoolClass,
        timerManager: ClassroomTimerManager,
        initialSection: LiveWorkspaceSection = .session
    ) {
        self.schoolClass = schoolClass
        _timerManager = StateObject(wrappedValue: timerManager)
        _selectedSection = State(initialValue: initialSection)
    }

    init(
        schoolClass: SchoolClass,
        initialSection: LiveWorkspaceSection = .session
    ) {
        self.schoolClass = schoolClass
        _timerManager = StateObject(wrappedValue: ClassroomTimerManager())
        _selectedSection = State(initialValue: initialSection)
    }

    private var orderedStudents: [Student] {
        schoolClass.students.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var assignmentCount: Int {
        schoolClass.subjects.flatMap(\.units).flatMap(\.assignments).count
    }

    private var currentSection: LiveWorkspaceSection {
        selectedSection
    }

    #if os(iOS)
    private var usesSidebarLayout: Bool {
        horizontalSizeClass == .regular
    }
    #else
    private let usesSidebarLayout = true
    #endif

    var body: some View {
        Group {
            if usesSidebarLayout {
                expandedLayout
            } else {
                compactLayout
            }
        }
        .navigationTitle(currentSection.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(motion.animation(.standard), value: selectedSection)
        .macNavigationDepth()
    }

    private var expandedLayout: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 290)
                .background(workspaceSidebarBackground)

            Divider()

            currentSectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(workspaceContentBackground)
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            compactHeader
            currentSectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(workspaceContentBackground)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceSummaryCard
                    .appMotionReveal(index: 0)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Live Tools".localized)
                        .font(.headline)
                        .padding(.horizontal, 18)

                    ForEach(LiveWorkspaceSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .appMotionReveal(index: 1)

                spacerSummary
                    .appMotionReveal(index: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private var workspaceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(currentSection.tint.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: currentSection.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(currentSection.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Live Workspace".localized)
                        .font(.title3.weight(.semibold))
                    Text(schoolClass.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }

            Text(currentSection.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                workspaceMetric(
                    title: "Students".localized,
                    value: "\(orderedStudents.count)",
                    color: .blue
                )
                workspaceMetric(
                    title: "Assignments".localized,
                    value: "\(assignmentCount)",
                    color: .teal
                )
            }
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 20,
            borderColor: currentSection.tint.opacity(0.14),
            tint: currentSection.tint
        )
    }

    private var spacerSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How It Works".localized)
                .font(.headline)

            Label("Switch tools without leaving the lesson.".localized, systemImage: "arrow.left.arrow.right")
            Label("Timer state stays available across the whole workspace.".localized, systemImage: "timer")
            Label("Sub-editors still open as sheets when they are true edit tasks.".localized, systemImage: "square.on.square")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(18)
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.secondary.opacity(0.08)
        )
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Workspace".localized)
                    .font(.title3.weight(.semibold))
                Text(schoolClass.name)
                    .font(.headline)
                Text(currentSection.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LiveWorkspaceSection.allCases) { section in
                        compactSectionButton(for: section)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(workspaceContentBackground)
    }

    @ViewBuilder
    private var currentSectionContent: some View {
        switch selectedSection {
        case .session:
            ClassroomSessionView(
                schoolClass: schoolClass,
                timerManager: timerManager,
                embeddedInLiveWorkspace: true
            ) { section in
                select(section)
            }
            .transition(motion.transition(.sectionSwitch))
        case .checkIn:
            LiveCheckInView(
                schoolClass: schoolClass,
                source: .classroomSession,
                embeddedInLiveWorkspace: true,
                onOpenSeatingChart: {
                    select(.seating)
                }
            )
            .transition(motion.transition(.sectionSwitch))
        case .attendance:
            AttendanceListView(
                schoolClass: schoolClass,
                embeddedInLiveWorkspace: true
            )
            .transition(motion.transition(.sectionSwitch))
        case .seating:
            SeatingChartView(schoolClass: schoolClass)
                .transition(motion.transition(.sectionSwitch))
        case .assignments:
            ClassAssignmentsView(schoolClass: schoolClass)
                .transition(motion.transition(.sectionSwitch))
        }
    }

    private func select(_ section: LiveWorkspaceSection) {
        guard selectedSection != section else { return }
        withAnimation(motion.animation(.standard)) {
            selectedSection = section
        }
    }

    private func sidebarButton(for section: LiveWorkspaceSection) -> some View {
        Button {
            select(section)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(section.tint.opacity(selectedSection == section ? 0.16 : 0.08))
                        .frame(width: 40, height: 40)

                    Image(systemName: section.systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(section.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if selectedSection == section {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(section.tint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedSection == section ? section.tint.opacity(0.11) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(section.tint.opacity(selectedSection == section ? 0.18 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    private func compactSectionButton(for section: LiveWorkspaceSection) -> some View {
        Button {
            select(section)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(selectedSection == section ? section.tint : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedSection == section ? section.tint.opacity(0.14) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(section.tint.opacity(selectedSection == section ? 0.18 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    private func workspaceMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: color.opacity(0.10),
            tint: color
        )
    }

    private var workspaceSidebarBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor).opacity(0.55)
        #else
        return Color(uiColor: .secondarySystemBackground).opacity(0.55)
        #endif
    }

    private var workspaceContentBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}
