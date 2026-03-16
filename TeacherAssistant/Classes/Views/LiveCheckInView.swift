import SwiftUI
import SwiftData

struct LiveCheckInView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case needsSupport
        case observedToday
        case notCheckedToday

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All".localized
            case .needsSupport:
                return "Needs Support".localized
            case .observedToday:
                return "Observed Today".localized
            case .notCheckedToday:
                return "Not Checked Today".localized
            }
        }
    }

    @Bindable var schoolClass: SchoolClass
    let source: LiveObservationSource
    let showsDismissButton: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appMotionContext) private var motion
    @Query(sort: [SortDescriptor(\LiveObservationTemplate.sortOrder), SortDescriptor(\LiveObservationTemplate.createdAt)])
    private var templates: [LiveObservationTemplate]

    @State private var selectedFilter: Filter = .all
    @State private var selectedTemplateID: UUID?
    @State private var sessionExtraCriteria: [LiveCheckInSessionCriterion] = []
    @State private var newCriterionTitle = ""
    @State private var selectedStudent: Student?
    @State private var showingTemplateManager = false
    @State private var feedbackBanner: LiveCheckInFeedbackBannerState?
    @State private var feedbackDismissTask: DispatchWorkItem?
    @Namespace private var filterSelectionNamespace

    private let calendar = Calendar.current

    init(
        schoolClass: SchoolClass,
        source: LiveObservationSource,
        showsDismissButton: Bool = false
    ) {
        self.schoolClass = schoolClass
        self.source = source
        self.showsDismissButton = showsDismissButton
    }

    private var orderedStudents: [Student] {
        schoolClass.students.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var chart: SeatingChart? {
        schoolClass.seatingChart
    }

    private var layoutStyle: SeatingLayoutStyle {
        chart?.layoutStyle ?? .rows
    }

    private var seatCoordinates: [LiveCheckInSeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.rows).flatMap { row in
            (0..<chart.columns).map { column in
                LiveCheckInSeatCoordinate(row: row, column: column)
            }
        }
    }

    private var activeSeatCoordinates: [LiveCheckInSeatCoordinate] {
        guard let chart else { return [] }
        return seatCoordinates.filter { chart.isActiveSeat(row: $0.row, column: $0.column) }
    }

    private var centerGroupSize: Int {
        chart?.validatedCenterGroupSize ?? 4
    }

    private var centerGroups: [[LiveCheckInSeatCoordinate]] {
        chunkCoordinates(activeSeatCoordinates, size: centerGroupSize)
    }

    private var hasSeatPlacements: Bool {
        !(chart?.placements.isEmpty ?? true)
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var startOfTomorrow: Date {
        calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    private var allObservationsDescending: [LiveObservation] {
        schoolClass.liveObservations.sorted { $0.createdAt > $1.createdAt }
    }

    private var todaysObservations: [LiveObservation] {
        allObservationsDescending.filter { observation in
            observation.createdAt >= startOfToday && observation.createdAt < startOfTomorrow
        }
    }

    private var observedTodayUUIDs: Set<UUID> {
        Set(todaysObservations.map(\.studentUUID))
    }

    private var latestObservationByStudentUUID: [UUID: LiveObservation] {
        var observations: [UUID: LiveObservation] = [:]
        for observation in allObservationsDescending where observations[observation.studentUUID] == nil {
            observations[observation.studentUUID] = observation
        }
        return observations
    }

    private var latestObservationByStudentTodayUUID: [UUID: LiveObservation] {
        var observations: [UUID: LiveObservation] = [:]
        for observation in todaysObservations where observations[observation.studentUUID] == nil {
            observations[observation.studentUUID] = observation
        }
        return observations
    }

    private var activeTemplate: LiveObservationTemplate? {
        guard let selectedTemplateID else { return nil }
        return templates.first { $0.id == selectedTemplateID }
    }

    private var activeCriteria: [LiveCheckInCriterionDefinition] {
        let templateCriteria = activeTemplate?.criteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                LiveCheckInCriterionDefinition(
                    id: $0.id.uuidString,
                    title: $0.title,
                    sortOrder: $0.sortOrder,
                    origin: .template
                )
            } ?? []
        let sessionCriteria = sessionExtraCriteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                LiveCheckInCriterionDefinition(
                    id: $0.id.uuidString,
                    title: $0.title,
                    sortOrder: $0.sortOrder,
                    origin: .session
                )
            }
        return (templateCriteria + sessionCriteria)
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var filteredStudents: [Student] {
        orderedStudents.filter(matchesCurrentFilter)
    }

    private var studentsNeedingSupportNow: Int {
        latestObservationByStudentTodayUUID.values.filter(isNeedsSupport).count
    }

    private var unseatedFilteredStudents: [Student] {
        let seatedUUIDs = Set(chart?.placements.map(\.studentUUID) ?? [])
        return filteredStudents.filter { !seatedUUIDs.contains($0.uuid) }
    }

    private var templateLabel: String {
        activeTemplate?.title ?? "No Checklist".localized
    }

    private var checkedInProgress: Double {
        guard !orderedStudents.isEmpty else { return 0 }
        return Double(observedTodayUUIDs.count) / Double(orderedStudents.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                headerCard
                    .appMotionReveal(index: 0)
                checklistCard
                    .appMotionReveal(index: 1)
                studentSurfaceCard
                    .appMotionReveal(index: 2)
                recentObservationsCard
                    .appMotionReveal(index: 3)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Live Check-In".localized)
        .appSheetMotion()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedStudent) { student in
            NavigationStack {
                LiveCheckInObservationEntrySheet(
                    student: student,
                    criteria: activeCriteria,
                    previousObservation: latestObservationByStudentUUID[student.uuid]
                ) { payload in
                    saveObservation(for: student, payload: payload)
                }
            }
        }
        .sheet(isPresented: $showingTemplateManager) {
            NavigationStack {
                LiveCheckInTemplateManagerView(
                    selectedTemplateID: $selectedTemplateID,
                    sessionCriteria: sessionExtraCriteria
                ) { feedback in
                    presentFeedback(feedback)
                }
            }
        }
        .overlay(alignment: .top) {
            if let feedbackBanner {
                LiveCheckInFeedbackBanner(state: feedbackBanner)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(motion.transition(.overlay))
                    .zIndex(2)
            }
        }
        .animation(motion.animation(.standard), value: selectedFilter)
        .animation(motion.animation(.emphasis), value: todaysObservations.count)
        .animation(motion.animation(.standard), value: sessionExtraCriteria.count)
        .animation(motion.animation(.quick), value: selectedTemplateID)
        .animation(motion.animation(.quick), value: feedbackBanner?.id)
        .macNavigationDepth()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.indigo.opacity(0.12))
                            .frame(width: 52, height: 52)

                        Image(systemName: source == .classroomSession ? "bolt.badge.clock.fill" : "waveform.path.ecg.text")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(source == .classroomSession ? "Session Live Check-In".localized : "Live Check-In".localized)
                            .font(.title3.weight(.semibold))
                        Text(schoolClass.name)
                            .font(.headline)
                        Text("Capture a fast snapshot of understanding, engagement, and support in the moment.".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(Date().appDateString(systemStyle: .full))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)

                    LiveCheckInTopBadge(
                        icon: activeTemplate == nil ? "bolt.badge.checkmark" : "checklist.checked",
                        title: activeTemplate == nil ? "Core Snapshot Only".localized : templateLabel,
                        tint: activeTemplate == nil ? .secondary : .indigo
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(
                        String(
                            format: "%d of %d students checked in".localized,
                            observedTodayUUIDs.count,
                            orderedStudents.count
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(Int((checkedInProgress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.indigo.opacity(0.10))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.indigo, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * checkedInProgress, checkedInProgress == 0 ? 0 : 24))
                    }
                }
                .frame(height: 10)
                .animation(motion.animation(.emphasis), value: checkedInProgress)
            }

            HStack(spacing: 10) {
                LiveCheckInTopBadge(
                    icon: "person.2.fill",
                    title: "\(orderedStudents.count) " + "students".localized,
                    tint: .blue
                )
                LiveCheckInTopBadge(
                    icon: hasSeatPlacements ? "rectangle.grid.3x2.fill" : "list.bullet.rectangle",
                    title: hasSeatPlacements ? "Seating Layout Active".localized : "Roster View".localized,
                    tint: hasSeatPlacements ? .teal : .secondary
                )
                if !sessionExtraCriteria.isEmpty {
                    LiveCheckInTopBadge(
                        icon: "sparkles.rectangle.stack",
                        title: "\(sessionExtraCriteria.count) " + "session extras".localized,
                        tint: .orange
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 12)], spacing: 12) {
                liveStatCard(
                    title: "Observed Today".localized,
                    value: "\(observedTodayUUIDs.count)",
                    color: .blue,
                    icon: "checkmark.circle.fill"
                )
                liveStatCard(
                    title: "Snapshots".localized,
                    value: "\(todaysObservations.count)",
                    color: .indigo,
                    icon: "waveform.path.ecg"
                )
                liveStatCard(
                    title: "Needs Support".localized,
                    value: "\(studentsNeedingSupportNow)",
                    color: studentsNeedingSupportNow == 0 ? .secondary : .red,
                    icon: "cross.case.fill"
                )
                liveStatCard(
                    title: "Waiting".localized,
                    value: "\(max(orderedStudents.count - observedTodayUUIDs.count, 0))",
                    color: observedTodayUUIDs.count == orderedStudents.count ? .secondary : .orange,
                    icon: "clock.badge.exclamationmark"
                )
            }

            filterStrip
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.indigo.opacity(0.12),
            tint: .indigo
        )
        .padding(.horizontal)
    }

    private var filterStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Focus Filter".localized)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedFilter.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Filter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(motion.animation(.standard)) {
                                selectedFilter = filter
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.subheadline)
                                    Text(filter.title)
                                        .font(.subheadline.weight(.semibold))
                                }

                                Text(filterSubtitle(for: filter))
                                    .font(.caption)
                                    .foregroundColor(isSelected ? .white.opacity(0.86) : .secondary)
                                    .lineLimit(1)
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(width: 170, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.primary.opacity(isSelected ? 0.02 : 0.05))

                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.indigo)
                                            .matchedGeometryEffect(
                                                id: "live-check-in-filter-selection",
                                                in: filterSelectionNamespace
                                            )
                                    }
                                }
                            )
                        }
                        .buttonStyle(AppPressableButtonStyle())
                        .scaleEffect(isSelected ? 1.0 : 0.985)
                    }
                }
            }
        }
    }

    private func filterSubtitle(for filter: Filter) -> String {
        switch filter {
        case .all:
            return "See the full class at once.".localized
        case .needsSupport:
            return "Surface students who need attention now.".localized
        case .observedToday:
            return "Review students already checked in.".localized
        case .notCheckedToday:
            return "Focus on students still waiting.".localized
        }
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Checklist".localized)
                        .font(AppTypography.sectionTitle)
                    Text("Use the default 3-signal snapshot only, or attach a reusable checklist for this session.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Menu {
                    Button("No Checklist".localized) {
                        clearActiveTemplate(showFeedback: true)
                    }

                    if !templates.isEmpty {
                        Divider()

                        ForEach(templates, id: \.id) { template in
                            Button(template.title) {
                                applyTemplate(template, showFeedback: true)
                            }
                        }
                    }
                } label: {
                    Label(templateLabel, systemImage: "checklist")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Label(
                        activeTemplate == nil
                            ? "Using the default 3-signal snapshot".localized
                            : String(format: "Using template: %@".localized, templateLabel),
                        systemImage: activeTemplate == nil ? "bolt.badge.checkmark" : "square.stack.3d.up.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(activeTemplate == nil ? .secondary : .indigo)

                    Spacer()

                    Button("Template Library".localized) {
                        showingTemplateManager = true
                    }
                    .buttonStyle(.bordered)
                }

                Text("Session-only criteria stay only in this live session. The Template Library stores reusable checklists.".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.indigo.opacity(0.06))
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Add Session-Only Criterion".localized)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    TextField("Add a session-only criterion".localized, text: $newCriterionTitle)
                        .textFieldStyle(.roundedBorder)

                    Button("Add".localized) {
                        addSessionCriterion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedNewCriterionTitle.isEmpty)
                }
            }

            if activeCriteria.isEmpty {
                Text("No checklist attached. Every check-in will still record Understanding, Engagement, and Support Need.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let activeTemplate {
                        criteriaGroupCard(
                            title: "Reusable Template".localized,
                            subtitle: String(
                                format: "Active template: %@".localized,
                                activeTemplate.title
                            ),
                            tint: .indigo,
                            criteria: activeCriteria.filter { $0.origin == .template }
                        )
                    }

                    if !sessionExtraCriteria.isEmpty {
                        criteriaGroupCard(
                            title: "Session-Only Criteria".localized,
                            subtitle: "These appear in the current check-in sheet only.".localized,
                            tint: .orange,
                            criteria: activeCriteria.filter { $0.origin == .session },
                            removableIDs: Set(sessionExtraCriteria.map { $0.id.uuidString })
                        )
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.10),
            tint: .blue
        )
        .padding(.horizontal)
    }

    private func criteriaGroupCard(
        title: String,
        subtitle: String,
        tint: Color,
        criteria: [LiveCheckInCriterionDefinition],
        removableIDs: Set<String> = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                ForEach(criteria) { criterion in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(criterion.title)
                                .font(.caption.weight(.semibold))
                            Text(criterion.origin == .session ? "Session only".localized : "Reusable".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 0)

                        if removableIDs.contains(criterion.id) {
                            Button {
                                withAnimation(motion.animation(.quick)) {
                                    sessionExtraCriteria.removeAll { $0.id.uuidString == criterion.id }
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tint.opacity(0.10))
                    )
                }
            }
        }
    }

    private var studentSurfaceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assess Students".localized)
                .font(AppTypography.sectionTitle)

            if filteredStudents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("No students match the current filter.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .transition(motion.transition(.inlineChange))
            } else if hasSeatPlacements {
                VStack(alignment: .leading, spacing: 16) {
                    seatingSurface

                    if !unseatedFilteredStudents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unseated Students".localized)
                                .font(.headline)

                            studentGrid(unseatedFilteredStudents)
                        }
                    }
                }
                .transition(motion.transition(.cardReveal))
            } else {
                studentGrid(filteredStudents)
                    .transition(motion.transition(.cardReveal))
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.10),
            tint: .orange
        )
        .padding(.horizontal)
    }

    private var seatingSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(layoutSurfaceTitle)
                .font(.headline)

            seatingLayoutSurface
        }
    }

    @ViewBuilder
    private var seatingLayoutSurface: some View {
        switch layoutStyle {
        case .rows:
            liveRowsSurface(groupAsDuos: false)
        case .duos:
            liveRowsSurface(groupAsDuos: true)
        case .uShape:
            liveUShapeSurface
        case .centers:
            liveCentersSurface
        }
    }

    private func liveRowsSurface(groupAsDuos: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                if groupAsDuos {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(duoGroups(for: row).indices, id: \.self) { groupIndex in
                            HStack(spacing: 10) {
                                ForEach(duoGroups(for: row)[groupIndex]) { coordinate in
                                    liveSeatCard(for: coordinate)
                                }
                            }
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(rowSeatCoordinates(for: row)) { coordinate in
                            liveSeatCard(for: coordinate)
                        }
                    }
                }
            }
        }
    }

    private var liveUShapeSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(rowSeatCoordinates(for: row)) { coordinate in
                        if chart?.isActiveSeat(row: coordinate.row, column: coordinate.column) == true {
                            liveSeatCard(for: coordinate)
                        } else {
                            inactiveLiveSeatPlaceholder
                        }
                    }
                }
            }
        }
    }

    private var liveCentersSurface: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(centerGroups.enumerated()), id: \.offset) { index, group in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            String(format: "Center %d".localized, index + 1),
                            systemImage: "circle.grid.2x2.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.indigo)

                        if centerGroupSize == 4 {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(group) { coordinate in
                                    liveSeatCard(for: coordinate)
                                }
                            }
                            .frame(width: 360)
                        } else {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(group) { coordinate in
                                    liveSeatCard(for: coordinate)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .appCardStyle(
                        cornerRadius: 14,
                        borderColor: Color.indigo.opacity(0.10),
                        shadowOpacity: 0.03,
                        shadowRadius: 5,
                        shadowY: 2,
                        tint: .indigo
                    )
                }
            }
        }
    }

    private func liveSeatCard(for coordinate: LiveCheckInSeatCoordinate) -> some View {
        let student = student(at: coordinate)
        return LiveCheckInSeatCard(
            student: student,
            observation: student.map { latestObservationByStudentUUID[$0.uuid] } ?? nil,
            isDimmed: student.map { !matchesCurrentFilter($0) } ?? false,
            onTap: {
                guard let student else { return }
                selectedStudent = student
            }
        )
    }

    private var inactiveLiveSeatPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Space".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Center stays open".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        )
    }

    private func studentGrid(_ students: [Student]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            ForEach(students, id: \.id) { student in
                Button {
                    selectedStudent = student
                } label: {
                    LiveCheckInStudentCard(
                        student: student,
                        latestObservation: latestObservationByStudentUUID[student.uuid],
                        observedToday: observedTodayUUIDs.contains(student.uuid)
                    )
                }
                .buttonStyle(AppPressableButtonStyle())
                .transition(motion.transition(.inlineChange))
            }
        }
        .animation(motion.animation(.standard), value: students.map(\.uuid))
    }

    private var recentObservationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Snapshots".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(todaysObservations.count) " + "today".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if todaysObservations.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No check-ins recorded today yet.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(todaysObservations.prefix(8), id: \.id) { observation in
                        recentObservationRow(observation)
                            .transition(motion.transition(.cardReveal))
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.teal.opacity(0.10),
            tint: .teal
        )
        .padding(.horizontal)
    }

    private func recentObservationRow(_ observation: LiveObservation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.student?.name ?? observation.studentNameSnapshot)
                        .font(.headline)
                    Text(observation.createdAt.appTimeString(systemStyle: .short))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                LiveCheckInLevelBadge(level: observation.supportLevel)
            }

            HStack(spacing: 8) {
                LiveCheckInMiniLevelTag(label: "Understanding".localized, level: observation.understandingLevel)
                LiveCheckInMiniLevelTag(label: "Engagement".localized, level: observation.engagementLevel)
                LiveCheckInMiniLevelTag(label: "Support".localized, level: observation.supportLevel)
            }

            if !observation.checklistResponses.isEmpty {
                Text(
                    observation.checklistResponses
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { "\($0.criterionTitle): \($0.level.title)" }
                        .joined(separator: " • ")
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if !observation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(observation.note)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: observation.supportLevel.color.opacity(0.16),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: observation.supportLevel.color
        )
    }

    private func liveStatCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.10))
        )
    }

    private var trimmedNewCriterionTitle: String {
        newCriterionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addSessionCriterion() {
        guard !trimmedNewCriterionTitle.isEmpty else { return }
        let nextSortOrder = (activeTemplate?.criteria.count ?? 0) + sessionExtraCriteria.count
        withAnimation(motion.animation(.standard)) {
            sessionExtraCriteria.append(
                LiveCheckInSessionCriterion(
                    title: trimmedNewCriterionTitle,
                    sortOrder: nextSortOrder
                )
            )
        }
        newCriterionTitle = ""
    }

    private func student(at coordinate: LiveCheckInSeatCoordinate) -> Student? {
        guard let placement = chart?.placements.first(where: {
            $0.row == coordinate.row && $0.column == coordinate.column
        }) else {
            return nil
        }
        return orderedStudents.first { $0.uuid == placement.studentUUID }
    }

    private var layoutSurfaceTitle: String {
        switch layoutStyle {
        case .rows:
            return "Seating Layout".localized
        case .duos:
            return "Duo Seating Layout".localized
        case .uShape:
            return "U-Shape Seating Layout".localized
        case .centers:
            return centerGroupSize == 3
                ? "Learning Centers (3)".localized
                : "Learning Centers (4)".localized
        }
    }

    private func rowSeatCoordinates(for row: Int) -> [LiveCheckInSeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.columns).map { LiveCheckInSeatCoordinate(row: row, column: $0) }
    }

    private func duoGroups(for row: Int) -> [[LiveCheckInSeatCoordinate]] {
        chunkCoordinates(rowSeatCoordinates(for: row), size: 2)
    }

    private func chunkCoordinates(_ coordinates: [LiveCheckInSeatCoordinate], size: Int) -> [[LiveCheckInSeatCoordinate]] {
        guard size > 0 else { return [coordinates] }

        var groups: [[LiveCheckInSeatCoordinate]] = []
        var index = 0
        while index < coordinates.count {
            let end = min(index + size, coordinates.count)
            groups.append(Array(coordinates[index..<end]))
            index = end
        }
        return groups
    }

    private func matchesCurrentFilter(_ student: Student) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .needsSupport:
            guard let observation = latestObservationByStudentTodayUUID[student.uuid] ?? latestObservationByStudentUUID[student.uuid] else {
                return false
            }
            return isNeedsSupport(observation)
        case .observedToday:
            return observedTodayUUIDs.contains(student.uuid)
        case .notCheckedToday:
            return !observedTodayUUIDs.contains(student.uuid)
        }
    }

    private func isNeedsSupport(_ observation: LiveObservation) -> Bool {
        if observation.supportLevel == .needsSupport || observation.understandingLevel == .needsSupport || observation.engagementLevel == .needsSupport {
            return true
        }
        return observation.checklistResponses.contains { $0.level == .needsSupport }
    }

    private func saveObservation(
        for student: Student,
        payload: LiveCheckInObservationPayload
    ) {
        withAnimation(motion.animation(.emphasis)) {
            let observation = LiveObservation(
                sessionDate: startOfToday,
                source: source,
                understandingLevel: payload.understandingLevel,
                engagementLevel: payload.engagementLevel,
                supportLevel: payload.supportLevel,
                note: payload.note.trimmingCharacters(in: .whitespacesAndNewlines),
                studentUUID: student.uuid,
                studentNameSnapshot: student.name,
                student: student,
                schoolClass: schoolClass
            )
            let responses = payload.checklistResponses.enumerated().map { index, response in
                LiveObservationChecklistResponse(
                    criterionTitle: response.criterionTitle,
                    level: response.level,
                    sortOrder: index,
                    observation: observation
                )
            }
            observation.checklistResponses = responses
            schoolClass.liveObservations.append(observation)
            student.liveObservations.append(observation)
            context.insert(observation)
            for response in responses {
                context.insert(response)
            }
        }
        _ = SaveCoordinator.save(context: context, reason: "Save live check-in observation")
        presentFeedback(
            LiveCheckInFeedbackBannerState(
                icon: "checkmark.circle.fill",
                title: String(format: "Saved %@".localized, student.name),
                message: activeCriteria.isEmpty
                    ? "Core snapshot recorded for this student.".localized
                    : String(
                        format: "Snapshot recorded with %d checklist item(s).".localized,
                        payload.checklistResponses.count
                    ),
                tint: payload.supportLevel.color
            )
        )
    }

    private func applyTemplate(_ template: LiveObservationTemplate, showFeedback: Bool) {
        withAnimation(motion.animation(.standard)) {
            selectedTemplateID = template.id
        }
        guard showFeedback else { return }
        presentFeedback(
            LiveCheckInFeedbackBannerState(
                icon: "checklist.checked",
                title: String(format: "Using %@".localized, template.title),
                message: String(
                    format: "%d reusable items are ready for the next check-in.".localized,
                    template.criteria.count
                ),
                tint: .indigo
            )
        )
    }

    private func clearActiveTemplate(showFeedback: Bool) {
        withAnimation(motion.animation(.standard)) {
            selectedTemplateID = nil
        }
        guard showFeedback else { return }
        presentFeedback(
            LiveCheckInFeedbackBannerState(
                icon: "bolt.badge.checkmark",
                title: "Core Snapshot Only".localized,
                message: "The session is back to the default 3-signal check-in.".localized,
                tint: .secondary
            )
        )
    }

    private func presentFeedback(_ feedback: LiveCheckInFeedbackBannerState) {
        feedbackDismissTask?.cancel()
        withAnimation(motion.animation(.emphasis)) {
            feedbackBanner = feedback
        }

        let dismissTask = DispatchWorkItem {
            withAnimation(motion.animation(.quick)) {
                if feedbackBanner?.id == feedback.id {
                    feedbackBanner = nil
                }
            }
        }
        feedbackDismissTask = dismissTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissTask)
    }
}

