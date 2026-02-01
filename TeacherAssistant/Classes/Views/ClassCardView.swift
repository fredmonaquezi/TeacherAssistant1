import SwiftUI

struct ClassCardView: View {
    let schoolClass: SchoolClass
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schoolClass.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(schoolClass.grade)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete Class?".localized)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 24) {
                Label("\(schoolClass.students.count) \(schoolClass.students.count == 1 ? "Student".localized : "Students".localized)", systemImage: "person.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Label("\(schoolClass.subjects.count) \(schoolClass.subjects.count == 1 ? "Subject".localized : "Subjects".localized)", systemImage: "book.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        .padding(PlatformSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(PlatformSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: PlatformSpacing.cardCornerRadius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Platform-specific colors
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
