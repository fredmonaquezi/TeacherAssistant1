import SwiftUI

struct SubjectCardView: View {
    let subject: Subject
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(subject.name)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete Subject?".localized)
            }
            
            Divider()
            
            Label("\(subject.units.count) \(subject.units.count == 1 ? "unit".localized : "units".localized)", systemImage: "folder.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
