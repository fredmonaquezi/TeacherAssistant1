import SwiftUI

struct ClassPickerCard: View {
    let schoolClass: SchoolClass
    let toolColor: Color
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Class info
            VStack(alignment: .leading, spacing: 6) {
                Text(schoolClass.name)
                    .font(.title3)
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
            
            Divider()
            
            // Stats
            HStack(spacing: 20) {
                statItem(icon: "person.2.fill", value: schoolClass.students.count, label: schoolClass.students.count == 1 ? "student".localized : "students".localized)
                statItem(icon: "book.fill", value: schoolClass.subjects.count, label: schoolClass.subjects.count == 1 ? "subject".localized : "subjects".localized)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            borderColor: toolColor.opacity(0.24),
            lineWidth: 1.5,
            tint: toolColor
        )
    }
    
    func statItem(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppChrome.elevatedBackground)
        )
    }
}
