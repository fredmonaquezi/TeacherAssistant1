import SwiftUI

struct TimerOverlayView: View {

    @ObservedObject var timer: ClassroomTimerManager

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                
                // Timer circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 300, height: 300)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            LinearGradient(
                                colors: progressColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timer.progress)
                    
                    // Time display
                    VStack(spacing: 8) {
                        Text(timer.formattedTime)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                        
                        Text(timeRemaining)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Controls
                HStack(spacing: 20) {
                    Button {
                        timer.reset()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        timer.isExpanded.toggle()
                    } label: {
                        HStack {
                            Image(systemName: timer.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            Text(timer.isExpanded ? "Minimize" : "Expand")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .padding(40)
        }
    }
    
    var progressColors: [Color] {
        if timer.progress > 0.5 {
            return [.green, .blue]
        } else if timer.progress > 0.2 {
            return [.orange, .yellow]
        } else {
            return [.red, .orange]
        }
    }
    
    var timeRemaining: String {
        let minutes = timer.remainingSeconds / 60
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        } else {
            return "\(timer.remainingSeconds) second\(timer.remainingSeconds == 1 ? "" : "s") remaining"
        }
    }
}
