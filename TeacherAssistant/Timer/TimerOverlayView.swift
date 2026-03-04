import SwiftUI

struct TimerOverlayView: View {

    @ObservedObject var timer: ClassroomTimerManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                HStack(alignment: .center, spacing: 32) {
                    timerDisplay

                    if !timer.checklist.isEmpty {
                        checklistPanel
                    }
                }

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
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red)
                        )
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
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppChrome.elevatedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppChrome.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .frame(maxWidth: timer.checklist.isEmpty ? 420 : 860)
            .padding(40)
        }
    }

    var timerDisplay: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .frame(width: 300, height: 300)

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
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var checklistPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timer To-Do List".localized)
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(timer.checklist.count) tasks".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(timer.checklist.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(width: 28, alignment: .leading)

                            Text(item)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 360, height: 320, alignment: .topLeading)
        .appCardStyle(
            cornerRadius: 18,
            borderColor: Color.blue.opacity(0.12),
            shadowOpacity: 0.10,
            shadowRadius: 12,
            shadowY: 5,
            tint: .blue
        )
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
