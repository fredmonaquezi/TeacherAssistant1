import SwiftUI

struct TimerPickerView: View {

    @Environment(\.dismiss) var dismiss
    @ObservedObject var timer: ClassroomTimerManager

    @State private var customMinutes: Int = 5
    @State private var customSeconds: Int = 0

    let presets = [
        (minutes: 1, label: "1 min", color: Color.blue, icon: "hare.fill"),
        (minutes: 5, label: "5 min", color: Color.green, icon: "bolt.fill"),
        (minutes: 10, label: "10 min", color: Color.orange, icon: "flame.fill"),
        (minutes: 15, label: "15 min", color: Color.purple, icon: "star.fill"),
        (minutes: 30, label: "30 min", color: Color.pink, icon: "heart.fill"),
        (minutes: 45, label: "45 min", color: Color.indigo, icon: "sparkles"),
        (minutes: 60, label: "1 hour", color: Color.red, icon: "timer")
    ]

    var body: some View {
        #if os(macOS)
        // macOS: No NavigationStack needed, header navigation handles it
        timerContent
        #else
        // iOS: Keep NavigationStack for proper navigation
        NavigationStack {
            timerContent
        }
        #endif
    }
    
    var timerContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                headerCard
                
                // Quick presets
                presetsSection
                
                // Custom timer
                customTimerSection
                
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle("Timer".localized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    dismiss()
                }
            }
        }
        #endif
    }
    
    // MARK: - Header Card
    
    var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Classroom Timer".localized)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose a duration to start the countdown".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Presets Section
    
    var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Timers".localized)
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(presets, id: \.minutes) { preset in
                    presetCard(preset)
                }
            }
            .padding(.horizontal)
        }
    }
    
    func presetCard(_ preset: (minutes: Int, label: String, color: Color, icon: String)) -> some View {
        Button {
            playHaptic()
            timer.start(minutes: preset.minutes)
            dismiss()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 32))
                    .foregroundColor(preset.color)
                
                Text(preset.label.localized)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(preset.color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(preset.color.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Timer Section
    
    var customTimerSection: some View {
        VStack(spacing: 20) {
            Text("Custom Timer".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Time display
                HStack(spacing: 8) {
                    timeDisplay(value: customMinutes, unit: "min")
                    Text(":")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.secondary)
                    timeDisplay(value: customSeconds, unit: "sec")
                }
                
                // Pickers
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Minutes".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Minutes".localized, selection: $customMinutes) {
                            ForEach(0..<181, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .clipped()
                        .onChange(of: customMinutes) { _, _ in
                            playHaptic()
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("Seconds".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Seconds".localized, selection: $customSeconds) {
                            ForEach(0..<60, id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .clipped()
                        .onChange(of: customSeconds) { _, _ in
                            playHaptic()
                        }
                    }
                }
                
                // Start button
                Button {
                    playHaptic()
                    let totalSeconds = customMinutes * 60 + customSeconds
                    guard totalSeconds > 0 else { return }
                    timer.start(seconds: totalSeconds)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Custom Timer".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(customMinutes == 0 && customSeconds == 0)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    func timeDisplay(value: Int, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.blue)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Haptics (iOS only)

    func playHaptic() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
}
