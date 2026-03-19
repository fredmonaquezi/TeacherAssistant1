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
    let embeddedInLiveWorkspace: Bool
    let onOpenSeatingChart: (() -> Void)?

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
    @State private var selectedProgressStudent: Student?
    @State private var showingTemplateManager = false
    @State private var showingHistory = false
    @State private var feedbackBanner: LiveCheckInFeedbackBannerState?
    @State private var feedbackDismissTask: DispatchWorkItem?
    @Namespace private var filterSelectionNamespace

    private let calendar = Calendar.current

    init(
        schoolClass: SchoolClass,
        source: LiveObservationSource,
        showsDismissButton: Bool = false,
        embeddedInLiveWorkspace: Bool = false,
        onOpenSeatingChart: (() -> Void)? = nil
    ) {
        self.schoolClass = schoolClass
        self.source = source
        self.showsDismissButton = showsDismissButton
        self.embeddedInLiveWorkspace = embeddedInLiveWorkspace
        self.onOpenSeatingChart = onOpenSeatingChart
    }

    private var orderedStudents: [Student] {
        schoolClass.students.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var allObservationsDescending: [LiveObservation] {
        schoolClass.liveObservations.sorted { $0.createdAt > $1.createdAt }
    }

    private var todaysObservations: [LiveObservation] {
        allObservationsDescending.filter { observation in
            calendar.isDate(observation.sessionDate, inSameDayAs: startOfToday)
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

    private var latestRelevantObservationByStudentUUID: [UUID: LiveObservation] {
        var observations: [UUID: LiveObservation] = [:]
        for student in orderedStudents {
            if let todaysObservation = latestObservationByStudentTodayUUID[student.uuid] {
                observations[student.uuid] = todaysObservation
            } else if let latestObservation = latestObservationByStudentUUID[student.uuid] {
                observations[student.uuid] = latestObservation
            }
        }
        return observations
    }

    private var studentsNeedingSupportNow: Int {
        latestRelevantObservationByStudentUUID.values.filter(isNeedsSupport).count
    }

    private var templateLabel: String {
        activeTemplate?.title ?? "No Checklist".localized
    }

    private var checkedInProgress: Double {
        guard !orderedStudents.isEmpty else { return 0 }
        return Double(observedTodayUUIDs.count) / Double(orderedStudents.count)
    }

    private var pendingStudents: [Student] {
        orderedStudents.filter { latestObservationByStudentTodayUUID[$0.uuid] == nil }
            .filter(matchesCurrentFilter)
    }

    private var checkedInTodayEntries: [LiveCheckInTodayEntry] {
        orderedStudents.compactMap { student in
            guard let observation = latestObservationByStudentTodayUUID[student.uuid] else { return nil }
            return LiveCheckInTodayEntry(student: student, observation: observation)
        }
        .filter { entry in
            switch selectedFilter {
            case .all, .observedToday:
                return true
            case .notCheckedToday:
                return false
            case .needsSupport:
                return isNeedsSupport(entry.observation)
            }
        }
        .sorted { lhs, rhs in
            lhs.observation.createdAt > rhs.observation.createdAt
        }
    }

    private var historyDaySections: [LiveCheckInHistoryDaySection] {
        let grouped = Dictionary(grouping: allObservationsDescending) { observation in
            calendar.startOfDay(for: observation.sessionDate)
        }

        return grouped.keys
            .sorted(by: >)
            .map { date in
                LiveCheckInHistoryDaySection(
                    sessionDate: date,
                    observations: grouped[date, default: []].sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    private var previousHistoryDay: LiveCheckInHistoryDaySection? {
        historyDaySections.first { $0.sessionDate < startOfToday }
    }

    var body: some View {
        bodyPresentation
    }

    private var contentBody: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                headerCard
                    .appMotionReveal(index: 0)
                checklistCard
                    .appMotionReveal(index: 1)
                studentSurfaceCard
                    .appMotionReveal(index: 2)
                historySummaryCard
                    .appMotionReveal(index: 3)
            }
            .padding(.vertical, 20)
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
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                LiveCheckInHistoryView(
                    schoolClass: schoolClass,
                    daySections: historyDaySections
                )
            }
        }
        .sheet(item: $selectedProgressStudent) { student in
            NavigationStack {
                StudentProgressView(student: student)
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
        .animation(motion.animation(.quick), value: selectedTemplateID)
        .animation(motion.animation(.quick), value: feedbackBanner?.id)
        .macNavigationDepth()
    }

    @ViewBuilder
    private var bodyPresentation: some View {
        if embeddedInLiveWorkspace {
            contentBody
                .navigationTitle("Live Check-In".localized)
                .toolbar {
                    if showsDismissButton {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close".localized) {
                                dismiss()
                            }
                        }
                    }
                }
                .navigationDestination(item: $selectedStudent) { student in
                    LiveCheckInObservationEntryView(
                        student: student,
                        criteria: activeCriteria,
                        previousObservation: latestObservationByStudentUUID[student.uuid],
                        nextStudent: nextStudent(after: student),
                        showsExplicitCancelButton: false,
                        prefersSheetPresentation: false
                    ) { payload in
                        saveObservation(for: student, payload: payload)
                    } onSaveAndAdvance: { payload, nextStudent in
                        saveObservation(for: student, payload: payload)
                        selectedStudent = nextStudent
                    }
                }
        } else {
            contentBody
                .navigationTitle("Live Check-In".localized)
                .toolbar {
                    if showsDismissButton {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close".localized) {
                                dismiss()
                            }
                        }
                    }
                }
                .modifier(LiveCheckInSheetMotionModifier(isEnabled: true))
                .sheet(item: $selectedStudent) { student in
                    NavigationStack {
                        LiveCheckInObservationEntryView(
                            student: student,
                            criteria: activeCriteria,
                            previousObservation: latestObservationByStudentUUID[student.uuid],
                            nextStudent: nextStudent(after: student)
                        ) { payload in
                            saveObservation(for: student, payload: payload)
                        } onSaveAndAdvance: { payload, nextStudent in
                            saveObservation(for: student, payload: payload)
                            selectedStudent = nextStudent
                        }
                    }
                }
        }
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
                        icon: "calendar.badge.clock",
                        title: "Active Day: Today".localized,
                        tint: .blue
                    )

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
                    icon: "list.bullet.rectangle.portrait",
                    title: "Roster View".localized,
                    tint: .secondary
                )
                if !sessionExtraCriteria.isEmpty {
                    LiveCheckInTopBadge(
                        icon: "sparkles.rectangle.stack",
                        title: "\(sessionExtraCriteria.count) " + "session extras".localized,
                        tint: .orange
                    )
                }
                if onOpenSeatingChart != nil {
                    Button {
                        onOpenSeatingChart?()
                    } label: {
                        Label("Open Seating Chart".localized, systemImage: "chair.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assess Students".localized)
                        .font(AppTypography.sectionTitle)
                    Text("Work from today’s roster first. Students move into the review section as soon as you save a live check-in.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(Date().appDateString(systemStyle: .full))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if pendingStudents.isEmpty && checkedInTodayEntries.isEmpty {
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
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !pendingStudents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeaderLabel(
                                title: "Pending Students".localized,
                                subtitle: String(
                                    format: "%d still waiting for today’s check-in.".localized,
                                    pendingStudents.count
                                ),
                                tint: .orange
                            )
                            pendingStudentGrid(pendingStudents)
                        }
                    }

                    if !checkedInTodayEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeaderLabel(
                                title: "Checked In Today".localized,
                                subtitle: String(
                                    format: "%d students already reviewed today.".localized,
                                    checkedInTodayEntries.count
                                ),
                                tint: .green
                            )
                            checkedInTodayList
                        }
                    }
                }
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

    private func sectionHeaderLabel(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func pendingStudentGrid(_ students: [Student]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            ForEach(students, id: \.id) { student in
                LiveCheckInStudentCard(
                    student: student,
                    latestObservation: latestObservationByStudentUUID[student.uuid],
                    observedToday: false,
                    onCheckIn: {
                        selectedStudent = student
                    },
                    onOpenHistory: {
                        selectedProgressStudent = student
                    }
                )
                .transition(motion.transition(.inlineChange))
            }
        }
    }

    private var checkedInTodayList: some View {
        VStack(spacing: 12) {
            ForEach(checkedInTodayEntries) { entry in
                LiveCheckInCheckedInRow(
                    student: entry.student,
                    observation: entry.observation,
                    onOpenCheckIn: {
                        selectedStudent = entry.student
                    },
                    onOpenHistory: {
                        selectedProgressStudent = entry.student
                    }
                )
            }
        }
    }

    private var historySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Check-In History".localized)
                        .font(AppTypography.sectionTitle)
                    Text("Review today, compare previous check-in days, and open the full class history when you need more context.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("View History".localized) {
                    showingHistory = true
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                liveStatCard(
                    title: "Today".localized,
                    value: "\(todaysObservations.count)",
                    color: .blue,
                    icon: "calendar"
                )
                liveStatCard(
                    title: "Previous Day".localized,
                    value: previousHistoryDay.map { $0.sessionDate.appDateString(systemStyle: .short) } ?? "None".localized,
                    color: .indigo,
                    icon: "clock.arrow.circlepath"
                )
                liveStatCard(
                    title: "Total Snapshots".localized,
                    value: "\(allObservationsDescending.count)",
                    color: .teal,
                    icon: "waveform.path.ecg"
                )
            }

            if let previousHistoryDay {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Previous Day With Check-Ins".localized)
                        .font(.subheadline.weight(.semibold))
                    Text(
                        String(
                            format: "%@ • %d snapshot(s)".localized,
                            previousHistoryDay.sessionDate.appDateString(systemStyle: .full),
                            previousHistoryDay.observations.count
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else {
                Text("Previous live check-in days will appear here after you have history to compare.".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

    private func matchesCurrentFilter(_ student: Student) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .needsSupport:
            guard let observation = latestRelevantObservationByStudentUUID[student.uuid] else {
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

    private func nextStudent(after student: Student) -> Student? {
        let sequence = navigationSequenceStudents
        guard let currentIndex = sequence.firstIndex(where: { $0.uuid == student.uuid }) else {
            return nil
        }

        let nextIndex = sequence.index(after: currentIndex)
        guard sequence.indices.contains(nextIndex) else {
            return nil
        }
        return sequence[nextIndex]
    }

    private var navigationSequenceStudents: [Student] {
        switch selectedFilter {
        case .all, .notCheckedToday:
            return pendingStudents
        case .observedToday:
            return checkedInTodayEntries.map(\.student)
        case .needsSupport:
            return pendingStudents + checkedInTodayEntries.map(\.student)
        }
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
    let onCheckIn: () -> Void
    let onOpenHistory: () -> Void

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
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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

            HStack(spacing: 10) {
                Button(observedToday ? "Open Check-In".localized : "Start Check-In".localized) {
                    onCheckIn()
                }
                .buttonStyle(.borderedProminent)

                Button("History".localized) {
                    onOpenHistory()
                }
                .buttonStyle(.bordered)
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

    private var statusSubtitle: String {
        guard let latestObservation else {
            return "Ready for today’s check-in.".localized
        }
        if observedToday {
            return "Latest check-in saved today.".localized
        }
        return String(
            format: "Last snapshot: %@".localized,
            latestObservation.sessionDate.appDateString(systemStyle: .short)
        )
    }
}

private struct LiveCheckInCheckedInRow: View {
    let student: Student
    let observation: LiveObservation?
    let onOpenCheckIn: () -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.headline)
                    if let observation {
                        Text(
                            String(
                                format: "Checked in at %@".localized,
                                observation.createdAt.appTimeString(systemStyle: .short)
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let observation {
                    LiveCheckInLevelBadge(level: observation.supportLevel)
                }
            }

            if let observation {
                HStack(spacing: 8) {
                    LiveCheckInMiniLevelTag(label: "Understanding".localized, level: observation.understandingLevel)
                    LiveCheckInMiniLevelTag(label: "Engagement".localized, level: observation.engagementLevel)
                    LiveCheckInMiniLevelTag(label: "Support".localized, level: observation.supportLevel)
                }

                if !observation.checklistResponses.isEmpty {
                    Label(
                        String(format: "%d checklist item(s)".localized, observation.checklistResponses.count),
                        systemImage: "checklist"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if !observation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(observation.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Button("Update".localized) {
                    onOpenCheckIn()
                }
                .buttonStyle(.borderedProminent)

                Button("History".localized) {
                    onOpenHistory()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: (observation?.supportLevel.color ?? .green).opacity(0.18),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: observation?.supportLevel.color ?? .green
        )
    }
}

private struct LiveCheckInHistoryView: View {
    let schoolClass: SchoolClass
    let daySections: [LiveCheckInHistoryDaySection]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressStudent: Student?
    @State private var selectedObservation: LiveObservation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                historyOverviewCard

                if daySections.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary)
                        Text("No Live Check-In History Yet".localized)
                            .font(.headline)
                        Text("Snapshots will appear here after you save live check-ins on one or more days.".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .appCardStyle(
                        cornerRadius: 18,
                        borderColor: Color.secondary.opacity(0.10),
                        tint: .secondary
                    )
                } else {
                    ForEach(daySections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.sessionDate.appDateString(systemStyle: .full))
                                .font(.headline)
                            Text(
                                String(
                                    format: "%d snapshot(s)".localized,
                                    section.observations.count
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)

                            ForEach(section.observations, id: \.id) { observation in
                                LiveCheckInHistoryRow(
                                    observation: observation,
                                    onOpenDetail: {
                                        selectedObservation = observation
                                    },
                                    onOpenProgress: observation.student == nil ? nil : {
                                        selectedProgressStudent = observation.student
                                    }
                                )
                            }
                        }
                        .padding(16)
                        .appCardStyle(
                            cornerRadius: 18,
                            borderColor: Color.indigo.opacity(0.10),
                            tint: .indigo
                        )
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Live Check-In History".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done".localized) {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedProgressStudent) { student in
            NavigationStack {
                StudentProgressView(student: student)
            }
        }
        .sheet(item: $selectedObservation) { observation in
            NavigationStack {
                LiveCheckInObservationHistoryDetailView(observation: observation)
            }
        }
        .appSheetMotion()
    }

    private var historyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Class History".localized)
                .font(AppTypography.sectionTitle)
            Text(schoolClass.name)
                .font(.headline)
            Text("Compare performance day by day and open individual student progress when you need a deeper trend.".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                historyMetric(title: "Days".localized, value: "\(daySections.count)", tint: .indigo)
                historyMetric(
                    title: "Snapshots".localized,
                    value: "\(daySections.reduce(0) { $0 + $1.observations.count })",
                    tint: .blue
                )
            }
        }
        .padding(18)
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.indigo.opacity(0.12),
            tint: .indigo
        )
    }

    private func historyMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(tint)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct LiveCheckInHistoryRow: View {
    let observation: LiveObservation
    let onOpenDetail: () -> Void
    let onOpenProgress: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(observation.student?.name ?? observation.studentNameSnapshot)
                                .font(.headline)
                                .foregroundColor(.primary)
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
                        .lineLimit(2)
                    }

                    if !observation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(observation.note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(AppPressableButtonStyle())

            if let onOpenProgress {
                Button("Open Student Progress".localized) {
                    onOpenProgress()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: observation.supportLevel.color.opacity(0.16),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: observation.supportLevel.color
        )
    }
}

private struct LiveCheckInObservationHistoryDetailView: View {
    let observation: LiveObservation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(observation.student?.name ?? observation.studentNameSnapshot)
                        .font(.title2.weight(.bold))
                    Text(observation.sessionDate.appDateString(systemStyle: .full))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(observation.createdAt.appTimeString(systemStyle: .short))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        LiveCheckInMiniLevelTag(label: "Understanding".localized, level: observation.understandingLevel)
                        LiveCheckInMiniLevelTag(label: "Engagement".localized, level: observation.engagementLevel)
                        LiveCheckInMiniLevelTag(label: "Support".localized, level: observation.supportLevel)
                    }
                }
                .padding(18)
                .appCardStyle(
                    cornerRadius: 18,
                    borderColor: observation.supportLevel.color.opacity(0.16),
                    tint: observation.supportLevel.color
                )

                if !observation.checklistResponses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Checklist".localized)
                            .font(AppTypography.sectionTitle)

                        ForEach(observation.checklistResponses.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { response in
                            HStack {
                                Text(response.criterionTitle)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                LiveCheckInLevelBadge(level: response.level)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(response.level.color.opacity(0.08))
                            )
                        }
                    }
                    .padding(18)
                    .appCardStyle(
                        cornerRadius: 18,
                        borderColor: Color.indigo.opacity(0.10),
                        tint: .indigo
                    )
                }

                if !observation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes".localized)
                            .font(AppTypography.sectionTitle)
                        Text(observation.note)
                            .font(.subheadline)
                    }
                    .padding(18)
                    .appCardStyle(
                        cornerRadius: 18,
                        borderColor: Color.teal.opacity(0.10),
                        tint: .teal
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle("Snapshot Detail".localized)
        .appSheetMotion()
    }
}

private struct LiveCheckInObservationEntryView: View {
    let student: Student
    let criteria: [LiveCheckInCriterionDefinition]
    let previousObservation: LiveObservation?
    let nextStudent: Student?
    let showsExplicitCancelButton: Bool
    let prefersSheetPresentation: Bool
    let onSave: (LiveCheckInObservationPayload) -> Void
    let onSaveAndAdvance: ((LiveCheckInObservationPayload, Student) -> Void)?

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
        nextStudent: Student? = nil,
        showsExplicitCancelButton: Bool = true,
        prefersSheetPresentation: Bool = true,
        onSave: @escaping (LiveCheckInObservationPayload) -> Void,
        onSaveAndAdvance: ((LiveCheckInObservationPayload, Student) -> Void)? = nil
    ) {
        self.student = student
        self.criteria = criteria
        self.previousObservation = previousObservation
        self.nextStudent = nextStudent
        self.showsExplicitCancelButton = showsExplicitCancelButton
        self.prefersSheetPresentation = prefersSheetPresentation
        self.onSave = onSave
        self.onSaveAndAdvance = onSaveAndAdvance
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
        .navigationTitle("Check-In".localized)
        .toolbar {
            if showsExplicitCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save".localized) {
                    onSave(makePayload())
                    dismiss()
                }
            }

            if let nextStudent, let onSaveAndAdvance {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save & Next".localized) {
                        onSaveAndAdvance(makePayload(), nextStudent)
                    }
                }
            }
        }
        .modifier(LiveCheckInSheetMotionModifier(isEnabled: prefersSheetPresentation))
        .modifier(LiveCheckInObservationFrameModifier(isEnabled: prefersSheetPresentation))
    }

    private func makePayload() -> LiveCheckInObservationPayload {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 420)
        #endif
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

private struct LiveCheckInTodayEntry: Identifiable {
    let student: Student
    let observation: LiveObservation

    var id: UUID { student.uuid }
}

private struct LiveCheckInHistoryDaySection: Identifiable {
    let sessionDate: Date
    let observations: [LiveObservation]

    var id: Date { sessionDate }
}

private struct LiveCheckInSheetMotionModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.appSheetMotion()
        } else {
            content
        }
    }
}

private struct LiveCheckInObservationFrameModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        if isEnabled {
            content.frame(minWidth: 720, minHeight: 680)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
