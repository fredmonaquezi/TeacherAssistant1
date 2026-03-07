import SwiftUI
import SwiftData

struct AttendanceListView: View {
    
    @EnvironmentObject var languageManager: LanguageManager
    @Bindable var schoolClass: SchoolClass
    
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    
    var sortedSessions: [AttendanceSession] {
        schoolClass.attendanceSessions.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            content
            #else
            NavigationStack {
                content
            }
            #endif
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .macNavigationDepth()
    }

    var content: some View {
        let sessions = sortedSessions
        let overallStats = aggregateStats(for: sessions)

        return ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                #if os(macOS)
                attendanceActionsRow
                #endif
                
                // Statistics card
                if !sessions.isEmpty {
                    statisticsCard(
                        totalSessions: sessions.count,
                        overallStats: overallStats
                    )
                }
                
                // Sessions section
                sessionsSection(sessions: sessions)
                
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 2)
        }
        #if !os(macOS)
        .navigationTitle(languageManager.localized("Attendance"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        selectedDate = Date()
                        showingDatePicker = true
                    } label: {
                        Label(languageManager.localized("By Date"), systemImage: "calendar")
                    }
                    
                    Button {
                        createTodaySession()
                    } label: {
                        Label(languageManager.localized("Today"), systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        #endif
    }

    #if os(macOS)
    var attendanceActionsRow: some View {
        HStack(spacing: 12) {
            Button {
                selectedDate = Date()
                showingDatePicker = true
            } label: {
                Label(languageManager.localized("By Date"), systemImage: "calendar")
            }

            Button {
                createTodaySession()
            } label: {
                Label(languageManager.localized("Today"), systemImage: "plus.circle.fill")
            }

            Spacer()
        }
        .padding(.horizontal)
    }
    #endif
    
    // MARK: - Statistics Card
    
    func statisticsCard(totalSessions: Int, overallStats: AttendanceSessionStats) -> some View {
        VStack(spacing: 16) {
            Text(languageManager.localized("Attendance Overview"))
                .font(AppTypography.cardTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                statBox(
                    title: languageManager.localized("Total Sessions"),
                    value: "\(totalSessions)",
                    icon: "calendar.badge.clock",
                    color: .blue
                )
                
                statBox(
                    title: languageManager.localized("Students"),
                    value: "\(schoolClass.students.count)",
                    icon: "person.3.fill",
                    color: .purple
                )
                
                statBox(
                    title: languageManager.localized("Attendance Rate"),
                    value: "\(overallStats.attendanceRate)%",
                    icon: "chart.bar.fill",
                    color: overallStats.rateColor
                )
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
    
    func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(AppTypography.statValue)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .appCardStyle(
            cornerRadius: 10,
            borderColor: color.opacity(0.15),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: color
        )
    }
    
    // MARK: - Sessions Section
    
    func sessionsSection(sessions: [AttendanceSession]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(languageManager.localized("Attendance Sessions"))
                .font(AppTypography.sectionTitle)
                .padding(.horizontal)
            
            if sessions.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                ], spacing: 16) {
                    ForEach(sessions, id: \.id) { session in
                        NavigationLink {
                            AttendanceSessionView(session: session)
                        } label: {
                            AttendanceSessionCard(
                                session: session,
                                stats: AttendanceSessionStats(records: session.records),
                                onDelete: {
                                deleteSession(session)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(languageManager.localized("No attendance sessions yet"))
                .font(AppTypography.cardTitle)
                .foregroundColor(.secondary)
            
            Text(languageManager.localized("Create your first session to start tracking attendance"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.blue.opacity(0.08),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .blue
        )
    }
    
    
    // MARK: - Date Picker Sheet

    var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header info
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text(languageManager.localized("Add Attendance Session"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(languageManager.localized("Choose a date to record attendance"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Calendar
                DatePicker(
                    languageManager.localized("Select date"),
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(20)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: Color.blue.opacity(0.10),
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2,
                    tint: .blue
                )
                .padding(.horizontal)
                #if os(macOS)
                .scaleEffect(1.3)
                #endif
                
                // Selected date display
                VStack(spacing: 8) {
                    Text(languageManager.localized("Selected Date"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(selectedDate.appDateString)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .appCardStyle(
                            cornerRadius: 8,
                            borderColor: Color.blue.opacity(0.14),
                            shadowOpacity: 0.02,
                            shadowRadius: 4,
                            shadowY: 1,
                            tint: .blue
                        )
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        createSession(for: selectedDate)
                        showingDatePicker = false
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(languageManager.localized("Create Session"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingDatePicker = false
                    } label: {
                        Text(languageManager.localized("Cancel"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .appCardStyle(
                                cornerRadius: 10,
                                borderColor: AppChrome.separator,
                                shadowOpacity: 0.02,
                                shadowRadius: 4,
                                shadowY: 1
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .appSheetBackground(tint: .blue)
            .navigationTitle("")
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 650)
        #endif
    }

    func aggregateStats(for sessions: [AttendanceSession]) -> AttendanceSessionStats {
        var present = 0
        var absent = 0
        var late = 0
        var leftEarly = 0
        var total = 0

        for session in sessions {
            for record in session.records {
                total += 1
                switch record.status {
                case .present:
                    present += 1
                case .absent:
                    absent += 1
                case .late:
                    late += 1
                case .leftEarly:
                    leftEarly += 1
                }
            }
        }

        return AttendanceSessionStats(
            presentCount: present,
            absentCount: absent,
            lateCount: late,
            leftEarlyCount: leftEarly,
            totalCount: total
        )
    }
    
    // MARK: - Logic
    
    func createTodaySession() {
        createSession(for: Date())
    }
    
    func createSession(for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        
        // Avoid duplicates for same day
        if schoolClass.attendanceSessions.contains(where: {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }) {
            return
        }
        
        let session = AttendanceSession(date: day)
        
        for student in schoolClass.students.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            session.records.append(AttendanceRecord(student: student, status: .present))
        }
        
        schoolClass.attendanceSessions.append(session)
    }
    
    func deleteSession(_ session: AttendanceSession) {
        schoolClass.attendanceSessions.removeAll { $0.id == session.id }
    }
}
