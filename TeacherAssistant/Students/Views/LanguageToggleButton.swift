import SwiftUI

/// A segmented control showing both languages with the active one highlighted
struct LanguageToggleButton: View {
    @ObservedObject var languageManager: LanguageManager
    
    var body: some View {
        HStack(spacing: 2) {
            // English Button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    languageManager.currentLanguage = .english
                }
            } label: {
                HStack(spacing: 3) {
                    Text("🇺🇸")
                        .font(.caption)
                    Text("EN")
                        .font(.caption2)
                        .fontWeight(languageManager.currentLanguage == .english ? .bold : .regular)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(languageManager.currentLanguage == .english ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(languageManager.currentLanguage == .english ? .white : .primary)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            // Portuguese Button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    languageManager.currentLanguage = .portuguese
                }
            } label: {
                HStack(spacing: 3) {
                    Text("🇧🇷")
                        .font(.caption)
                    Text("PT")
                        .font(.caption2)
                        .fontWeight(languageManager.currentLanguage == .portuguese ? .bold : .regular)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(languageManager.currentLanguage == .portuguese ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(languageManager.currentLanguage == .portuguese ? .white : .primary)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .help("Switch Language / Trocar Idioma")
    }
}

/// A menu-style language picker (alternative style)
struct LanguagePickerMenu: View {
    @ObservedObject var languageManager: LanguageManager
    
    var body: some View {
        Menu {
            ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                Button {
                    withAnimation {
                        languageManager.currentLanguage = language
                    }
                } label: {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        
                        if languageManager.currentLanguage == language {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(languageManager.currentLanguage.flag)
                    .font(.title3)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(20)
        }
        .menuStyle(.borderlessButton)
    }
}
