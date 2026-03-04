import SwiftUI

struct ClassCardView: View {
    let schoolClass: SchoolClass
    let onDelete: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schoolClass.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(schoolClass.grade)
                        .font(.body)
                        .foregroundColor(.secondary)

                    if let schoolYear = schoolClass.schoolYear, !schoolYear.isEmpty {
                        Text(schoolYear)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onDelete) {
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
                .help("Delete Class?".localized)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 24) {
                statBadge(
                    icon: "person.2.fill",
                    text: "\(schoolClass.students.count) \(schoolClass.students.count == 1 ? "Student".localized : "Students".localized)"
                )

                statBadge(
                    icon: "book.fill",
                    text: "\(schoolClass.subjects.count) \(schoolClass.subjects.count == 1 ? "Subject".localized : "Subjects".localized)"
                )
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        .padding(PlatformSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            cornerRadius: PlatformSpacing.cardCornerRadius + 2,
            borderColor: Color.blue.opacity(0.14),
            tint: .blue
        )
    }

    func statBadge(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppChrome.elevatedBackground)
            )
    }
}
