import SwiftUI
import SwiftData

struct AttendanceSessionView: View {
    @Bindable var session: AttendanceSession

    private var sortedRecordIDs: [PersistentIdentifier] {
        session.records
            .sorted { lhs, rhs in
                let lhsName = normalizedStudentName(for: lhs)
                let rhsName = normalizedStudentName(for: rhs)
                let nameOrder = lhsName.localizedStandardCompare(rhsName)
                if nameOrder == .orderedSame {
                    return String(describing: lhs.id) < String(describing: rhs.id)
                }
                return nameOrder == .orderedAscending
            }
            .map(\.id)
    }
    
    var body: some View {
        let stats = AttendanceSessionStats(records: session.records)

        ScrollView {
            VStack(spacing: 20) {
                
                // Header card with summary
                summaryCard(stats: stats)
                
                // Students section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mark Attendance".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(sortedRecordIDs, id: \.self) { recordID in
                            if let recordBinding = bindingForRecord(withID: recordID) {
                                StudentAttendanceCard(record: recordBinding)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle(session.date.appDateString)
        #endif
        .macNavigationDepth()
    }

    private func normalizedStudentName(for record: AttendanceRecord) -> String {
        let trimmedName = record.student?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedName.isEmpty {
            return "zzz_unknown_student"
        }
        return trimmedName
    }

    private func bindingForRecord(withID recordID: PersistentIdentifier) -> Binding<AttendanceRecord>? {
        guard let index = session.records.firstIndex(where: { $0.id == recordID }) else {
            return nil
        }
        return $session.records[index]
    }
    
    // MARK: - Summary Card
    
    func summaryCard(stats: AttendanceSessionStats) -> some View {
        VStack(spacing: 16) {
            // Icon and title
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.appDateString)
                        .font(.headline)
                    Text("\(session.records.count) " + "students".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Statistics
            HStack(spacing: 12) {
                summaryBox(
                    title: "Present".localized,
                    count: stats.presentCount,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                summaryBox(
                    title: "Absent".localized,
                    count: stats.absentCount,
                    icon: "xmark.circle.fill",
                    color: .red
                )
                
                summaryBox(
                    title: "Late".localized,
                    count: stats.lateCount,
                    icon: "clock.fill",
                    color: .orange
                )
                
                summaryBox(
                    title: "Left Early".localized,
                    count: stats.leftEarlyCount,
                    icon: "arrow.right.circle.fill",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func summaryBox(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Student Attendance Card

struct StudentAttendanceCard: View {
    @Binding var record: AttendanceRecord
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 16) {
                // Student avatar and name
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.fill")
                            .foregroundColor(statusColor)
                    }
                    
                    Text(record.student?.name ?? "Unknown Student".localized)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                // Status buttons
                HStack(spacing: 8) {
                    statusButton(.present)
                    statusButton(.late)
                    statusButton(.leftEarly)
                    statusButton(.absent)
                }
            }
            .padding()
            .background(cardBackground)
            
            // Notes section (expanded)
            if record.status != .present {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        TextField("Add notes (optional)".localized, text: $record.notes)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(statusColor.opacity(0.05))
                }
            }
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.3), lineWidth: 1.5)
        )
        #if os(macOS)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        #endif
    }
    
    @ViewBuilder
    func statusButton(_ status: AttendanceStatus) -> some View {
        let isSelected = record.status == status
        
        Button(action: {
            record.status = status
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? getStatusColor(status) : Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: getStatusIcon(status))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(getStatusLabel(status))
    }
    
    var statusColor: Color {
        getStatusColor(record.status)
    }
    
    func getStatusColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .present: return .green
        case .late: return .orange
        case .leftEarly: return .yellow
        case .absent: return .red
        }
    }
    
    func getStatusIcon(_ status: AttendanceStatus) -> String {
        switch status {
        case .present: return "checkmark"
        case .late: return "clock"
        case .leftEarly: return "arrow.right"
        case .absent: return "xmark"
        }
    }
    
    func getStatusLabel(_ status: AttendanceStatus) -> String {
        switch status {
        case .present: return "Present".localized
        case .late: return "Arrived Late".localized
        case .leftEarly: return "Left Early".localized
        case .absent: return "Absent".localized
        }
    }
    var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
