import Foundation
import Foundation
import SwiftUI
import SwiftData
import Combine

/// Manages backup reminders and tracks when backups were last made
class BackupReminderManager: ObservableObject {
    
    @Published var shouldShowReminder = false
    @Published var daysSinceLastBackup: Int = 0
    
    private let lastBackupDateKey = "lastBackupDate"
    private let reminderIntervalDays = 7 // Remind every 7 days
    
    // UserDefaults for storing last backup date
    private let defaults = UserDefaults.standard
    
    init() {
        checkIfReminderNeeded()
    }
    
    /// Check if a backup reminder should be shown
    func checkIfReminderNeeded() {
        guard let lastBackupDate = defaults.object(forKey: lastBackupDateKey) as? Date else {
            // Never backed up before
            daysSinceLastBackup = -1
            shouldShowReminder = true
            return
        }
        
        let daysSince = Calendar.current.dateComponents([.day], from: lastBackupDate, to: Date()).day ?? 0
        daysSinceLastBackup = daysSince
        
        if daysSince >= reminderIntervalDays {
            shouldShowReminder = true
        }
    }
    
    /// Record that a backup was just made
    func recordBackupMade() {
        defaults.set(Date(), forKey: lastBackupDateKey)
        shouldShowReminder = false
        daysSinceLastBackup = 0
    }
    
    /// Dismiss the reminder (user chose "Later")
    func dismissReminder() {
        shouldShowReminder = false
    }
    
    /// Get a friendly message about backup status
    var reminderMessage: String {
        if daysSinceLastBackup < 0 {
            return "You haven't created a backup yet. It's a good idea to back up your data regularly to prevent loss.".localized
        } else if daysSinceLastBackup == 0 {
            return "Great! Your data is backed up.".localized
        } else if daysSinceLastBackup == 1 {
            return "It's been 1 day since your last backup.".localized
        } else {
            return String(format: "It's been %d days since your last backup. Consider creating a new backup to keep your data safe.".localized, daysSinceLastBackup)
        }
    }
}

// MARK: - Backup Reminder View

struct BackupReminderView: View {
    @ObservedObject var reminderManager: BackupReminderManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "externaldrive.fill.badge.timemachine")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text("Backup Reminder".localized)
                .font(.title)
                .fontWeight(.bold)
            
            // Message
            Text(reminderManager.reminderMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Info box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Why backup?".localized)
                        .fontWeight(.semibold)
                }
                
                Text("Regular backups protect your classes, students, grades, and attendance records from accidental loss.".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 16) {
                Button {
                    reminderManager.dismissReminder()
                    dismiss()
                } label: {
                    Text("Remind Me Later".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button {
                    #if os(macOS)
                    dismiss()
                    // Small delay to let sheet dismiss first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        MacBackupManager.backup(context: context)
                        reminderManager.recordBackupMade()
                    }
                    #endif
                } label: {
                    Text("Backup Now".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500)
    }
}
// MARK: - Backup Reminder Banner (for Dashboard)

struct BackupReminderBanner: View {
    @ObservedObject var reminderManager: BackupReminderManager
    @Environment(\.modelContext) private var context
    
    var body: some View {
        if reminderManager.daysSinceLastBackup >= 7 || reminderManager.daysSinceLastBackup < 0 {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "externaldrive.fill.badge.timemachine")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backup Reminder".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(reminderManager.reminderMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        reminderManager.dismissReminder()
                    } label: {
                        Text("Later".localized)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        #if os(macOS)
                        Task { @MainActor in
                            MacBackupManager.backup(context: context)
                            reminderManager.recordBackupMade()
                        }
                        #endif
                    } label: {
                        Text("Backup Now".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

