import SwiftUI

struct StudentCardView: View {
    let student: Student
    var onDelete: (() -> Void)? = nil
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Student name with delete button
            HStack {
                Text(student.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Student?".localized)
                }
            }
            
            Divider()
            
            // Status badges
            VStack(alignment: .leading, spacing: 8) {
                if student.isParticipatingWell {
                    statusBadge(icon: "⭐", text: "Participating Well".localized, color: .green)
                }
                
                if student.needsHelp {
                    statusBadge(icon: "⚠️", text: "Needs Help".localized, color: .orange)
                }
                
                if student.missingHomework {
                    statusBadge(icon: "📚", text: "Missing Homework".localized, color: .red)
                }
                
                if !student.isParticipatingWell && !student.needsHelp && !student.missingHomework {
                    Text("No status flags".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Notes preview (if any)
            if !student.notes.isEmpty {
                Divider()
                
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(student.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    func statusBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.subheadline)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(6)
    }
    
    // MARK: - Styling
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    var borderColor: Color {
        if student.needsHelp {
            return .orange.opacity(0.5)
        } else if student.missingHomework {
            return .red.opacity(0.5)
        } else if student.isParticipatingWell {
            return .green.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    var borderWidth: CGFloat {
        if student.needsHelp || student.missingHomework {
            return 2
        } else {
            return 1
        }
    }
}
