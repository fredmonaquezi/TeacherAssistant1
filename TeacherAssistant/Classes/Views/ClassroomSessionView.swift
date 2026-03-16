import SwiftUI
import SwiftData

struct ClassroomSessionView: View {
    private static let sessionDiaryPlanFallback = "Classroom Session"

    enum InteractionMode: String, CaseIterable, Identifiable {
        case participation
        case behaviorSupport

        var id: String { rawValue }
    }

    @Bindable var schoolClass: SchoolClass
    @ObservedObject var timerManager: ClassroomTimerManager
    let showsDismissButton: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appMotionContext) private var motion
    @EnvironmentObject private var languageManager: LanguageManager
    @Query private var diaryEntries: [ClassDiaryEntry]

    @State private var selectedMode: InteractionMode = .participation
    @State private var pickedStudentUUID: UUID?
    @State private var notesDraft = ""
    @State private var notesSaveTask: Task<Void, Never>?
    @State private var showingAttendanceSheet = false
    @State private var showingAssignmentsSheet = false
    @State private var showingSeatingChartSheet = false
    @State private var showingLiveCheckInSheet = false

    private let calendar = Calendar.current

    init(
        schoolClass: SchoolClass,
        timerManager: ClassroomTimerManager,
        showsDismissButton: Bool = false
    ) {
        self.schoolClass = schoolClass
        self.timerManager = timerManager
        self.showsDismissButton = showsDismissButton
    }

    private var sessionDiaryPlanCandidates: Set<String> {
        [
            Self.sessionDiaryPlanFallback,
            Self.sessionDiaryPlanFallback.localized
        ]
    }

    private var sessionDiaryPlanLabel: String {
        Self.sessionDiaryPlanFallback.localized
    }

    private var orderedStudents: [Student] {
        schoolClass.students.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var classAssignments: [Assignment] {
        schoolClass.subjects
            .flatMap(\.units)
            .flatMap(\.assignments)
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var chart: SeatingChart? {
        schoolClass.seatingChart
    }

    private var layoutStyle: SeatingLayoutStyle {
        chart?.layoutStyle ?? .rows
    }

    private var seatCoordinates: [SessionSeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.rows).flatMap { row in
            (0..<chart.columns).map { column in
                SessionSeatCoordinate(row: row, column: column)
            }
        }
    }

    private var activeSeatCoordinates: [SessionSeatCoordinate] {
        guard let chart else { return [] }
        return seatCoordinates.filter { chart.isActiveSeat(row: $0.row, column: $0.column) }
    }

    private var centerGroupSize: Int {
        chart?.validatedCenterGroupSize ?? 4
    }

    private var centerGroups: [[SessionSeatCoordinate]] {
        chunkCoordinates(activeSeatCoordinates, size: centerGroupSize)
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var startOfTomorrow: Date {
        calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    private var todaysAttendanceSession: AttendanceSession? {
        schoolClass.attendanceSessions.first {
            calendar.isDate($0.date, inSameDayAs: startOfToday)
        }
    }

    private var attendanceStats: AttendanceSessionStats {
        AttendanceSessionStats(records: todaysAttendanceSession?.records ?? [])
    }

    private var todaysDiaryEntry: ClassDiaryEntry? {
        diaryEntries.first { entry in
            calendar.isDate(entry.date, inSameDayAs: startOfToday)
            && entry.schoolClass?.id == schoolClass.id
            && entry.assignment == nil
            && entry.subject == nil
            && entry.unit == nil
            && sessionDiaryPlanCandidates.contains(entry.plan)
        }
    }

    private var seatedStudentUUIDs: Set<UUID> {
        Set(chart?.placements.map(\.studentUUID) ?? [])
    }

    private var unseatedStudents: [Student] {
        orderedStudents.filter { !seatedStudentUUIDs.contains($0.uuid) }
    }

    private var todaysParticipationEvents: [ParticipationEvent] {
        schoolClass.participationEvents
            .filter { $0.createdAt >= startOfToday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var todaysBehaviorEvents: [BehaviorSupportEvent] {
        schoolClass.behaviorSupportEvents
            .filter { $0.createdAt >= startOfToday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var participationCountsToday: [UUID: Int] {
        Dictionary(grouping: todaysParticipationEvents, by: \.studentUUID).mapValues(\.count)
    }

    private var behaviorCountsToday: [UUID: Int] {
        Dictionary(grouping: todaysBehaviorEvents, by: \.studentUUID).mapValues(\.count)
    }

    private var activeSupportSignals: Int {
        Set(
            todaysBehaviorEvents
                .filter { $0.kind.shouldFlagNeedsHelp }
                .map(\.studentUUID)
        ).count
    }

    private var dueSoonAssignments: Int {
        classAssignments.filter { assignment in
            assignment.dueDate >= startOfToday && assignment.dueDate < startOfTomorrow
        }.count
    }

    private var missingAssignments: Int {
        classAssignments.reduce(0) { partialResult, assignment in
            partialResult + assignment.progressSummary().missingCount
        }
    }

    private var selectedStudent: Student? {
        guard let pickedStudentUUID else { return nil }
        return orderedStudents.first { $0.uuid == pickedStudentUUID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                headerCard
                    .appMotionReveal(index: 0)
                quickActionsCard
                    .appMotionReveal(index: 1)
                timerCard
                    .appMotionReveal(index: 2)
                attendanceCard
                    .appMotionReveal(index: 3)
                liveCaptureCard
                    .appMotionReveal(index: 4)
                sessionNotesCard
                    .appMotionReveal(index: 5)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Classroom Session".localized)
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
        .sheet(isPresented: $showingAttendanceSheet) {
            NavigationStack {
                AttendanceListView(schoolClass: schoolClass, showsDismissButton: true)
                    .appSheetMotion()
            }
        }
        .sheet(isPresented: $showingAssignmentsSheet) {
            NavigationStack {
                ClassAssignmentsView(schoolClass: schoolClass, showsDismissButton: true)
                    .appSheetMotion()
            }
        }
        .sheet(isPresented: $showingSeatingChartSheet) {
            NavigationStack {
                SeatingChartView(schoolClass: schoolClass, showsDismissButton: true)
                    .appSheetMotion()
            }
        }
        .sheet(isPresented: $showingLiveCheckInSheet) {
            NavigationStack {
                LiveCheckInView(
                    schoolClass: schoolClass,
                    source: .classroomSession,
                    showsDismissButton: true
                )
                .appSheetMotion()
            }
        }
        .task {
            loadNotesDraft()
            normalizeTodaysAttendanceIfNeeded()
        }
        .onAppear {
            loadNotesDraft()
            normalizeTodaysAttendanceIfNeeded()
        }
        .onChange(of: notesDraft) { _, newValue in
            scheduleNotesSave(for: newValue)
        }
        .onDisappear {
            notesSaveTask?.cancel()
            flushNotesSave()
        }
        .animation(motion.animation(.standard), value: selectedMode)
        .animation(motion.animation(.standard), value: timerManager.isRunning)
        .animation(motion.animation(.standard), value: todaysParticipationEvents.count)
        .animation(motion.animation(.standard), value: todaysBehaviorEvents.count)
        .animation(motion.animation(.standard), value: todayAttendanceRecords.count)
        .macNavigationDepth()
        #if os(macOS)
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 820, idealHeight: 900)
        #endif
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classroom Session".localized)
                        .font(.title3.weight(.semibold))
                    Text(schoolClass.name)
                        .font(.headline)
                    Text("Run the lesson from one screen: attendance, timer, live logging, and notes.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(Date().appDateString(systemStyle: .full))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                sessionStat(
                    title: "Students".localized,
                    value: "\(orderedStudents.count)",
                    color: .blue
                )
                sessionStat(
                    title: "Attendance".localized,
                    value: todaysAttendanceSession == nil ? "Not Started".localized : "\(attendanceStats.attendanceRate)%",
                    color: todaysAttendanceSession == nil ? .orange : attendanceStats.rateColor
                )
                sessionStat(
                    title: "Participation".localized,
                    value: "\(todaysParticipationEvents.count)",
                    color: todaysParticipationEvents.isEmpty ? .secondary : .pink
                )
                sessionStat(
                    title: "Support Signals".localized,
                    value: "\(activeSupportSignals)",
                    color: activeSupportSignals == 0 ? .secondary : .red
                )
                sessionStat(
                    title: "Due Today".localized,
                    value: "\(dueSoonAssignments)",
                    color: dueSoonAssignments == 0 ? .secondary : .teal
                )
                sessionStat(
                    title: "Missing Work".localized,
                    value: "\(missingAssignments)",
                    color: missingAssignments == 0 ? .secondary : .orange
                )
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

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Links".localized)
                .font(AppTypography.sectionTitle)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                sessionActionButton(
                    title: "Attendance Details".localized,
                    icon: "checklist",
                    color: .blue
                ) {
                    ensureTodayAttendanceSessionExists()
                    showingAttendanceSheet = true
                }

                sessionActionButton(
                    title: "Assignments".localized,
                    icon: "list.clipboard",
                    color: .teal,
                    disabled: classAssignments.isEmpty
                ) {
                    showingAssignmentsSheet = true
                }

                sessionActionButton(
                    title: "Live Check-In".localized,
                    icon: "waveform.path.ecg.rectangle",
                    color: .indigo
                ) {
                    showingLiveCheckInSheet = true
                }

                sessionActionButton(
                    title: "Seating Chart".localized,
                    icon: "chair.fill",
                    color: .indigo
                ) {
                    showingSeatingChartSheet = true
                }

                sessionActionButton(
                    title: "Reset Timer".localized,
                    icon: "stop.fill",
                    color: .red,
                    disabled: !timerManager.isRunning && timerManager.remainingSeconds == 0
                ) {
                    timerManager.reset()
                }
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

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session Timer".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text(timerManager.isRunning ? "Running".localized : "Ready".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(timerManager.isRunning ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((timerManager.isRunning ? Color.green : Color.secondary).opacity(0.12))
                    )
            }

            VStack(spacing: 12) {
                Text(timerManager.remainingSeconds > 0 ? timerManager.formattedTime : "00:00")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.blue)

                ProgressView(value: timerManager.totalSeconds > 0 ? timerManager.progress : 0)
                    .tint(timerManager.progress > 0.25 ? .blue : .orange)

                Text(timerStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                timerPresetButton(title: "5 min".localized, minutes: 5, color: .green)
                timerPresetButton(title: "10 min".localized, minutes: 10, color: .orange)
                timerPresetButton(title: "15 min".localized, minutes: 15, color: .purple)
                timerPresetButton(title: "30 min".localized, minutes: 30, color: .indigo)
            }

            HStack(spacing: 10) {
                Button {
                    if timerManager.isRunning {
                        timerManager.isExpanded.toggle()
                    }
                } label: {
                    Label(
                        timerManager.isExpanded ? "Minimize Overlay".localized : "Expand Overlay".localized,
                        systemImage: timerManager.isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!timerManager.isRunning)

                Button(role: .destructive) {
                    timerManager.reset()
                } label: {
                    Label("Stop".localized, systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!timerManager.isRunning && timerManager.remainingSeconds == 0)
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

    private var attendanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Attendance".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()

                Button(todaysAttendanceSession == nil ? "Start".localized : "Open Full".localized) {
                    ensureTodayAttendanceSessionExists()
                    if todaysAttendanceSession != nil {
                        showingAttendanceSheet = true
                    }
                }
                .buttonStyle(.bordered)
            }

            if todaysAttendanceSession == nil {
                Label(
                    "Start today's attendance session to mark the roster live during class.".localized,
                    systemImage: "calendar.badge.plus"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
                HStack(spacing: 12) {
                    attendanceSummaryBox(
                        title: "Present".localized,
                        value: attendanceStats.presentCount,
                        color: .green
                    )
                    attendanceSummaryBox(
                        title: "Absent".localized,
                        value: attendanceStats.absentCount,
                        color: .red
                    )
                    attendanceSummaryBox(
                        title: "Late".localized,
                        value: attendanceStats.lateCount,
                        color: .orange
                    )
                    attendanceSummaryBox(
                        title: "Left Early".localized,
                        value: attendanceStats.leftEarlyCount,
                        color: .yellow
                    )
                }

                LazyVStack(spacing: 10) {
                    ForEach(todayAttendanceRecords, id: \.id) { record in
                        attendanceRecordRow(record)
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

    private var liveCaptureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Capture".localized)
                        .font(AppTypography.sectionTitle)
                    Text("Tap seats to log moments as the lesson runs. Use the picker to spotlight the next student.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("Mode".localized, selection: $selectedMode) {
                    Text("Participation".localized).tag(InteractionMode.participation)
                    Text("Behavior / Support".localized).tag(InteractionMode.behaviorSupport)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            pickerCard

            if let chart, !chart.placements.isEmpty {
                sessionSeatingSurface(for: chart)
            } else {
                Label(
                    "No seating chart is set up yet. Use the roster below or open the full seating chart to lay out the room.".localized,
                    systemImage: "chair.lounge.fill"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            if chart == nil || chart?.placements.isEmpty == true {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(orderedStudents, id: \.id) { student in
                        rosterCaptureButton(for: student)
                    }
                }
            } else if !unseatedStudents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Unseated Students".localized)
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        ForEach(unseatedStudents, id: \.id) { student in
                            rosterCaptureButton(for: student)
                        }
                    }
                }
            }

            activitySummary
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.indigo.opacity(0.10),
            tint: .indigo
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private func sessionSeatingSurface(for chart: SeatingChart) -> some View {
        switch chart.layoutStyle {
        case .rows:
            sessionRowsSurface(groupAsDuos: false)
        case .duos:
            sessionRowsSurface(groupAsDuos: true)
        case .uShape:
            sessionUShapeSurface
        case .centers:
            sessionCentersSurface
        }
    }

    private func sessionRowsSurface(groupAsDuos: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                    if groupAsDuos {
                        HStack(alignment: .top, spacing: 20) {
                            ForEach(duoGroups(for: row).indices, id: \.self) { groupIndex in
                                HStack(spacing: 10) {
                                    ForEach(duoGroups(for: row)[groupIndex]) { coordinate in
                                        sessionSeatButton(for: coordinate)
                                    }
                                }
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(rowSeatCoordinates(for: row)) { coordinate in
                                sessionSeatButton(for: coordinate)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var sessionUShapeSurface: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<max(chart?.rows ?? 0, 0), id: \.self) { row in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(rowSeatCoordinates(for: row)) { coordinate in
                            if chart?.isActiveSeat(row: coordinate.row, column: coordinate.column) == true {
                                sessionSeatButton(for: coordinate)
                            } else {
                                inactiveSessionSeatPlaceholder
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var sessionCentersSurface: some View {
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
                            LazyVGrid(columns: [GridItem(.fixed(140), spacing: 10), GridItem(.fixed(140), spacing: 10)], spacing: 10) {
                                ForEach(group) { coordinate in
                                    sessionSeatButton(for: coordinate)
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(group) { coordinate in
                                    sessionSeatButton(for: coordinate)
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
            .padding(.bottom, 4)
        }
    }

    private var inactiveSessionSeatPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Space".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Center stays open".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 140, height: 112, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        )
    }

    private var pickerCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Random Picker".localized)
                    .font(.subheadline.weight(.semibold))

                if let selectedStudent {
                    Text(selectedStudent.name)
                        .font(.headline)
                    Text(selectedStudentContext(for: selectedStudent))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Pick a student to spotlight for answers, reads, or check-ins.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                pickRandomStudent()
            } label: {
                Label("Pick".localized, systemImage: "shuffle")
            }
            .buttonStyle(.borderedProminent)

            Button("Clear".localized) {
                pickedStudentUUID = nil
            }
            .buttonStyle(.bordered)
            .disabled(pickedStudentUUID == nil)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.orange.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .orange
        )
    }

    private var activitySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Activity".localized)
                .font(.subheadline.weight(.semibold))

            Group {
                if selectedMode == .participation {
                    LazyVStack(spacing: 8) {
                        ForEach(todaysParticipationEvents.prefix(6), id: \.id) { event in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.studentNameSnapshot)
                                        .font(.subheadline.weight(.medium))
                                    Text(studentLocationSummary(for: event.studentUUID))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(event.kind.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.pink)
                                Text(event.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(todaysBehaviorEvents.prefix(6), id: \.id) { event in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.studentNameSnapshot)
                                        .font(.subheadline.weight(.medium))
                                    Text(studentLocationSummary(for: event.studentUUID))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(event.kind.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(event.kind.color)
                                Text(event.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .id(selectedMode)
            .transition(motion.transition(.inlineChange))
        }
        .padding(.top, 4)
    }

    private var sessionNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Notes".localized)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("Saved to class diary".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $notesDraft)
                .frame(minHeight: 180)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppChrome.elevatedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppChrome.separator, lineWidth: 1)
                )

            Text("Capture what happened, who needed support, or what to revisit next lesson.".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.teal.opacity(0.10),
            tint: .teal
        )
        .padding(.horizontal)
    }

    private var todayAttendanceRecords: [AttendanceRecord] {
        guard let todaysAttendanceSession else { return [] }

        var seen: Set<PersistentIdentifier> = []
        return todaysAttendanceSession.records
            .sorted { lhs, rhs in
                let lhsName = lhs.student?.name ?? ""
                let rhsName = rhs.student?.name ?? ""
                let result = lhsName.localizedStandardCompare(rhsName)
                if result == .orderedSame {
                    return String(describing: lhs.id) < String(describing: rhs.id)
                }
                return result == .orderedAscending
            }
            .filter { seen.insert($0.id).inserted }
    }

    private var timerStatusText: String {
        if timerManager.isRunning {
            return timerManager.isExpanded
                ? "Timer is running on the shared classroom overlay.".localized
                : "Timer is running in minimized mode.".localized
        }

        if timerManager.remainingSeconds > 0 {
            return "Timer is paused and ready to restart.".localized
        }

        return "Choose a quick preset to keep the lesson moving.".localized
    }

    private func sessionStat(title: String, value: String, color: Color) -> some View {
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

    private func sessionActionButton(
        title: String,
        icon: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(disabled ? .secondary : color)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(disabled ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .appCardStyle(
                cornerRadius: 12,
                borderColor: (disabled ? Color.gray : color).opacity(0.14),
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: disabled ? nil : color
            )
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(disabled)
    }

    private func timerPresetButton(title: String, minutes: Int, color: Color) -> some View {
        Button {
            timerManager.start(minutes: minutes)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                )
        }
        .buttonStyle(AppPressableButtonStyle())
    }

    private func attendanceSummaryBox(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }

    @ViewBuilder
    private func attendanceRecordRow(_ record: AttendanceRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.student?.name ?? "Unknown Student".localized)
                    .font(.subheadline.weight(.semibold))
                Text(record.status.rawValue.localized)
                    .font(.caption)
                    .foregroundColor(attendanceColor(for: record.status))
            }

            Spacer()

            ForEach(AttendanceStatus.allCases) { status in
                Button {
                    updateAttendance(record, status: status)
                } label: {
                    Image(systemName: attendanceIcon(for: status))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(record.status == status ? .white : attendanceColor(for: status))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(
                                    record.status == status
                                        ? attendanceColor(for: status)
                                        : attendanceColor(for: status).opacity(0.12)
                                )
                        )
                }
                .buttonStyle(AppPressableButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appCardStyle(
            cornerRadius: 10,
            borderColor: attendanceColor(for: record.status).opacity(0.12),
            shadowOpacity: 0.02,
            shadowRadius: 4,
            shadowY: 1,
            tint: attendanceColor(for: record.status)
        )
    }

    private func sessionSeatButton(for coordinate: SessionSeatCoordinate) -> some View {
        let placement: SeatingPlacement? = placement(at: coordinate)
        let student: Student? = placement.flatMap { currentPlacement in
            self.student(for: currentPlacement.studentUUID)
        }
        let isSelected = placement?.studentUUID == pickedStudentUUID
        let eventCount = placement.map {
            selectedMode == .participation
                ? participationCountsToday[$0.studentUUID] ?? 0
                : behaviorCountsToday[$0.studentUUID] ?? 0
        } ?? 0
        let accent = accentColor(for: student)
        let borderColor: Color = {
            if isSelected {
                return accent
            }
            if student == nil {
                return Color.secondary.opacity(0.12)
            }
            return accent.opacity(0.12)
        }()
        let instructionText = selectedMode == .participation
            ? "Tap to log contribution".localized
            : "Tap to log support".localized

        return Button {
            guard let student else { return }
            logInteraction(for: student)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(sessionSeatLabel(for: coordinate))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if student != nil {
                        Text("\(eventCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(isSelected ? .white : accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? accent : accent.opacity(0.12))
                            )
                    }
                }

                Spacer()

                if let placement {
                    Text(placement.studentNameSnapshot)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(instructionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Empty Seat".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 112, alignment: .leading)
            .padding(12)
            .appCardStyle(
                cornerRadius: 12,
                borderColor: borderColor,
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: student == nil ? nil : accent
            )
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(student == nil)
        .contextMenu {
            seatContextMenu(for: student)
        }
    }

    @ViewBuilder
    private func seatContextMenu(for student: Student?) -> some View {
        if let student {
            if selectedMode == .participation {
                ForEach(ParticipationEventKind.allCases, id: \.rawValue) { kind in
                    Button {
                        logParticipation(for: student, kind: kind)
                    } label: {
                        Label(kind.title, systemImage: participationIcon(for: kind))
                    }
                }
            } else {
                ForEach(BehaviorSupportEventKind.allCases, id: \.rawValue) { kind in
                    Button {
                        logBehaviorSupport(for: student, kind: kind)
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            }

            Button {
                pickedStudentUUID = student.uuid
            } label: {
                Label("Spotlight Student".localized, systemImage: "star.circle")
            }
        }
    }

    private func rosterCaptureButton(for student: Student) -> some View {
        let isSelected = student.uuid == pickedStudentUUID
        let count = selectedMode == .participation
            ? participationCountsToday[student.uuid] ?? 0
            : behaviorCountsToday[student.uuid] ?? 0

        return Button {
            logInteraction(for: student)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(selectedMode == .participation ? "Log contribution".localized : "Log support".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(studentLocationSummary(for: student.uuid))
                            .font(.caption.weight(.medium))
                            .foregroundColor(locationChipColor)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(locationChipColor.opacity(0.10))
                            )
                    }
                }

                Spacer()

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(isSelected ? .white : accentColor(for: student))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isSelected ? accentColor(for: student) : accentColor(for: student).opacity(0.12))
                    )
            }
            .padding(12)
            .appCardStyle(
                cornerRadius: 10,
                borderColor: accentColor(for: student).opacity(0.12),
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: accentColor(for: student)
            )
        }
        .buttonStyle(AppPressableButtonStyle())
        .contextMenu {
            Button {
                pickedStudentUUID = student.uuid
            } label: {
                Label("Spotlight Student".localized, systemImage: "star.circle")
            }
        }
    }

    private func loadNotesDraft() {
        notesDraft = todaysDiaryEntry?.notes ?? ""
    }

    private func normalizeTodaysAttendanceIfNeeded() {
        guard let todaysAttendanceSession else { return }

        let changedRecords = todaysAttendanceSession.normalizeRecordsIfNeeded(
            for: schoolClass.students,
            context: context
        )
        guard changedRecords > 0 else { return }

        _ = SaveCoordinator.saveResult(
            context: context,
            reason: "Normalize classroom session attendance"
        )
    }

    private func scheduleNotesSave(for value: String) {
        notesSaveTask?.cancel()
        notesSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            saveNotes(value)
        }
    }

    private func flushNotesSave() {
        saveNotes(notesDraft)
    }

    private func saveNotes(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingEntry = todaysDiaryEntry {
            guard existingEntry.notes != value else { return }
            existingEntry.notes = value
            _ = SaveCoordinator.save(context: context, reason: "Update classroom session notes")
            return
        }

        guard !trimmedValue.isEmpty else { return }

        let entry = ClassDiaryEntry(
            date: startOfToday,
            plan: sessionDiaryPlanLabel,
            notes: value,
            schoolClass: schoolClass
        )
        context.insert(entry)
        _ = SaveCoordinator.save(context: context, reason: "Create classroom session notes")
    }

    private func ensureTodayAttendanceSessionExists() {
        guard todaysAttendanceSession == nil else { return }

        let session = AttendanceSession(date: startOfToday)
        for student in orderedStudents {
            let record = AttendanceRecord(student: student, status: .present)
            session.records.append(record)
            context.insert(record)
        }
        schoolClass.attendanceSessions.append(session)
        context.insert(session)
        _ = SaveCoordinator.save(context: context, reason: "Create classroom session attendance")
    }

    private func updateAttendance(_ record: AttendanceRecord, status: AttendanceStatus) {
        guard record.status != status else { return }
        record.status = status
        _ = SaveCoordinator.save(context: context, reason: "Update classroom session attendance")
    }

    private func pickRandomStudent() {
        guard !orderedStudents.isEmpty else { return }
        let candidates = orderedStudents.filter { $0.uuid != pickedStudentUUID }
        let source = candidates.isEmpty ? orderedStudents : candidates
        pickedStudentUUID = source.randomElement()?.uuid
    }

    private func placement(at coordinate: SessionSeatCoordinate) -> SeatingPlacement? {
        chart?.placements.first {
            $0.row == coordinate.row && $0.column == coordinate.column
        }
    }

    private func student(for uuid: UUID) -> Student? {
        orderedStudents.first { $0.uuid == uuid }
    }

    private func sessionSeatLabel(for coordinate: SessionSeatCoordinate) -> String {
        switch layoutStyle {
        case .rows:
            return "R\(coordinate.row + 1) • S\(coordinate.column + 1)"
        case .duos:
            return String(
                format: "Duo %d • %d".localized,
                (coordinate.column / 2) + 1,
                (coordinate.column % 2) + 1
            )
        case .uShape:
            return String(
                format: "U • %d-%d".localized,
                coordinate.row + 1,
                coordinate.column + 1
            )
        case .centers:
            let index = activeSeatCoordinates.firstIndex(of: coordinate) ?? 0
            return String(
                format: "C%d • %d".localized,
                (index / centerGroupSize) + 1,
                (index % centerGroupSize) + 1
            )
        }
    }

    private func rowSeatCoordinates(for row: Int) -> [SessionSeatCoordinate] {
        guard let chart else { return [] }
        return (0..<chart.columns).map { SessionSeatCoordinate(row: row, column: $0) }
    }

    private func duoGroups(for row: Int) -> [[SessionSeatCoordinate]] {
        chunkCoordinates(rowSeatCoordinates(for: row), size: 2)
    }

    private func chunkCoordinates(_ coordinates: [SessionSeatCoordinate], size: Int) -> [[SessionSeatCoordinate]] {
        guard size > 0 else { return [coordinates] }

        var groups: [[SessionSeatCoordinate]] = []
        var index = 0
        while index < coordinates.count {
            let end = min(index + size, coordinates.count)
            groups.append(Array(coordinates[index..<end]))
            index = end
        }
        return groups
    }

    private func selectedStudentContext(for student: Student) -> String {
        studentLocationSummary(for: student.uuid)
    }

    private func studentLocationSummary(for studentUUID: UUID) -> String {
        guard let placement = chart?.placements.first(where: { $0.studentUUID == studentUUID }) else {
            return "Not seated".localized
        }
        return classroomLocationText(for: placement)
    }

    private func classroomLocationText(for placement: SeatingPlacement) -> String {
        switch layoutStyle {
        case .rows:
            return String(
                format: languageManager.localized("Row %d • Seat %d"),
                placement.row + 1,
                placement.column + 1
            )
        case .duos:
            return String(
                format: languageManager.localized("Duo %d • Seat %d"),
                (placement.column / 2) + 1,
                (placement.column % 2) + 1
            )
        case .uShape:
            return String(
                format: languageManager.localized("U-Shape • Row %d Seat %d"),
                placement.row + 1,
                placement.column + 1
            )
        case .centers:
            let coordinate = SessionSeatCoordinate(row: placement.row, column: placement.column)
            let index = activeSeatCoordinates.firstIndex(of: coordinate) ?? 0
            return String(
                format: languageManager.localized("Center %d • Seat %d"),
                (index / centerGroupSize) + 1,
                (index % centerGroupSize) + 1
            )
        }
    }

    private var locationChipColor: Color {
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

    private func logInteraction(for student: Student) {
        if selectedMode == .participation {
            logParticipation(for: student, kind: .contribution)
        } else {
            logBehaviorSupport(for: student, kind: .supportCheckIn)
        }
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
        pickedStudentUUID = student.uuid
        _ = SaveCoordinator.save(context: context, reason: "Log classroom session participation")
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
        pickedStudentUUID = student.uuid
        _ = SaveCoordinator.save(context: context, reason: "Log classroom session behavior")
    }

    private func attendanceColor(for status: AttendanceStatus) -> Color {
        switch status {
        case .present:
            return .green
        case .absent:
            return .red
        case .late:
            return .orange
        case .leftEarly:
            return .yellow
        }
    }

    private func attendanceIcon(for status: AttendanceStatus) -> String {
        switch status {
        case .present:
            return "checkmark"
        case .absent:
            return "xmark"
        case .late:
            return "clock"
        case .leftEarly:
            return "arrow.right"
        }
    }

    private func participationIcon(for kind: ParticipationEventKind) -> String {
        switch kind {
        case .contribution:
            return "bubble.left.and.bubble.right.fill"
        case .leadership:
            return "flag.fill"
        case .collaboration:
            return "person.2.fill"
        }
    }

    private func accentColor(for student: Student?) -> Color {
        guard let student else { return .secondary }

        if selectedMode == .participation {
            return participationCountsToday[student.uuid, default: 0] > 0 ? .pink : .indigo
        }

        if let latestEvent = todaysBehaviorEvents.first(where: { $0.studentUUID == student.uuid }) {
            return latestEvent.kind.color
        }
        return student.needsHelp ? .red : .orange
    }
}

private struct SessionSeatCoordinate: Identifiable, Hashable {
    let row: Int
    let column: Int

    var id: String { "\(row)-\(column)" }
}
