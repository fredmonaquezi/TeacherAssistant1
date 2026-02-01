import SwiftUI

struct RandomPickerResultView: View {
    
    let student: Student
    let onPickAgain: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var isAnimating = false
    @State private var showConfetti = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    
                    Spacer()
                    
                    // Trophy/Winner icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                    }
                    
                    // "Selected Student" label
                    VStack(spacing: 8) {
                        Text("🎉 \(languageManager.localized("Selected Student")) 🎉")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        // Student name - BIG
                        Text(student.name)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .opacity(isAnimating ? 1.0 : 0.0)
                    }
                    
                    // Student info card
                    studentInfoCard
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            onPickAgain()
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text(languageManager.localized("Pick Again"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text(languageManager.localized("Done"))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Confetti effect
                if showConfetti {
                    ConfettiView()
                }
            }
            .navigationTitle("")
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
        .onAppear {
            withAnimation(.spring(response: 0.6)) {
                isAnimating = true
            }
            showConfetti = true
            
            // Hide confetti after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        }
    }
    
    // MARK: - Student Info Card
    
    var studentInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localized("Student Info"))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 8) {
                if student.isParticipatingWell {
                    statusRow(icon: "star.fill", text: languageManager.localized("Participating Well"), color: .green)
                }
                
                if student.needsHelp {
                    statusRow(icon: "exclamationmark.triangle.fill", text: languageManager.localized("Needs Help"), color: .orange)
                }
                
                if student.missingHomework {
                    statusRow(icon: "book.fill", text: languageManager.localized("Missing Homework"), color: .red)
                }
                
                if !student.isParticipatingWell && !student.needsHelp && !student.missingHomework {
                    Text(languageManager.localized("No status flags"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func statusRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces) { piece in
                ConfettiShape()
                    .fill(piece.color)
                    .frame(width: 10, height: 10)
                    .position(piece.position)
                    .rotationEffect(piece.rotation)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            generateConfetti()
        }
    }
    
    func generateConfetti() {
        let colors: [Color] = [.orange, .yellow, .red, .pink, .purple, .blue, .green]
        
        #if os(macOS)
        let screenWidth: CGFloat = 800
        let screenHeight: CGFloat = 600
        #else
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        #endif
        
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: -20
                ),
                color: colors.randomElement()!,
                rotation: .degrees(Double.random(in: 0...360))
            )
            confettiPieces.append(piece)
        }
        
        // Animate falling
        withAnimation(.linear(duration: 3.0)) {
            for i in confettiPieces.indices {
                confettiPieces[i].position.y = screenHeight + 20
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let rotation: Angle
}

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addEllipse(in: rect)
        }
    }
}
