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
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.red)
                        .padding(7)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Delete Subject?".localized)
            }
            
            Divider()
            
            Label("\(subject.units.count) \(subject.units.count == 1 ? "unit".localized : "units".localized)", systemImage: "folder.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppChrome.elevatedBackground)
                )
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            borderColor: Color.blue.opacity(0.14),
            tint: .blue
        )
    }
}
