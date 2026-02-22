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
        ScrollView {
            VStack(spacing: 20) {
                #if os(macOS)
                attendanceActionsRow
                #endif
                
                // Statistics card
                if !sortedSessions.isEmpty {
                    statisticsCard
                }
                
                // Sessions section
                sessionsSection
                
            }
            .padding(.vertical, 20)
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
    
    var statisticsCard: some View {
        VStack(spacing: 16) {
            Text(languageManager.localized("Attendance Overview"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                statBox(
                    title: languageManager.localized("Total Sessions"),
                    value: "\(sortedSessions.count)",
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
                    value: "\(attendanceRate)%",
                    icon: "chart.bar.fill",
                    color: attendanceRateColor
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    var attendanceRate: Int {
        guard !sortedSessions.isEmpty else { return 0 }
        
        let allRecords = sortedSessions.flatMap { $0.records }
        let presentCount = allRecords.filter { $0.status == .present }.count
        
        guard !allRecords.isEmpty else { return 0 }
        return Int((Double(presentCount) / Double(allRecords.count)) * 100)
    }
    
    var attendanceRateColor: Color {
        let rate = attendanceRate
        if rate >= 90 { return .green }
        if rate >= 75 { return .orange }
        return .red
    }
    
    // MARK: - Sessions Section
    
    var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(languageManager.localized("Attendance Sessions"))
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if sortedSessions.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                ], spacing: 16) {
                    ForEach(sortedSessions, id: \.id) { session in
                        NavigationLink {
                            AttendanceSessionView(session: session)
                        } label: {
                            AttendanceSessionCard(session: session, onDelete: {
                                deleteSession(session)
                            })
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
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(languageManager.localized("Create your first session to start tracking attendance"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
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
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
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
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
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
                        .background(Color.blue)
                        .cornerRadius(10)
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
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 650)
        #endif
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
