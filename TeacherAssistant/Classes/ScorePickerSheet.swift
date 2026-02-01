import SwiftUI
import SwiftData

struct ScorePickerSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var studentResult: StudentResult
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Header
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set Score".localized)
                        .font(.largeTitle)
                        .bold()
                    
                    if let student = studentResult.student {
                        Text(student.name)
                            .font(.headline)
                    }
                    
                    if let assessment = studentResult.assessment {
                        Text(assessment.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // MARK: - Score Buttons
            
            VStack(spacing: 14) {
                scoreButton(1, "Needs significant support".localized)
                scoreButton(2, "Beginning".localized)
                scoreButton(3, "Developing".localized)
                scoreButton(4, "Proficient".localized)
                scoreButton(5, "Mastering".localized)
            }
            
            Spacer()
        }
        .padding(24)
        
        // ✅ Fixed, predictable size
        .frame(width: 520, height: 520)
        
        // ✅ Fixed presentation style (no resizing, no dragging)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Button
    
    func scoreButton(_ value: Int, _ label: String) -> some View {
        let isSelected = Int(studentResult.score) == value
        
        return Button {
            studentResult.score = Double(value)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Text("\(value)")
                    .font(.title2)
                    .bold()
                    .frame(width: 36)
                
                Text(label)
                    .font(.headline)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue.opacity(0.25) : Color.blue.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}
