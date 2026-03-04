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

                if !timer.checklist.isEmpty {
                    Text("\(timer.checklist.count) tasks queued".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                timer.isExpanded = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(AppChrome.elevatedBackground)
                    )
            }
            .buttonStyle(.plain)

            Button {
                timer.reset()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: progressColor.opacity(0.18),
            shadowOpacity: 0.12,
            shadowRadius: 12,
            shadowY: 5,
            tint: progressColor
        )
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
