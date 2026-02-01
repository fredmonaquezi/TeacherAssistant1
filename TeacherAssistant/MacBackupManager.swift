#if os(macOS)
import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum MacBackupManager {

    /// Export backup with save dialog
    @MainActor
    static func backup(context: ModelContext) {
        do {
            // Create the backup data
            let tempURL = try BackupManager.exportBackup(context: context)
            
            // Show save panel to let user choose where to save
            let savePanel = NSSavePanel()
            savePanel.title = "Save Backup".localized
            savePanel.message = "Choose where to save your backup file".localized
            savePanel.nameFieldStringValue = "TeacherAssistant-\(dateString()).backup"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.allowedContentTypes = [.data]
            
            // Use runModal() instead of begin() for sandboxed apps
            let response = savePanel.runModal()
            
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Start accessing security-scoped resource
                    let didStartAccessing = destinationURL.startAccessingSecurityScopedResource()
                    defer {
                        if didStartAccessing {
                            destinationURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // If file exists, remove it
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Copy the backup to chosen location
                    try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                    
                    // Record backup was made
                    UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
                    
                    SecureLogger.operationComplete("Backup saved")
                    
                    // Beautiful success alert with icon
                    let alert = NSAlert()
                    alert.messageText = "✅ " + "Backup Saved Successfully!".localized
                    alert.informativeText = "Your data has been safely backed up.".localized + "\n\n" + "Location:".localized + " \(destinationURL.path)"
                    alert.alertStyle = .informational
                    alert.icon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
                    alert.addButton(withTitle: "Done".localized)
                    alert.addButton(withTitle: "Show in Finder".localized)
                    
                    let alertResponse = alert.runModal()
                    if alertResponse == .alertSecondButtonReturn {
                        NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: "")
                    }
                } catch {
                    SecureLogger.operationFailed("Backup save", error: error)
                    showError(title: "Backup Failed".localized, message: error.localizedDescription)
                }
            }
        } catch {
            SecureLogger.operationFailed("Backup creation", error: error)
            showError(title: "Backup Failed".localized, message: error.localizedDescription)
        }
    }

    /// Import backup with open dialog
    @MainActor
    static func restore(context: ModelContext) {
        // Show open panel to let user choose backup file
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Backup File".localized
        openPanel.message = "Choose a backup file to restore".localized
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.data]
        
        // Use runModal() instead of begin() for sandboxed apps
        let response = openPanel.runModal()
        
        if response == .OK, let url = openPanel.url {
            // Start accessing security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Verify we got access
            guard didStartAccessing else {
                showError(title: "Access Denied".localized, message: "Could not access the selected file.".localized)
                return
            }
            
            // Confirm before restoring (this will delete existing data!)
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Restore Backup?".localized
            confirmAlert.informativeText = "⚠️ " + "This will replace ALL current data with the backup. This cannot be undone!".localized
            confirmAlert.alertStyle = .warning
            confirmAlert.addButton(withTitle: "Cancel".localized)
            confirmAlert.addButton(withTitle: "Restore".localized)
            
            let confirmResponse = confirmAlert.runModal()
            
            if confirmResponse == .alertSecondButtonReturn {
                do {
                    try BackupManager.importBackup(from: url, context: context)
                    
                    SecureLogger.operationComplete("Restore")
                    
                    // Beautiful success alert
                    let alert = NSAlert()
                    alert.messageText = "✅ " + "Restore Completed Successfully!".localized
                    alert.informativeText = "Your data has been restored from the backup.".localized + "\n\n" + "All classes, students, grades, and attendance records have been updated.".localized
                    alert.alertStyle = .informational
                    alert.icon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
                    alert.runModal()
                } catch {
                    SecureLogger.operationFailed("Restore", error: error)
                    showError(title: "Restore Failed".localized, message: error.localizedDescription)
                }
            }
        }
    }
    
    /// Helper to show error alerts
    @MainActor
    private static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    /// Helper to generate date string for filename
    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }
}
#endif