private struct LiveCheckInStudentCard: View {
    let student: Student
    let latestObservation: LiveObservation?
    let observedToday: Bool

    private var accentColor: Color {
        latestObservation?.supportLevel.color ?? .indigo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Text(String(student.name.prefix(1)).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(student.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(observedToday ? "Observed Today".localized : "Ready for Check-In".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                LiveCheckInInlineStatusBadge(
                    title: observedToday ? "Checked".localized : "Pending".localized,
                    color: observedToday ? .green : .orange
                )
            }

            if let latestObservation {
                HStack(alignment: .center) {
                    LiveCheckInLevelBadge(level: latestObservation.supportLevel)
                    Spacer()
                    Label(latestObservation.createdAt.appTimeString(systemStyle: .short), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    LiveCheckInMiniLevelTag(label: "Understanding".localized, level: latestObservation.understandingLevel)
                    LiveCheckInMiniLevelTag(label: "Engagement".localized, level: latestObservation.engagementLevel)
                    LiveCheckInMiniLevelTag(label: "Support".localized, level: latestObservation.supportLevel)
                }

                if !latestObservation.checklistResponses.isEmpty {
                    Label(
                        String(format: "%d checklist item(s)".localized, latestObservation.checklistResponses.count),
                        systemImage: "checklist"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if !latestObservation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(latestObservation.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("Tap to capture a quick snapshot of understanding, engagement, and support.".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(accentColor)
                    Text("Start Check-In".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: accentColor.opacity(0.18),
            shadowOpacity: 0.03,
            shadowRadius: 6,
            shadowY: 3,
            tint: accentColor
        )
    }
}

private struct LiveCheckInSeatCard: View {
    let student: Student?
    let observation: LiveObservation?
    let isDimmed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                if let student {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(student.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            Text(observation == nil ? "No snapshot yet".localized : "Latest snapshot".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let observation {
                            LiveCheckInLevelBadge(level: observation.supportLevel)
                        }
                    }

                    if let observation {
                        HStack(spacing: 6) {
                            LiveCheckInCompactSignal(level: observation.understandingLevel, letter: "U")
                            LiveCheckInCompactSignal(level: observation.engagementLevel, letter: "E")
                            LiveCheckInCompactSignal(level: observation.supportLevel, letter: "S")
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(observation.createdAt.appTimeString(systemStyle: .short))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Tap to assess".localized, systemImage: "plus.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Empty".localized)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        Text("No student assigned".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((observation?.supportLevel.color ?? Color.gray).opacity(student == nil ? 0.06 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((observation?.supportLevel.color ?? Color.gray).opacity(0.14), lineWidth: 1)
            )
            .opacity(isDimmed ? 0.35 : 1)
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(student == nil)
    }
}

private struct LiveCheckInObservationEntrySheet: View {
    let student: Student
    let criteria: [LiveCheckInCriterionDefinition]
    let previousObservation: LiveObservation?
    let onSave: (LiveCheckInObservationPayload) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var understandingLevel: LiveObservationLevel
    @State private var engagementLevel: LiveObservationLevel
    @State private var supportLevel: LiveObservationLevel
    @State private var note: String
    @State private var checklistLevels: [String: LiveObservationLevel]
    @FocusState private var notesFocused: Bool

    init(
        student: Student,
        criteria: [LiveCheckInCriterionDefinition],
        previousObservation: LiveObservation?,
        onSave: @escaping (LiveCheckInObservationPayload) -> Void
    ) {
        self.student = student
        self.criteria = criteria
        self.previousObservation = previousObservation
        self.onSave = onSave
        _understandingLevel = State(initialValue: previousObservation?.understandingLevel ?? .developing)
        _engagementLevel = State(initialValue: previousObservation?.engagementLevel ?? .developing)
        _supportLevel = State(initialValue: previousObservation?.supportLevel ?? .developing)
        _note = State(initialValue: "")

        let previousChecklist = Dictionary(
            uniqueKeysWithValues: (previousObservation?.checklistResponses ?? []).map { ($0.criterionTitle, $0.level) }
        )
        var initialChecklistLevels: [String: LiveObservationLevel] = [:]
        for criterion in criteria {
            initialChecklistLevels[criterion.title] = previousChecklist[criterion.title] ?? .developing
        }
        _checklistLevels = State(initialValue: initialChecklistLevels)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                studentSummaryCard
                snapshotCard

                if !criteria.isEmpty {
                    checklistCard
                }

                notesCard
            }
            .padding(20)
        }
        .frame(minWidth: 720, minHeight: 680)
        .navigationTitle("Check-In".localized)
        .appSheetMotion()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save".localized) {
                    onSave(
                        LiveCheckInObservationPayload(
                            understandingLevel: understandingLevel,
                            engagementLevel: engagementLevel,
                            supportLevel: supportLevel,
                            note: note,
                            checklistResponses: criteria.map { criterion in
                                LiveCheckInChecklistResponsePayload(
                                    criterionTitle: criterion.title,
                                    level: checklistLevels[criterion.title] ?? .developing
                                )
                            }
                        )
                    )
                    dismiss()
                }
            }
        }
    }

    private var studentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.title2.weight(.bold))
                    Text("Core Snapshot".localized)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let previousObservation {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last check-in".localized)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(previousObservation.createdAt.appDateString(systemStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(previousObservation.createdAt.appTimeString(systemStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("First check-in today".localized, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                summaryPill(label: "Understanding".localized, level: understandingLevel)
                summaryPill(label: "Engagement".localized, level: engagementLevel)
                summaryPill(label: "Support".localized, level: supportLevel)
            }
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.indigo.opacity(0.12),
            tint: .indigo
        )
    }

    private var snapshotCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Core Snapshot".localized,
                subtitle: "Record how the student is doing right now.".localized
            )

            levelField(title: "Understanding".localized, selection: $understandingLevel)
            levelField(title: "Engagement".localized, selection: $engagementLevel)
            levelField(title: "Support Need".localized, selection: $supportLevel)
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Checklist".localized,
                subtitle: "Reusable and session-only criteria appear together here for this check-in.".localized
            )

