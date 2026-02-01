import SwiftUI

struct TimesUpView: View {

    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: [Color.red.opacity(0.8), Color.orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(pulseAnimation ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

            VStack(spacing: 50) {
                
                // Alarm icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isAnimating ? -10 : 10))
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                }

                VStack(spacing: 16) {
                    Text("TIME'S UP!".localized)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("⏰ Timer has finished ⏰".localized)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }

                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Dismiss".localized)
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            isAnimating = true
            pulseAnimation = true
        }
    }
}
