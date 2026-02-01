import SwiftUI

struct MiniTimerView: View {

    @ObservedObject var timer: ClassroomTimerManager

    var body: some View {
        HStack(spacing: 16) {
            // Progress circle (small)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text(timer.formattedTime)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Timer Running".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(timer.formattedTime)
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                timer.isExpanded = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button {
                timer.reset()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding()
    }
    
    var progressColor: Color {
        if timer.progress > 0.5 {
            return .green
        } else if timer.progress > 0.2 {
            return .orange
        } else {
            return .red
        }
    }
}
