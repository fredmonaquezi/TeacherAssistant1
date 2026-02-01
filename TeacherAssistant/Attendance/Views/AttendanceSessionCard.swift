import SwiftUI

struct AttendanceSessionCard: View {
    let session: AttendanceSession
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete button
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete session")
            }
            
            Divider()
            
            // Attendance summary
            HStack(spacing: 16) {
                attendanceStat(
                    icon: "checkmark.circle.fill",
                    label: languageManager.localized("Present"),
                    count: presentCount,
                    color: .green
                )
                
                attendanceStat(
                    icon: "xmark.circle.fill",
                    label: languageManager.localized("Absent"),
                    count: absentCount,
                    color: .red
                )
                
                attendanceStat(
                    icon: "clock.fill",
                    label: languageManager.localized("Late"),
                    count: lateCount,
                    color: .orange
                )
                
                attendanceStat(
                    icon: "arrow.left.circle.fill",
                    label: languageManager.localized("Left Early"),
                    count: leftEarlyCount,
                    color: .yellow
                )
            }
            
            // Attendance rate bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(languageManager.localized("Attendance Rate"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(attendanceRate)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(rateColor)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(rateColor)
                            .frame(width: geometry.size.width * (Double(attendanceRate) / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert(languageManager.localized("Delete Session?"), isPresented: $showingDeleteAlert) {
            Button(languageManager.localized("Cancel"), role: .cancel) {}
            Button(languageManager.localized("Delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(languageManager.localized("Are you sure you want to delete this attendance session? This cannot be undone."))
        }
    }
    
    // MARK: - Stats
    
    func attendanceStat(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    var presentCount: Int {
        session.records.filter { $0.status == .present }.count
    }
    
    var absentCount: Int {
        session.records.filter { $0.status == .absent }.count
    }
    
    var lateCount: Int {
        session.records.filter { $0.status == .late }.count
    }
    
    var leftEarlyCount: Int {
        session.records.filter { $0.status == .leftEarly }.count
    }
    
    var attendanceRate: Int {
        let total = session.records.count
        guard total > 0 else { return 0 }
        return Int((Double(presentCount) / Double(total)) * 100)
    }
    
    var rateColor: Color {
        let rate = attendanceRate
        if rate >= 90 { return .green }
        if rate >= 75 { return .orange }
        return .red
    }
    
    var relativeDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(session.date) {
            return languageManager.localized("Today")
        } else if calendar.isDateInYesterday(session.date) {
            return languageManager.localized("Yesterday")
        } else {
            let days = calendar.dateComponents([.day], from: session.date, to: Date()).day ?? 0
            if days > 0 && days <= 7 {
                return String(format: languageManager.localized("%d days ago"), days)
            } else {
                return session.date.formatted(.dateTime.weekday(.wide))
            }
        }
    }
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
