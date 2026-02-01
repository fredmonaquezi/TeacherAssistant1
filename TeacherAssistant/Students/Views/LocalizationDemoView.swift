import SwiftUI

/// Demo view showing localization in action
struct LocalizationDemoView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Localization Demo".localized)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Current Language: \(languageManager.currentLanguage.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Language Toggle
                VStack(spacing: 12) {
                    Text("Switch Language")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        LanguageToggleButton(languageManager: languageManager)
                        LanguagePickerMenu(languageManager: languageManager)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Example Translations
                VStack(alignment: .leading, spacing: 16) {
                    Text("Example Translations")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Group {
                        demoRow("Dashboard")
                        demoRow("Classes")
                        demoRow("Library")
                        demoRow("Student Name")
                        demoRow("Edit Info")
                        demoRow("Quick Status")
                        demoRow("Participating Well")
                        demoRow("Needs Help")
                        demoRow("Missing Homework")
                        demoRow("Overall Average")
                        demoRow("Attendance Summary")
                        demoRow("Performance by Subject")
                        demoRow("Development Tracking")
                        demoRow("Running Records")
                    }
                }
                
                // Status Examples
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status Examples")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        statusCard("Present", color: .green)
                        statusCard("Absent", color: .red)
                        statusCard("Late", color: .orange)
                        statusCard("Outstanding", color: .purple)
                        statusCard("Needs Improvement", color: .orange)
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Buttons")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        actionButton("Done", color: .blue)
                        actionButton("Cancel", color: .red)
                        actionButton("Save", color: .green)
                        actionButton("Edit", color: .orange)
                    }
                }
                .padding(.horizontal)
                
            }
            .padding(.vertical)
        }
        .navigationTitle("Localization Test")
    }
    
    func demoRow(_ key: String) -> some View {
        HStack {
            Text(key)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 180, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(key.localized)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    func statusCard(_ key: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(key.localized)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    func actionButton(_ key: String, color: Color) -> some View {
        Button {
            // Demo only
        } label: {
            Text(key.localized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LocalizationDemoView()
            .environmentObject(LanguageManager())
    }
}