            ForEach(criteria) { criterion in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(criterion.title)
                            .font(.subheadline.weight(.semibold))

                        Text(criterion.origin == .session ? "Session only".localized : "Template".localized)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(criterion.origin == .session ? .orange : .indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill((criterion.origin == .session ? Color.orange : Color.indigo).opacity(0.10))
                            )
                    }

                    levelField(
                        title: nil,
                        selection: Binding(
                            get: { checklistLevels[criterion.title] ?? .developing },
                            set: { checklistLevels[criterion.title] = $0 }
                        )
                    )
                }
            }
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.orange.opacity(0.12),
            tint: .orange
        )
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Notes".localized,
                subtitle: "Optional context that helps later when reviewing student progress.".localized
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.03))

                if note.isEmpty {
                    Text("Optional note".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $note)
                    .focused($notesFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120)
            }
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.teal.opacity(0.12),
            tint: .teal
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryPill(label: String, level: LiveObservationLevel) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(level.title)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(level.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(level.color.opacity(0.10))
        )
    }

    private func levelField(
        title: String?,
        selection: Binding<LiveObservationLevel>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(LiveObservationLevel.allCases, id: \.rawValue) { level in
                    Button {
                        selection.wrappedValue = level
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: level.systemImage)
                                .font(.body.weight(.semibold))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(selection.wrappedValue == level ? "Selected".localized : "Tap to choose".localized)
                                    .font(.caption2)
                                    .foregroundColor(selection.wrappedValue == level ? .white.opacity(0.85) : .secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .foregroundColor(selection.wrappedValue == level ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selection.wrappedValue == level ? level.color : level.color.opacity(0.09))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(level.color.opacity(selection.wrappedValue == level ? 0 : 0.20), lineWidth: 1)
                        )
                    }
                    .buttonStyle(AppPressableButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LiveCheckInTemplateManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appMotionContext) private var motion
    @Binding var selectedTemplateID: UUID?
    let sessionCriteria: [LiveCheckInSessionCriterion]
    let onSelectionApplied: (LiveCheckInFeedbackBannerState) -> Void
    @Query(sort: [SortDescriptor(\LiveObservationTemplate.sortOrder), SortDescriptor(\LiveObservationTemplate.createdAt)])
    private var templates: [LiveObservationTemplate]

    @State private var templateToEdit: LiveObservationTemplate?
    @State private var showingNewTemplateEditor = false
    @State private var feedbackBanner: LiveCheckInFeedbackBannerState?
    @State private var feedbackDismissTask: DispatchWorkItem?

    private var totalCriteriaCount: Int {
        templates.reduce(0) { $0 + $1.criteria.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reusable Templates".localized)
                                .font(.title3.weight(.semibold))
                            Text("Store checklists you want to reuse across future live check-ins. Session-only criteria do not appear here unless you save them as a template.".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button {
                            showingNewTemplateEditor = true
                        } label: {
                            Label("New Template".localized, systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        templateSummaryCard(
                            title: "Templates".localized,
                            value: "\(templates.count)",
                            icon: "square.stack.3d.up.fill",
                            tint: .indigo
                        )
                        templateSummaryCard(
                            title: "Criteria".localized,
                            value: "\(totalCriteriaCount)",
                            icon: "checklist.checked",
                            tint: .blue
                        )
                        templateSummaryCard(
                            title: "Session Extras".localized,
                            value: "\(sessionCriteria.count)",
                            icon: "sparkles.rectangle.stack",
                            tint: .orange
                        )
                    }

                    if !sessionCriteria.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .foregroundColor(.orange)
                                Text("Current Session Extras".localized)
                                    .font(.headline)
                            }
                            Text("These criteria are active only in the current session and will show in the check-in sheet, not in the reusable template list.".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                                ForEach(sessionCriteria) { criterion in
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text(criterion.title)
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.orange.opacity(0.10))
                                    )
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange.opacity(0.06))
                        )
                    }
                }
                .padding(18)
                .appCardStyle(
                    cornerRadius: 18,
                    borderColor: Color.indigo.opacity(0.12),
                    tint: .indigo
                )

                if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary)
                        Text("No Templates Yet".localized)
                            .font(.headline)
                        Text("Create a reusable checklist here when you want the same criteria available in future classes or sessions.".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            showingNewTemplateEditor = true
                        } label: {
                            Label("Create First Template".localized, systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .padding(.horizontal, 20)
                    .appCardStyle(
                        cornerRadius: 18,
                        borderColor: Color.gray.opacity(0.12),
                        tint: .gray
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Saved Templates".localized)
                                .font(.headline)
                            Spacer()
                            Text("\(templates.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.indigo.opacity(0.08))
                                )
                        }

                        ForEach(templates, id: \.id) { template in
                            templateRow(template)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 700, minHeight: 420)
        .navigationTitle("Checklist Templates".localized)
        .appSheetMotion()
        .overlay(alignment: .top) {
            if let feedbackBanner {
                LiveCheckInFeedbackBanner(state: feedbackBanner)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(motion.transition(.overlay))
                    .zIndex(2)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done".localized) {
                    dismiss()
                }
            }
        }
        .sheet(item: $templateToEdit) { template in
            NavigationStack {
                LiveCheckInTemplateEditorView(template: template) { savedTemplate in
                    selectedTemplateID = savedTemplate.id
                    templateToEdit = nil
                    presentFeedback(
                        LiveCheckInFeedbackBannerState(
                            icon: "square.and.pencil.circle.fill",
                            title: String(format: "Updated %@".localized, savedTemplate.title),
                            message: "This template is ready to reuse in future check-ins.".localized,
                            tint: .indigo
                        )
                    )
                }
            }
        }
        .sheet(isPresented: $showingNewTemplateEditor) {
            NavigationStack {
                LiveCheckInTemplateEditorView(template: nil) { savedTemplate in
                    selectedTemplateID = savedTemplate.id
                    showingNewTemplateEditor = false
                    presentFeedback(
                        LiveCheckInFeedbackBannerState(
                            icon: "plus.circle.fill",
                            title: String(format: "Saved %@".localized, savedTemplate.title),
                            message: "The template was added to your reusable library and selected for this session.".localized,
                            tint: .indigo
                        )
                    )
                }
            }
        }
    }

    private func templateSummaryCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tint)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: tint.opacity(0.12),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: tint
        )
    }

    private func templateRow(_ template: LiveObservationTemplate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.16), Color.blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)

                    Image(systemName: selectedTemplateID == template.id ? "checklist.checked" : "list.bullet.clipboard")
                        .foregroundColor(.indigo)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(template.title)
                            .font(.headline)

                        if selectedTemplateID == template.id {
                            Text("Selected".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.indigo.opacity(0.10))
                                )
                        }
                    }

                    Text(
                        String(
                            format: "%@ %@".localized,
                            "\(template.criteria.count)",
                            template.criteria.count == 1 ? "criterion".localized : "criteria".localized
                        )
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Text("Built for quick reuse during future live check-ins.".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if selectedTemplateID == template.id {
                        Button("Using Now".localized) {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Use in Session".localized) {
                            applyTemplate(template)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Menu {
                        Button("Edit".localized) {
                            templateToEdit = template
                        }
                        Button("Delete".localized, role: .destructive) {
                            if selectedTemplateID == template.id {
                                selectedTemplateID = nil
                            }
                            context.delete(template)
                            _ = SaveCoordinator.save(context: context, reason: "Delete live check-in template")
                        }
                    } label: {
                        Label("More".localized, systemImage: "ellipsis.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                ForEach(Array(template.criteria.sorted { $0.sortOrder < $1.sortOrder }.enumerated()), id: \.element.id) { index, criterion in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.indigo)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(Color.indigo.opacity(0.10))
                            )

                        Text(criterion.title)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.indigo.opacity(0.08))
                    )
                }
            }
        }
        .padding(16)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: selectedTemplateID == template.id ? Color.indigo.opacity(0.22) : Color.indigo.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .indigo
        )
    }

    private func applyTemplate(_ template: LiveObservationTemplate) {
        selectedTemplateID = template.id
        let feedback = LiveCheckInFeedbackBannerState(
            icon: "checklist.checked",
            title: String(format: "Using %@".localized, template.title),
            message: String(
                format: "%d reusable items are active for this session.".localized,
                template.criteria.count
            ),
            tint: .indigo
        )
        onSelectionApplied(feedback)
        dismiss()
    }

    private func presentFeedback(_ feedback: LiveCheckInFeedbackBannerState) {
        feedbackDismissTask?.cancel()
        withAnimation(motion.animation(.standard)) {
            feedbackBanner = feedback
        }

        let dismissTask = DispatchWorkItem {
            withAnimation(motion.animation(.quick)) {
                if feedbackBanner?.id == feedback.id {
                    feedbackBanner = nil
                }
            }
        }
        feedbackDismissTask = dismissTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissTask)
    }
}

