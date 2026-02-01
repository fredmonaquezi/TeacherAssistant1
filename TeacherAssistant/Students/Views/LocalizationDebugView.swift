import SwiftUI

/// Temporary debug view to diagnose localization issues
struct LocalizationDebugView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🔍 Localization Debug Info")
                .font(.title)
                .bold()
            
            Divider()
            
            // Current language
            HStack {
                Text("Current Language:")
                    .bold()
                Text(languageManager.currentLanguage.rawValue)
                    .foregroundColor(.blue)
            }
            
            // Test if .lproj bundles are found
            Group {
                Text("Bundle Check:")
                    .bold()
                
                if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("English bundle found at: \(enPath)")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("⚠️ English bundle NOT FOUND")
                    }
                }
                
                if let ptPath = Bundle.main.path(forResource: "pt", ofType: "lproj") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Portuguese bundle found at: \(ptPath)")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("⚠️ Portuguese bundle NOT FOUND")
                    }
                }
            }
            
            Divider()
            
            // Test translations
            Text("Test Translations:")
                .bold()
            
            Group {
                testTranslation(key: "Dashboard")
                testTranslation(key: "Classes")
                testTranslation(key: "Student Name")
                testTranslation(key: "Add New Unit")
            }
            
            Spacer()
            
            // Toggle button
            Button("Toggle Language") {
                languageManager.toggleLanguage()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    @ViewBuilder
    func testTranslation(key: String) -> some View {
        HStack(alignment: .top) {
            Text("'\(key)':")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text(languageManager.localized(key))
                    .font(.body)
                    .foregroundColor(
                        languageManager.localized(key) == key ? .red : .green
                    )
                
                if languageManager.localized(key) == key {
                    Text("⚠️ Translation missing!")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    LocalizationDebugView()
        .environmentObject(LanguageManager())
}
