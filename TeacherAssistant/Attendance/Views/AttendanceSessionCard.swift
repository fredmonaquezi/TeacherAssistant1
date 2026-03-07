import SwiftUI

struct AttendanceSessionStats {
    let presentCount: Int
    let absentCount: Int
    let lateCount: Int
    let leftEarlyCount: Int
    let totalCount: Int

    init(records: [AttendanceRecord]) {
        var present = 0
        var absent = 0
        var late = 0
        var leftEarly = 0

        for record in records {
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

        self.init(
            presentCount: present,
            absentCount: absent,
            lateCount: late,
            leftEarlyCount: leftEarly,
            totalCount: records.count
        )
    }

    init(
        presentCount: Int,
        absentCount: Int,
        lateCount: Int,
        leftEarlyCount: Int,
        totalCount: Int
    ) {
        self.presentCount = presentCount
        self.absentCount = absentCount
        self.lateCount = lateCount
        self.leftEarlyCount = leftEarlyCount
        self.totalCount = totalCount
    }

    var attendanceRate: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(presentCount) / Double(totalCount)) * 100)
    }

    var rateColor: Color {
        let rate = attendanceRate
        if rate >= 90 { return .green }
        if rate >= 75 { return .orange }
        return .red
    }
}

struct AttendanceSessionCard: View {
    let session: AttendanceSession
    let stats: AttendanceSessionStats
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.appDateString)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Delete session"))
            }
            
            Divider()
            
            // Attendance summary
            HStack(spacing: 16) {
                attendanceStat(
                    icon: "checkmark.circle.fill",
                    label: languageManager.localized("Present"),
                    count: stats.presentCount,
                    color: .green
                )
                
                attendanceStat(
                    icon: "xmark.circle.fill",
                    label: languageManager.localized("Absent"),
                    count: stats.absentCount,
                    color: .red
                )
                
                attendanceStat(
                    icon: "clock.fill",
                    label: languageManager.localized("Late"),
                    count: stats.lateCount,
                    color: .orange
                )
                
                attendanceStat(
                    icon: "arrow.left.circle.fill",
                    label: languageManager.localized("Left Early"),
                    count: stats.leftEarlyCount,
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
                    
                    Text("\(stats.attendanceRate)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(stats.rateColor)
                }
                
                ProgressView(value: Double(stats.attendanceRate), total: 100)
                    .progressViewStyle(.linear)
                    .tint(stats.rateColor)
                    .scaleEffect(y: 1.2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            borderColor: stats.rateColor.opacity(0.16),
            tint: stats.rateColor
        )
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppChrome.elevatedBackground)
        )
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
                return session.date.appDateString
            }
        }
    }
    
}