private struct LiveCheckInTemplateEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let template: LiveObservationTemplate?
    let onSave: (LiveObservationTemplate) -> Void

    @State private var title: String
    @State private var criteriaTitles: [String]
    @State private var newCriterionTitle = ""

    init(
        template: LiveObservationTemplate?,
        onSave: @escaping (LiveObservationTemplate) -> Void
    ) {
        self.template = template
        self.onSave = onSave
        _title = State(initialValue: template?.title ?? "")
        _criteriaTitles = State(
            initialValue: template?.criteria
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.title) ?? []
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlatformSpacing.sectionSpacing) {
                headerCard
                templateDetailsCard
                criteriaCard

                if !trimmedTitle.isEmpty || !criteriaTitles.isEmpty {
                    previewCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .appSheetBackground(tint: .indigo)
        .navigationTitle(template == nil ? "New Template".localized : "Edit Template".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save".localized) {
                    saveTemplate()
                }
                .disabled(trimmedTitle.isEmpty)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 560)
        #endif
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewCriterion: String {
        newCriterionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addCriterion() {
        guard !trimmedNewCriterion.isEmpty else { return }
        criteriaTitles.append(trimmedNewCriterion)
        newCriterionTitle = ""
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.18), Color.blue.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: template == nil ? "list.bullet.clipboard.fill" : "square.and.pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(.indigo)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(template == nil ? "Build a Reusable Checklist".localized : "Refine This Template".localized)
                    .font(AppTypography.sectionTitle)

                Text("Create a short checklist you can reuse across future live check-ins. Keep criteria specific and easy to score in the moment.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.indigo.opacity(0.12),
            tint: .indigo
        )
    }

    private var templateDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template Details".localized)
                .font(AppTypography.sectionTitle)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title".localized)
                    .font(AppTypography.eyebrow)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextField("Template title".localized, text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .appFieldStyle(tint: .indigo, isInvalid: trimmedTitle.isEmpty && !title.isEmpty)

                Text("Example: Reading Conference Snapshot, Guided Group Observation, Writing Workshop Look-Fors".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.indigo.opacity(0.10),
            tint: .indigo
        )
    }

    private var criteriaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Criteria".localized)
                        .font(AppTypography.sectionTitle)

                    Text("Add the checkpoints you want to score quickly during a live check-in.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(criteriaTitles.count) " + "items".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(criteriaTitles.isEmpty ? .secondary : .indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((criteriaTitles.isEmpty ? Color.gray : Color.indigo).opacity(0.10))
                    )
            }

            if criteriaTitles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checklist.unchecked")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)

                    Text("No criteria yet".localized)
                        .font(.headline)

                    Text("Start with 3 to 5 short criteria so this checklist stays fast to use during class.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.gray.opacity(0.10),
                    shadowOpacity: 0.02,
                    shadowRadius: 4,
                    shadowY: 1,
                    tint: .gray
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(criteriaTitles.enumerated()), id: \.offset) { index, criterionTitle in
                        criterionRow(index: index, title: criterionTitle)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Add New Criterion".localized)
                    .font(AppTypography.eyebrow)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    TextField("Add criterion".localized, text: $newCriterionTitle)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .appFieldStyle(tint: .blue)

                    Button {
                        addCriterion()
                    } label: {
                        Label("Add".localized, systemImage: "plus.circle.fill")
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedNewCriterion.isEmpty)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.indigo.opacity(0.10),
            tint: .indigo
        )
    }

    private func criterionRow(index: Int, title: String) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundColor(.indigo)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.indigo.opacity(0.10))
                )

            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                criteriaTitles.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(AppPressableButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.indigo.opacity(0.08),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: .indigo
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview".localized)
                .font(AppTypography.sectionTitle)

            Text(trimmedTitle.isEmpty ? "Untitled Template".localized : trimmedTitle)
                .font(.headline)

            if criteriaTitles.isEmpty {
                Text("Criteria will appear here as you add them.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(Array(criteriaTitles.enumerated()), id: \.offset) { index, criterionTitle in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.indigo)
                            Text("\(index + 1). \(criterionTitle)")
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.indigo.opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.indigo.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .indigo
        )
    }

    private func saveTemplate() {
        let targetTemplate: LiveObservationTemplate
        if let template {
            targetTemplate = template
            targetTemplate.title = trimmedTitle
            targetTemplate.updatedAt = Date()
            for criterion in targetTemplate.criteria {
                context.delete(criterion)
            }
            targetTemplate.criteria.removeAll()
        } else {
            targetTemplate = LiveObservationTemplate(
                title: trimmedTitle,
                sortOrder: nextSortOrder
            )
            context.insert(targetTemplate)
        }

        targetTemplate.criteria = criteriaTitles.enumerated().map { index, criterionTitle in
            LiveObservationTemplateCriterion(
                title: criterionTitle,
                sortOrder: index,
                template: targetTemplate
            )
        }
        for criterion in targetTemplate.criteria {
            context.insert(criterion)
        }

        _ = SaveCoordinator.save(context: context, reason: "Save live check-in template")
        onSave(targetTemplate)
        dismiss()
    }

    private var nextSortOrder: Int {
        let descriptor = FetchDescriptor<LiveObservationTemplate>()
        let existingTemplates = (try? context.fetch(descriptor)) ?? []
        return existingTemplates.count
    }
}

