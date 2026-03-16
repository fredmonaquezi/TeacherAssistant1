import SwiftUI
import SwiftData

struct SeatingChartView: View {
    enum ClassroomMode: String, CaseIterable, Identifiable {
        case layout
        case participation
        case behaviorSupport

        var id: String { rawValue }
    }

    @Bindable var schoolClass: SchoolClass
    let showsDismissButton: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var editingSeat: SeatCoordinate?
    @State private var showingClearChartAlert = false
    @State private var selectedMode: ClassroomMode = .layout
    @State private var recentParticipationPulseID: UUID?
    @State private var recentBehaviorPulseID: UUID?

    init(schoolClass: SchoolClass, showsDismissButton: Bool = false) {
        self.schoolClass = schoolClass
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

    private var seatCount: Int {
        chart?.activeSeatCount ?? 0
    }

    private var seatedCount: Int {
        chart?.placements.count ?? 0
    }

    private var unseatedStudents: [Student] {
        let seatedUUIDs = Set(chart?.placements.map(\.studentUUID) ?? [])
        return orderedStudents.filter { !seatedUUIDs.contains($0.uuid) }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(160), spacing: 12), count: max(chart?.columns ?? 1, 1))
    }

    private var allSeatCoordinates: [SeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.rows).flatMap { row in
            (0..<chart.columns).map { column in
                SeatCoordinate(row: row, column: column)
            }
        }
    }

    private var activeSeatCoordinates: [SeatCoordinate] {
        guard let chart else { return [] }
        return allSeatCoordinates.filter { chart.isActiveSeat(row: $0.row, column: $0.column) }
    }

    private var centerGroupSize: Int {
        chart?.validatedCenterGroupSize ?? 4
    }

    private var centerGroups: [[SeatCoordinate]] {
        activeSeatCoordinates.chunked(into: centerGroupSize)
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todaysParticipationEvents: [ParticipationEvent] {
        schoolClass.participationEvents
            .filter { $0.createdAt >= startOfToday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var participationCountsToday: [UUID: Int] {
        Dictionary(
            grouping: todaysParticipationEvents,
            by: \.studentUUID
        ).mapValues(\.count)
    }

    private var activeParticipantsToday: Int {
        participationCountsToday.values.filter { $0 > 0 }.count
    }

    private var todaysBehaviorSupportEvents: [BehaviorSupportEvent] {
        schoolClass.behaviorSupportEvents
            .filter { $0.createdAt >= startOfToday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var behaviorCountsToday: [UUID: Int] {
        Dictionary(
            grouping: todaysBehaviorSupportEvents,
            by: \.studentUUID
        ).mapValues(\.count)
    }

    private var supportSignalsToday: Int {
        Set(
            todaysBehaviorSupportEvents
                .filter { $0.kind.shouldFlagNeedsHelp }
                .map(\.studentUUID)
        ).count
    }

    private var positiveBehaviorToday: Int {
        todaysBehaviorSupportEvents.filter { $0.kind == .positiveBehavior }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                heroCard
                controlsCard
                chartCard
                activityFeedCard
                unseatedCard
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Seating Chart".localized)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        autoArrangeStudents()
                    } label: {
                        Label("Auto Arrange".localized, systemImage: "sparkles.rectangle.stack")
                    }
                    .disabled(orderedStudents.isEmpty)

                    Button(role: .destructive) {
                        showingClearChartAlert = true
                    } label: {
                        Label("Clear Chart".localized, systemImage: "trash")
                    }
                    .disabled(seatedCount == 0)
                } label: {
                    Label("Actions".localized, systemImage: "ellipsis.circle")
                }
            }
        }
        .task {
            ensureChartExists()
            syncChartWithRoster()
        }
        .onAppear {
            ensureChartExists()
            syncChartWithRoster()
        }
        .onChange(of: schoolClass.students.count) { _, _ in
            syncChartWithRoster()
        }
        .sheet(item: $editingSeat) { coordinate in
            NavigationStack {
                SeatAssignmentSheet(
                    schoolClass: schoolClass,
                    currentPlacement: placement(at: coordinate),
                    onAssign: { student in
                        assign(student: student, to: coordinate)
                    },
                    onClear: {
                        clearSeat(at: coordinate)
                    },
                    locationTitle: seatLabel(for: coordinate)
                )
            }
        }
        .alert("Clear Seating Chart?".localized, isPresented: $showingClearChartAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Clear".localized, role: .destructive) {
                clearAllSeats()
            }
        } message: {
            Text("This removes all current seat assignments for this class.".localized)
        }
        .macNavigationDepth()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seating Chart".localized)
                        .font(.title3.weight(.semibold))
                    Text("Lay out the room, seat students quickly, and keep the chart ready for live classroom tools.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Auto Arrange".localized) {
                    autoArrangeStudents()
                }
                .buttonStyle(.borderedProminent)
                .disabled(orderedStudents.isEmpty)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                overviewStat(
                    title: "Students".localized,
                    value: "\(orderedStudents.count)",
                    color: .blue
                )
                overviewStat(
                    title: "Seated".localized,
                    value: "\(seatedCount)",
                    color: seatedCount == orderedStudents.count ? .green : .teal
                )
                overviewStat(
                    title: "Unseated".localized,
                    value: "\(unseatedStudents.count)",
                    color: unseatedStudents.isEmpty ? .green : .orange
                )
                overviewStat(
                    title: "Seats".localized,
                    value: "\(seatCount)",
                    color: seatCount >= orderedStudents.count ? .indigo : .red
                )
                overviewStat(
                    title: "Format".localized,
                    value: layoutStyleSummary,
                    color: .purple
                )
                overviewStat(
                    title: "Participation Today".localized,
                    value: "\(todaysParticipationEvents.count)",
                    color: todaysParticipationEvents.isEmpty ? .secondary : .pink
                )
                overviewStat(
                    title: "Active Speakers".localized,
                    value: "\(activeParticipantsToday)",
                    color: activeParticipantsToday == 0 ? .secondary : .green
                )
                overviewStat(
                    title: "Behavior Logs Today".localized,
                    value: "\(todaysBehaviorSupportEvents.count)",
                    color: todaysBehaviorSupportEvents.isEmpty ? .secondary : .orange
                )
                overviewStat(
                    title: "Positive Notes".localized,
                    value: "\(positiveBehaviorToday)",
                    color: positiveBehaviorToday == 0 ? .secondary : .green
                )
                overviewStat(
                    title: "Support Signals".localized,
                    value: "\(supportSignalsToday)",
                    color: supportSignalsToday == 0 ? .secondary : .red
                )
            }

            if seatCount < orderedStudents.count {
                Label(
                    String(
                        format: languageManager.localized("Add %d more seat%@ or increase rows and columns to fit everyone."),
                        orderedStudents.count - seatCount,
                        orderedStudents.count - seatCount == 1 ? "" : "s"
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundColor(.orange)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.indigo.opacity(0.12),
            tint: .indigo
        )
        .padding(.horizontal)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Room Format".localized)
                    .font(AppTypography.sectionTitle)

                Picker("Room Format".localized, selection: Binding(
                    get: { layoutStyle },
                    set: { applyLayoutStyle($0) }
                )) {
                    Text("Rows".localized).tag(SeatingLayoutStyle.rows)
                    Text("Duos".localized).tag(SeatingLayoutStyle.duos)
                    Text("U-Shape".localized).tag(SeatingLayoutStyle.uShape)
                    Text("Centers".localized).tag(SeatingLayoutStyle.centers)
                }
                .pickerStyle(.segmented)

                Text(layoutStyleDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if layoutStyle == .centers {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Center Size".localized)
                        .font(.subheadline.weight(.semibold))

                    Picker("Center Size".localized, selection: Binding(
                        get: { centerGroupSize },
                        set: { updateCenterGroupSize($0) }
                    )) {
                        Text("3 per center".localized).tag(3)
                        Text("4 per center".localized).tag(4)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Text("Classroom Mode".localized)
                .font(AppTypography.sectionTitle)

            Picker("Classroom Mode".localized, selection: $selectedMode) {
                Text("Seat Editing".localized).tag(ClassroomMode.layout)
                Text("Participation".localized).tag(ClassroomMode.participation)
                Text("Behavior / Support".localized).tag(ClassroomMode.behaviorSupport)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                Stepper(
                    value: Binding(
                        get: { chart?.rows ?? 1 },
                        set: { updateLayout(rows: $0, columns: nil) }
                    ),
                    in: 1...12
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rows".localized)
                            .font(.subheadline.weight(.medium))
                        Text("\(chart?.rows ?? 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Stepper(
                    value: Binding(
                        get: { chart?.columns ?? 1 },
                        set: { updateLayout(rows: nil, columns: $0) }
                    ),
                    in: 1...10
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Columns".localized)
                            .font(.subheadline.weight(.medium))
                        Text("\(chart?.columns ?? 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(selectedMode == .participation)

            Text(
                selectedMode == .layout
                ? layoutInteractionText
                : selectedMode == .participation
                ? "Tap any occupied seat to log a participation moment instantly. Use the menu on each seat for leadership or collaboration tags.".localized
                : "Tap any occupied seat to log a support check-in instantly. Use the menu on each seat for positive behavior, support, or redirect tags.".localized
            )
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.indigo.opacity(0.1),
            tint: .indigo
        )
        .padding(.horizontal)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(chartTitle)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text(chartStatusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if orderedStudents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("No students in this class".localized)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.secondary)
                    Text("Add students first, then come back to build the seating chart.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.indigo.opacity(0.08),
                    tint: .indigo
                )
                .padding(.horizontal)
            } else {
                seatingSurface
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var seatingSurface: some View {
        switch layoutStyle {
        case .rows:
            standardRowsSurface(groupAsDuos: false)
        case .duos:
            standardRowsSurface(groupAsDuos: true)
        case .uShape:
            uShapeSurface
        case .centers:
            centersSurface
        }
    }

    private func standardRowsSurface(groupAsDuos: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "Row %d".localized, row + 1))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        if groupAsDuos {
                            HStack(alignment: .top, spacing: 24) {
                                ForEach(rowSeatCoordinates(for: row).chunked(into: 2).indices, id: \.self) { groupIndex in
                                    HStack(spacing: 12) {
                                        ForEach(rowSeatCoordinates(for: row).chunked(into: 2)[groupIndex]) { coordinate in
                                            seatButton(for: coordinate)
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(rowSeatCoordinates(for: row)) { coordinate in
                                    seatButton(for: coordinate)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private var uShapeSurface: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(rowSeatCoordinates(for: row)) { coordinate in
                            if chart?.isActiveSeat(row: coordinate.row, column: coordinate.column) == true {
                                seatButton(for: coordinate)
                            } else {
                                inactiveSeatPlaceholder
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private var centersSurface: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(centerGroups.enumerated()), id: \.offset) { index, group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(
                                String(format: "Center %d".localized, index + 1),
                                systemImage: "circle.grid.2x2.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.indigo)

                            Spacer()

                            Text("\(group.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        if centerGroupSize == 4 {
                            LazyVGrid(columns: [GridItem(.fixed(160), spacing: 12), GridItem(.fixed(160), spacing: 12)], spacing: 12) {
                                ForEach(group) { coordinate in
                                    seatButton(for: coordinate)
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(group) { coordinate in
                                    seatButton(for: coordinate)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .appCardStyle(
                        cornerRadius: 16,
                        borderColor: Color.indigo.opacity(0.12),
                        shadowOpacity: 0.03,
                        shadowRadius: 5,
                        shadowY: 2,
                        tint: .indigo
                    )
                }
            }
            .padding(.bottom, 6)
        }
    }

    private var inactiveSeatPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Space".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Text("No seat in this layout".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160, height: 118, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        )
    }

    @ViewBuilder
    private var activityFeedCard: some View {
        switch selectedMode {
        case .layout, .participation:
            participationFeedCard
        case .behaviorSupport:
            behaviorSupportFeedCard
        }
    }

    private var participationFeedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Participation".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(todaysParticipationEvents.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if todaysParticipationEvents.isEmpty {
                Label(
                    "No participation moments logged yet today.".localized,
                    systemImage: "waveform.badge.magnifyingglass"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(todaysParticipationEvents.prefix(10), id: \.id) { event in
                        participationRow(for: event)
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.pink.opacity(0.1),
            tint: .pink
        )
        .padding(.horizontal)
    }

    private var behaviorSupportFeedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Behavior & Support".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(todaysBehaviorSupportEvents.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if todaysBehaviorSupportEvents.isEmpty {
                Label(
                    "No behavior or support moments logged yet today.".localized,
                    systemImage: "shield.lefthalf.filled.badge.checkmark"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(todaysBehaviorSupportEvents.prefix(10), id: \.id) { event in
                        behaviorSupportRow(for: event)
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.1),
            tint: .orange
        )
        .padding(.horizontal)
    }

    private var unseatedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Unseated Students".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("\(unseatedStudents.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if unseatedStudents.isEmpty {
                Label("Everyone is currently seated.".localized, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(unseatedStudents, id: \.id) { student in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text(initials(for: student.name))
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.orange)
                                }

                            Text(student.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .appCardStyle(
                            cornerRadius: 10,
                            borderColor: Color.orange.opacity(0.12),
                            shadowOpacity: 0.02,
                            shadowRadius: 4,
                            shadowY: 1,
                            tint: .orange
                        )
                    }
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.orange.opacity(0.1),
            tint: .orange
        )
        .padding(.horizontal)
    }

    private func overviewStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundColor(color)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: color.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: color
        )
    }

    private func seatButton(for coordinate: SeatCoordinate) -> some View {
        let currentPlacement = placement(at: coordinate)
        let isOccupied = currentPlacement != nil
        let participationCount = currentPlacement.map { participationCountsToday[$0.studentUUID] ?? 0 } ?? 0
        let behaviorCount = currentPlacement.map { behaviorCountsToday[$0.studentUUID] ?? 0 } ?? 0
        let latestBehaviorEvent = currentPlacement.flatMap { latestBehaviorSupportEvent(for: $0.studentUUID) }
        let isRecentlyLogged = isSeatRecentlyLogged(for: currentPlacement?.studentUUID)

        return Button {
            handleSeatTap(at: coordinate)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(seatLabel(for: coordinate))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    if selectedMode == .participation, isOccupied {
                        participationBadge(count: participationCount, highlighted: isRecentlyLogged)
                    } else if selectedMode == .behaviorSupport, isOccupied {
                        behaviorBadge(
                            count: behaviorCount,
                            latestEvent: latestBehaviorEvent,
                            highlighted: isRecentlyLogged
                        )
                    }
                }

                Spacer()

                if let currentPlacement {
                    Text(currentPlacement.studentNameSnapshot)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(
                        selectedMode == .layout
                        ? "Tap to move or reassign".localized
                        : selectedMode == .participation
                        ? "Tap to log contribution".localized
                        : "Tap to log support".localized
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.indigo)
                        Text("Assign Student".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.indigo)
                    }
                }
            }
            .frame(width: 160, height: 118, alignment: .leading)
            .padding(12)
            .appCardStyle(
                cornerRadius: 14,
                borderColor: seatBorderColor(
                    isOccupied: isOccupied,
                    isRecentlyLogged: isRecentlyLogged,
                    latestBehaviorEvent: latestBehaviorEvent
                ),
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: seatTintColor(
                    isOccupied: isOccupied,
                    isRecentlyLogged: isRecentlyLogged,
                    latestBehaviorEvent: latestBehaviorEvent
                )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if selectedMode == .layout {
                Button {
                    editingSeat = coordinate
                } label: {
                    Label("Assign Student".localized, systemImage: "person.crop.square")
                }

                if currentPlacement != nil {
                    Button(role: .destructive) {
                        clearSeat(at: coordinate)
                    } label: {
                        Label("Clear Seat".localized, systemImage: "trash")
                    }
                }
            } else if selectedMode == .participation,
                      let currentPlacement,
                      let student = student(for: currentPlacement.studentUUID) {
                ForEach(ParticipationEventKind.allCases, id: \.rawValue) { kind in
                    Button {
                        logParticipation(for: student, kind: kind)
                    } label: {
                        Label(kind.title, systemImage: icon(for: kind))
                    }
                }

                if let latestEvent = latestParticipationEvent(for: student.uuid) {
                    Button(role: .destructive) {
                        removeParticipationEvent(latestEvent)
                    } label: {
                        Label("Undo Last Entry".localized, systemImage: "arrow.uturn.backward")
                    }
                }
            } else if selectedMode == .behaviorSupport,
                      let currentPlacement,
                      let student = student(for: currentPlacement.studentUUID) {
                ForEach(BehaviorSupportEventKind.allCases, id: \.rawValue) { kind in
                    Button {
                        logBehaviorSupport(for: student, kind: kind)
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }

                if student.needsHelp {
                    Button {
                        student.needsHelp = false
                        _ = SaveCoordinator.save(context: context, reason: "Clear support flag")
                    } label: {
                        Label("Clear Needs Help Flag".localized, systemImage: "checkmark.circle")
                    }
                }

                if let latestEvent = latestBehaviorSupportEvent(for: student.uuid) {
                    Button(role: .destructive) {
                        removeBehaviorSupportEvent(latestEvent)
                    } label: {
                        Label("Undo Last Entry".localized, systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
    }

    private func participationRow(for event: ParticipationEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color(for: event.kind).opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon(for: event.kind))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(color(for: event.kind))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.studentNameSnapshot)
                    .font(.subheadline.weight(.semibold))
                Text(event.kind.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(color(for: event.kind))
            }

            Spacer()

            Text(event.createdAt, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appCardStyle(
            cornerRadius: 10,
            borderColor: color(for: event.kind).opacity(0.12),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: color(for: event.kind)
        )
        .contextMenu {
            Button(role: .destructive) {
                removeParticipationEvent(event)
            } label: {
                Label("Delete Entry".localized, systemImage: "trash")
            }
        }
    }

    private func participationBadge(count: Int, highlighted: Bool) -> some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundColor(highlighted ? .white : .pink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(highlighted ? Color.pink : Color.pink.opacity(0.12))
            )
    }

    private func behaviorBadge(
        count: Int,
        latestEvent: BehaviorSupportEvent?,
        highlighted: Bool
    ) -> some View {
        let color = latestEvent?.kind.color ?? .orange
        return Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundColor(highlighted ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(highlighted ? color : color.opacity(0.12))
            )
    }

    private func behaviorSupportRow(for event: BehaviorSupportEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.kind.color.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: event.kind.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(event.kind.color)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.studentNameSnapshot)
                    .font(.subheadline.weight(.semibold))
                Text(event.kind.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(event.kind.color)
            }

            Spacer()

            Text(event.createdAt, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appCardStyle(
            cornerRadius: 10,
            borderColor: event.kind.color.opacity(0.12),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: event.kind.color
        )
        .contextMenu {
            Button(role: .destructive) {
                removeBehaviorSupportEvent(event)
            } label: {
                Label("Delete Entry".localized, systemImage: "trash")
            }
        }
    }

    private func ensureChartExists() {
        guard schoolClass.seatingChart == nil else { return }

        let dimensions = defaultDimensions(for: max(orderedStudents.count, 1))
        let chart = SeatingChart(
            title: "\(schoolClass.name) Layout",
            rows: dimensions.rows,
            columns: dimensions.columns
        )
        chart.schoolClass = schoolClass
        schoolClass.seatingChart = chart
        context.insert(chart)
        _ = SaveCoordinator.save(context: context, reason: "Create seating chart")
    }

    private func handleSeatTap(at coordinate: SeatCoordinate) {
        guard let currentPlacement = placement(at: coordinate) else {
            if selectedMode == .layout {
                editingSeat = coordinate
            }
            return
        }

        if selectedMode == .layout {
            editingSeat = coordinate
            return
        }

        guard let student = student(for: currentPlacement.studentUUID) else { return }
        if selectedMode == .participation {
            logParticipation(for: student, kind: .contribution)
        } else {
            logBehaviorSupport(for: student, kind: .supportCheckIn)
        }
    }

    private func syncChartWithRoster() {
        guard let chart else { return }

        let rosterByUUID = Dictionary(uniqueKeysWithValues: orderedStudents.map { ($0.uuid, $0) })
        var seenStudentUUIDs: Set<UUID> = []
        var seenCoordinates: Set<String> = []
        var deletedPlacementIDs: Set<UUID> = []

        for placement in chart.placements {
            let coordinateKey = "\(placement.row)-\(placement.column)"
            guard placement.row >= 0,
                  placement.column >= 0,
                  placement.row < chart.rows,
                  placement.column < chart.columns,
                  chart.isActiveSeat(row: placement.row, column: placement.column),
                  let student = rosterByUUID[placement.studentUUID],
                  seenStudentUUIDs.insert(placement.studentUUID).inserted,
                  seenCoordinates.insert(coordinateKey).inserted else {
                context.delete(placement)
                deletedPlacementIDs.insert(placement.id)
                continue
            }

            if placement.studentNameSnapshot != student.name {
                placement.studentNameSnapshot = student.name
                chart.updatedAt = Date()
            }
        }

        if !deletedPlacementIDs.isEmpty {
            chart.placements.removeAll { deletedPlacementIDs.contains($0.id) }
            chart.updatedAt = Date()
        }

        if context.hasChanges {
            _ = SaveCoordinator.save(context: context, reason: "Sync seating chart")
        }
    }

    private func updateLayout(rows: Int?, columns: Int?) {
        guard let chart else { return }

        chart.rows = rows ?? chart.rows
        chart.columns = columns ?? chart.columns
        trimPlacementsOutsideBounds()
        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Update seating chart layout")
    }

    private func applyLayoutStyle(_ style: SeatingLayoutStyle) {
        ensureChartExists()
        guard let chart else { return }

        chart.layoutStyle = style
        let recommended = recommendedDimensions(
            for: max(orderedStudents.count, 1),
            style: style,
            centerGroupSize: chart.validatedCenterGroupSize
        )
        if chart.activeSeatCount < orderedStudents.count {
            chart.rows = recommended.rows
            chart.columns = recommended.columns
        }
        trimPlacementsOutsideBounds()
        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Change seating chart layout style")
    }

    private func updateCenterGroupSize(_ groupSize: Int) {
        guard let chart else { return }
        chart.centerGroupSize = min(max(groupSize, 3), 4)
        if chart.layoutStyle == .centers, chart.activeSeatCount < orderedStudents.count {
            let recommended = recommendedDimensions(
                for: max(orderedStudents.count, 1),
                style: .centers,
                centerGroupSize: chart.validatedCenterGroupSize
            )
            chart.rows = recommended.rows
            chart.columns = recommended.columns
        }
        trimPlacementsOutsideBounds()
        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Update seating chart center size")
    }

    private func trimPlacementsOutsideBounds() {
        guard let chart else { return }

        let invalidPlacements = chart.placements.filter {
            $0.row >= chart.rows ||
            $0.column >= chart.columns ||
            !chart.isActiveSeat(row: $0.row, column: $0.column)
        }

        for placement in invalidPlacements {
            context.delete(placement)
        }

        chart.placements.removeAll { placement in
            placement.row >= chart.rows ||
            placement.column >= chart.columns ||
            !chart.isActiveSeat(row: placement.row, column: placement.column)
        }
    }

    private func autoArrangeStudents() {
        ensureChartExists()
        guard let chart else { return }

        let students = orderedStudents
        guard !students.isEmpty else { return }

        if seatCount < students.count {
            let recommended = recommendedDimensions(
                for: students.count,
                style: chart.layoutStyle,
                centerGroupSize: chart.validatedCenterGroupSize
            )
            chart.rows = recommended.rows
            chart.columns = recommended.columns
        }

        for placement in chart.placements {
            context.delete(placement)
        }
        chart.placements.removeAll()

        let targetCoordinates = autoArrangeCoordinates(for: chart)
        for (index, student) in students.enumerated() {
            guard index < targetCoordinates.count else { break }
            let coordinate = targetCoordinates[index]
            let placement = SeatingPlacement(
                row: coordinate.row,
                column: coordinate.column,
                studentUUID: student.uuid,
                studentNameSnapshot: student.name,
                chart: chart
            )
            chart.placements.append(placement)
            context.insert(placement)
        }

        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Auto arrange seating chart")
    }

    private func clearAllSeats() {
        guard let chart else { return }

        for placement in chart.placements {
            context.delete(placement)
        }
        chart.placements.removeAll()
        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Clear seating chart")
    }

    private func clearSeat(at coordinate: SeatCoordinate) {
        guard let currentPlacement = placement(at: coordinate), let chart else { return }

        context.delete(currentPlacement)
        chart.placements.removeAll { $0.id == currentPlacement.id }
        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Clear seating chart seat")
    }

    private func assign(student: Student, to coordinate: SeatCoordinate) {
        ensureChartExists()
        guard let chart else { return }
        guard chart.isActiveSeat(row: coordinate.row, column: coordinate.column) else { return }

        let targetPlacement = placement(at: coordinate)
        let existingPlacement = chart.placements.first { $0.studentUUID == student.uuid }

        if let targetPlacement, targetPlacement.studentUUID == student.uuid {
            return
        }

        if let existingPlacement, let targetPlacement, existingPlacement.id != targetPlacement.id {
            let displacedUUID = targetPlacement.studentUUID
            let displacedName = targetPlacement.studentNameSnapshot

            targetPlacement.studentUUID = student.uuid
            targetPlacement.studentNameSnapshot = student.name
            existingPlacement.studentUUID = displacedUUID
            existingPlacement.studentNameSnapshot = displacedName
        } else if let existingPlacement {
            existingPlacement.row = coordinate.row
            existingPlacement.column = coordinate.column
            existingPlacement.studentNameSnapshot = student.name
        } else if let targetPlacement {
            targetPlacement.studentUUID = student.uuid
            targetPlacement.studentNameSnapshot = student.name
        } else {
            let newPlacement = SeatingPlacement(
                row: coordinate.row,
                column: coordinate.column,
                studentUUID: student.uuid,
                studentNameSnapshot: student.name,
                chart: chart
            )
            chart.placements.append(newPlacement)
            context.insert(newPlacement)
        }

        chart.updatedAt = Date()
        _ = SaveCoordinator.save(context: context, reason: "Assign seating chart seat")
    }

    private func logParticipation(for student: Student, kind: ParticipationEventKind) {
        let event = ParticipationEvent(
            createdAt: Date(),
            kind: kind,
            studentUUID: student.uuid,
            studentNameSnapshot: student.name,
            student: student,
            schoolClass: schoolClass
        )
        schoolClass.participationEvents.append(event)
        student.participationEvents.append(event)
        student.isParticipatingWell = true
        context.insert(event)
        recentParticipationPulseID = student.uuid
        _ = SaveCoordinator.save(context: context, reason: "Log participation event")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if recentParticipationPulseID == student.uuid {
                recentParticipationPulseID = nil
            }
        }
    }

    private func logBehaviorSupport(for student: Student, kind: BehaviorSupportEventKind) {
        let event = BehaviorSupportEvent(
            createdAt: Date(),
            kind: kind,
            studentUUID: student.uuid,
            studentNameSnapshot: student.name,
            student: student,
            schoolClass: schoolClass
        )
        schoolClass.behaviorSupportEvents.append(event)
        student.behaviorSupportEvents.append(event)
        if kind.shouldFlagNeedsHelp {
            student.needsHelp = true
        }
        context.insert(event)
        recentBehaviorPulseID = student.uuid
        _ = SaveCoordinator.save(context: context, reason: "Log behavior support event")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if recentBehaviorPulseID == student.uuid {
                recentBehaviorPulseID = nil
            }
        }
    }

    private func removeParticipationEvent(_ event: ParticipationEvent) {
        schoolClass.participationEvents.removeAll { $0.id == event.id }
        event.student?.participationEvents.removeAll { $0.id == event.id }
        context.delete(event)
        _ = SaveCoordinator.save(context: context, reason: "Delete participation event")
    }

    private func removeBehaviorSupportEvent(_ event: BehaviorSupportEvent) {
        schoolClass.behaviorSupportEvents.removeAll { $0.id == event.id }
        event.student?.behaviorSupportEvents.removeAll { $0.id == event.id }
        context.delete(event)
        _ = SaveCoordinator.save(context: context, reason: "Delete behavior support event")
    }

    private func placement(at coordinate: SeatCoordinate) -> SeatingPlacement? {
        chart?.placements.first {
            $0.row == coordinate.row && $0.column == coordinate.column
        }
    }

    private func latestParticipationEvent(for studentUUID: UUID) -> ParticipationEvent? {
        schoolClass.participationEvents
            .filter { $0.studentUUID == studentUUID }
            .max { $0.createdAt < $1.createdAt }
    }

    private func latestBehaviorSupportEvent(for studentUUID: UUID) -> BehaviorSupportEvent? {
        todaysBehaviorSupportEvents
            .filter { $0.studentUUID == studentUUID }
            .max { $0.createdAt < $1.createdAt }
    }

    private func student(for uuid: UUID) -> Student? {
        orderedStudents.first { $0.uuid == uuid }
    }

    private func seatLabel(for coordinate: SeatCoordinate) -> String {
        switch layoutStyle {
        case .rows:
            return String(
                format: languageManager.localized("Row %d • Seat %d"),
                coordinate.row + 1,
                coordinate.column + 1
            )
        case .duos:
            return String(
                format: languageManager.localized("Duo %d • Seat %d"),
                (coordinate.column / 2) + 1,
                (coordinate.column % 2) + 1
            )
        case .uShape:
            return String(
                format: languageManager.localized("U-Shape • Row %d Seat %d"),
                coordinate.row + 1,
                coordinate.column + 1
            )
        case .centers:
            let centerIndex = activeSeatCoordinates.firstIndex(of: coordinate).map { $0 / centerGroupSize } ?? 0
            let seatIndex = activeSeatCoordinates.firstIndex(of: coordinate).map { ($0 % centerGroupSize) + 1 } ?? 1
            return String(
                format: languageManager.localized("Center %d • Seat %d"),
                centerIndex + 1,
                seatIndex
            )
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters
    }

    private func defaultDimensions(for studentCount: Int) -> (rows: Int, columns: Int) {
        let columns = min(max(4, Int(ceil(sqrt(Double(studentCount))))), 6)
        let rows = max(1, Int(ceil(Double(studentCount) / Double(columns))))
        return (rows, columns)
    }

    private func recommendedDimensions(
        for studentCount: Int,
        style: SeatingLayoutStyle,
        centerGroupSize: Int
    ) -> (rows: Int, columns: Int) {
        switch style {
        case .rows:
            return defaultDimensions(for: studentCount)
        case .duos:
            let base = defaultDimensions(for: studentCount)
            let columns = max(2, base.columns + (base.columns % 2))
            let rows = max(1, Int(ceil(Double(studentCount) / Double(columns))))
            return (rows, columns)
        case .centers:
            let groupSize = min(max(centerGroupSize, 3), 4)
            let groups = max(1, Int(ceil(Double(studentCount) / Double(groupSize))))
            if groupSize == 3 {
                let groupsPerRow = min(max(1, Int(ceil(sqrt(Double(groups))))), 4)
                let columns = groupsPerRow * 3
                let rows = max(1, Int(ceil(Double(studentCount) / Double(columns))))
                return (rows, columns)
            } else {
                let groupsPerRow = min(max(1, Int(ceil(sqrt(Double(groups))))), 3)
                let columns = groupsPerRow * 2
                let rows = max(2, Int(ceil(Double(studentCount) / Double(columns))))
                return (rows, columns)
            }
        case .uShape:
            var best: (rows: Int, columns: Int, area: Int)?
            for rows in 3...10 {
                for columns in 4...12 {
                    let activeSeats = (rows * 2) + (columns * 2) - 4
                    guard activeSeats >= studentCount else { continue }
                    let area = rows * columns
                    if let best, best.area <= area {
                        continue
                    }
                    best = (rows, columns, area)
                }
            }
            return best.map { ($0.rows, $0.columns) } ?? (4, 5)
        }
    }

    private var chartTitle: String {
        switch selectedMode {
        case .layout:
            return String(format: "%@ • %@".localized, "Room Layout".localized, layoutStyleSummary)
        case .participation:
            return "Live Participation Board".localized
        case .behaviorSupport:
            return "Behavior & Support Board".localized
        }
    }

    private var chartStatusText: String {
        switch selectedMode {
        case .layout:
            return "\(seatedCount)/\(seatCount)"
        case .participation:
            return "\(todaysParticipationEvents.count) " + "logged".localized
        case .behaviorSupport:
            return "\(todaysBehaviorSupportEvents.count) " + "logged".localized
        }
    }

    private func icon(for kind: ParticipationEventKind) -> String {
        switch kind {
        case .contribution:
            return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .leadership:
            return "flag.fill"
        case .collaboration:
            return "person.2.fill"
        }
    }

    private func color(for kind: ParticipationEventKind) -> Color {
        switch kind {
        case .contribution:
            return .pink
        case .leadership:
            return .indigo
        case .collaboration:
            return .teal
        }
    }

    private func isSeatRecentlyLogged(for studentUUID: UUID?) -> Bool {
        guard let studentUUID else { return false }
        switch selectedMode {
        case .layout:
            return false
        case .participation:
            return studentUUID == recentParticipationPulseID
        case .behaviorSupport:
            return studentUUID == recentBehaviorPulseID
        }
    }

    private func seatBorderColor(
        isOccupied: Bool,
        isRecentlyLogged: Bool,
        latestBehaviorEvent: BehaviorSupportEvent?
    ) -> Color {
        if isRecentlyLogged {
            switch selectedMode {
            case .layout:
                return Color.indigo.opacity(0.18)
            case .participation:
                return Color.pink.opacity(0.28)
            case .behaviorSupport:
                return (latestBehaviorEvent?.kind.color ?? .orange).opacity(0.3)
            }
        }
        if selectedMode == .behaviorSupport, let latestBehaviorEvent {
            return latestBehaviorEvent.kind.color.opacity(0.22)
        }
        return isOccupied ? Color.indigo.opacity(0.18) : Color.gray.opacity(0.12)
    }

    private func seatTintColor(
        isOccupied: Bool,
        isRecentlyLogged: Bool,
        latestBehaviorEvent: BehaviorSupportEvent?
    ) -> Color? {
        if isRecentlyLogged {
            switch selectedMode {
            case .layout:
                return .indigo
            case .participation:
                return .pink
            case .behaviorSupport:
                return latestBehaviorEvent?.kind.color ?? .orange
            }
        }
        if selectedMode == .behaviorSupport, let latestBehaviorEvent {
            return latestBehaviorEvent.kind.color
        }
        return isOccupied ? .indigo : nil
    }

    private var layoutStyleSummary: String {
        switch layoutStyle {
        case .rows:
            return "Rows".localized
        case .duos:
            return "Duos".localized
        case .uShape:
            return "U-Shape".localized
        case .centers:
            return centerGroupSize == 3 ? "Centers of 3".localized : "Centers of 4".localized
        }
    }

    private var layoutStyleDescription: String {
        switch layoutStyle {
        case .rows:
            return "A traditional row-and-column room layout.".localized
        case .duos:
            return "Keep seats visually grouped in pairs for partner work and quick pair swaps.".localized
        case .uShape:
            return "Reserve the middle of the room and keep seating around the perimeter.".localized
        case .centers:
            return centerGroupSize == 3
                ? "Organize the class into small centers of three students.".localized
                : "Organize the class into small centers of four students.".localized
        }
    }

    private var layoutInteractionText: String {
        switch layoutStyle {
        case .rows:
            return "Tap any seat to assign, move, or clear a student. Moving a seated student onto another occupied seat swaps them.".localized
        case .duos:
            return "Tap seats to build partner pairs. Students can still be moved or swapped seat by seat.".localized
        case .uShape:
            return "Only the outer seats are active in U-shape mode. The middle space stays open for instruction.".localized
        case .centers:
            return centerGroupSize == 3
                ? "Tap seats to organize students into small centers of three.".localized
                : "Tap seats to organize students into small centers of four.".localized
        }
    }

    private func rowSeatCoordinates(for row: Int) -> [SeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.columns).map { SeatCoordinate(row: row, column: $0) }
    }

    private func autoArrangeCoordinates(for chart: SeatingChart) -> [SeatCoordinate] {
        switch chart.layoutStyle {
        case .rows, .duos, .centers:
            return activeSeatCoordinates
        case .uShape:
            guard chart.rows > 1, chart.columns > 1 else {
                return activeSeatCoordinates
            }

            var coordinates: [SeatCoordinate] = []
            coordinates.append(contentsOf: (0..<chart.columns).map { SeatCoordinate(row: 0, column: $0) })
            if chart.rows > 2 {
                coordinates.append(contentsOf: (1..<(chart.rows - 1)).map { SeatCoordinate(row: $0, column: chart.columns - 1) })
            }
            if chart.rows > 1 {
                coordinates.append(contentsOf: (0..<chart.columns).reversed().map { SeatCoordinate(row: chart.rows - 1, column: $0) })
            }
            if chart.columns > 1, chart.rows > 2 {
                coordinates.append(contentsOf: (1..<(chart.rows - 1)).reversed().map { SeatCoordinate(row: $0, column: 0) })
            }
            return coordinates
        }
    }
}

private struct SeatCoordinate: Identifiable, Hashable {
    let row: Int
    let column: Int

    var id: String {
        "\(row)-\(column)"
    }
}

private struct SeatAssignmentSheet: View {
    @Bindable var schoolClass: SchoolClass
    let currentPlacement: SeatingPlacement?
    let onAssign: (Student) -> Void
    let onClear: () -> Void
    let locationTitle: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    private var layoutStyle: SeatingLayoutStyle {
        schoolClass.seatingChart?.layoutStyle ?? .rows
    }

    private var activeSeatCoordinates: [SeatCoordinate] {
        guard let chart = schoolClass.seatingChart else { return [] }
        return (0..<chart.rows).flatMap { row in
            (0..<chart.columns).compactMap { column in
                chart.isActiveSeat(row: row, column: column) ? SeatCoordinate(row: row, column: column) : nil
            }
        }
    }

    private var centerGroupSize: Int {
        schoolClass.seatingChart?.validatedCenterGroupSize ?? 4
    }

    private var orderedStudents: [Student] {
        schoolClass.students.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var placementsByStudentUUID: [UUID: SeatingPlacement] {
        var placements: [UUID: SeatingPlacement] = [:]
        for placement in schoolClass.seatingChart?.placements ?? [] {
            placements[placement.studentUUID] = placement
        }
        return placements
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(locationTitle)
                            .font(.headline)

                        Text(layoutBadgeTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(layoutBadgeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(layoutBadgeColor.opacity(0.10))
                            )
                    }

                    if let currentPlacement {
                        Text(
                            String(
                                format: languageManager.localized("Currently seated: %@ at %@"),
                                currentPlacement.studentNameSnapshot,
                                locationText(for: currentPlacement)
                            )
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    } else {
                        Text("This seat is currently empty.".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if currentPlacement != nil {
                Section {
                    Button(role: .destructive) {
                        onClear()
                        dismiss()
                    } label: {
                        Label("Clear Seat".localized, systemImage: "trash")
                    }
                }
            }

            Section("Students".localized) {
                ForEach(orderedStudents, id: \.id) { student in
                    Button {
                        onAssign(student)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(student.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)

                                if let placement = placementsByStudentUUID[student.uuid] {
                                    HStack(spacing: 6) {
                                        Image(systemName: locationChipIcon)
                                            .font(.caption2)
                                            .foregroundColor(layoutBadgeColor)
                                        Text(locationText(for: placement))
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(layoutBadgeColor)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(layoutBadgeColor.opacity(0.10))
                                    )
                                } else {
                                    Text("Unseated".localized)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if currentPlacement?.studentUUID == student.uuid {
                                statusBadge(title: "Current".localized, color: .indigo)
                            } else if placementsByStudentUUID[student.uuid] != nil {
                                statusBadge(title: "Swap".localized, color: .orange)
                            } else {
                                statusBadge(title: "Assign".localized, color: .green)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Assign Seat".localized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close".localized) {
                    dismiss()
                }
            }
        }
    }

    private func locationText(for placement: SeatingPlacement) -> String {
        switch layoutStyle {
        case .rows:
            return String(
                format: languageManager.localized("Currently at row %d seat %d"),
                placement.row + 1,
                placement.column + 1
            )
        case .duos:
            return String(
                format: languageManager.localized("Currently in duo %d seat %d"),
                (placement.column / 2) + 1,
                (placement.column % 2) + 1
            )
        case .uShape:
            return String(
                format: languageManager.localized("Currently in U-shape row %d seat %d"),
                placement.row + 1,
                placement.column + 1
            )
        case .centers:
            let coordinate = SeatCoordinate(row: placement.row, column: placement.column)
            let index = activeSeatCoordinates.firstIndex(of: coordinate) ?? 0
            return String(
                format: languageManager.localized("Currently in center %d seat %d"),
                (index / centerGroupSize) + 1,
                (index % centerGroupSize) + 1
            )
        }
    }

    private var layoutBadgeTitle: String {
        switch layoutStyle {
        case .rows:
            return "Rows".localized
        case .duos:
            return "Duos".localized
        case .uShape:
            return "U-Shape".localized
        case .centers:
            return centerGroupSize == 3 ? "Centers of 3".localized : "Centers of 4".localized
        }
    }

    private var layoutBadgeColor: Color {
        switch layoutStyle {
        case .rows:
            return .indigo
        case .duos:
            return .teal
        case .uShape:
            return .orange
        case .centers:
            return .purple
        }
    }

    private var locationChipIcon: String {
        switch layoutStyle {
        case .rows:
            return "square.grid.3x3"
        case .duos:
            return "person.2.fill"
        case .uShape:
            return "arrow.uturn.down"
        case .centers:
            return "circle.grid.2x2.fill"
        }
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.10))
            )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return chunks
    }
}