private struct LiveCheckInLevelBadge: View {
    let level: LiveObservationLevel

    var body: some View {
        Label(level.title, systemImage: level.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundColor(level.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(level.color.opacity(0.10))
            )
    }
}

private struct LiveCheckInInlineStatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
    }
}

private struct LiveCheckInTopBadge: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
    }
}

private struct LiveCheckInFeedbackBannerState: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let tint: Color
}

private struct LiveCheckInFeedbackBanner: View {
    let state: LiveCheckInFeedbackBannerState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(state.tint.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: state.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(state.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(state.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(state.tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct LiveCheckInMiniLevelTag: View {
    let label: String
    let level: LiveObservationLevel

    var body: some View {
        Text("\(label): \(level.title)")
            .font(.caption)
            .foregroundColor(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(level.color.opacity(0.08))
            )
    }
}

private struct LiveCheckInCompactSignal: View {
    let level: LiveObservationLevel
    let letter: String

    var body: some View {
        HStack(spacing: 5) {
            Text(letter)
                .font(.caption2.weight(.bold))
            Circle()
                .fill(level.color)
                .frame(width: 7, height: 7)
            Text(level.title)
                .font(.caption2.weight(.medium))
        }
        .foregroundColor(level.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(level.color.opacity(0.10))
        )
    }
}

private struct LiveCheckInCriterionDefinition: Identifiable, Equatable {
    enum Origin {
        case template
        case session
    }

    let id: String
    let title: String
    let sortOrder: Int
    let origin: Origin
}

private struct LiveCheckInSessionCriterion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let sortOrder: Int

    init(id: UUID = UUID(), title: String, sortOrder: Int) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
    }
}

private struct LiveCheckInObservationPayload {
    let understandingLevel: LiveObservationLevel
    let engagementLevel: LiveObservationLevel
    let supportLevel: LiveObservationLevel
    let note: String
    let checklistResponses: [LiveCheckInChecklistResponsePayload]
}

private struct LiveCheckInChecklistResponsePayload {
    let criterionTitle: String
    let level: LiveObservationLevel
}

private struct LiveCheckInSeatCoordinate: Identifiable, Hashable {
    let row: Int
    let column: Int

    var id: String { "\(row)-\(column)" }
}
