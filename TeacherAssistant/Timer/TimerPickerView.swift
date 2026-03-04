import SwiftUI

struct TimerPickerView: View {
    @AppStorage("ta_timer_custom_minutes") private var storedCustomMinutes: Int = 5
    @AppStorage("ta_timer_custom_seconds") private var storedCustomSeconds: Int = 0
    @AppStorage("ta_timer_custom_checklist_text") private var storedChecklistText: String = ""

    @ObservedObject var timer: ClassroomTimerManager

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
        timerContent
    }
    
    var timerContent: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                
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
        #endif
    }
    
    // MARK: - Header Card
    
    var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Classroom Timer".localized)
                .font(.title2.weight(.bold))
            
            Text("Choose a duration to start the countdown".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
        .padding(.horizontal)
    }
    
    // MARK: - Presets Section
    
    var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Timers".localized)
                .font(AppTypography.sectionTitle)
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
        } label: {
            VStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 32))
                    .foregroundColor(preset.color)
                
                Text(preset.label.localized)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .appCardStyle(
                cornerRadius: 12,
                borderColor: preset.color.opacity(0.22),
                lineWidth: 1.6,
                shadowOpacity: 0.04,
                shadowRadius: 6,
                shadowY: 2,
                tint: preset.color
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Timer Section
    
    var customTimerSection: some View {
        VStack(spacing: 20) {
            Text("Custom Timer".localized)
                .font(AppTypography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Time display
                HStack(spacing: 8) {
                    timeDisplay(value: storedCustomMinutes, unit: "min")
                    Text(":")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.secondary)
                    timeDisplay(value: storedCustomSeconds, unit: "sec")
                }
                
                // Pickers
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Minutes".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Minutes".localized, selection: $storedCustomMinutes) {
                            ForEach(0..<181, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .clipped()
                        .onChange(of: storedCustomMinutes) { _, _ in
                            playHaptic()
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("Seconds".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Seconds".localized, selection: $storedCustomSeconds) {
                            ForEach(0..<60, id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .clipped()
                        .onChange(of: storedCustomSeconds) { _, _ in
                            playHaptic()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Timer To-Do List".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    TextEditor(text: $storedChecklistText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppChrome.elevatedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppChrome.separator, lineWidth: 1)
                        )

                    Text("Add one task per line. Bullets and numbered lists are cleaned automatically when the timer starts.".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Start button
                Button {
                    playHaptic()
                    let totalSeconds = storedCustomMinutes * 60 + storedCustomSeconds
                    guard totalSeconds > 0 else { return }
                    timer.start(
                        seconds: totalSeconds,
                        checklist: parseChecklist(from: storedChecklistText)
                    )
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Custom Timer".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .allowsHitTesting(false)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue)
                    )
                    .opacity(storedCustomMinutes == 0 && storedCustomSeconds == 0 ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .disabled(storedCustomMinutes == 0 && storedCustomSeconds == 0)
            }
            .padding()
            .appCardStyle(
                cornerRadius: 16,
                borderColor: Color.blue.opacity(0.10),
                tint: .blue
            )
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
        .padding(.horizontal, 8)
    }

    // MARK: - Haptics (iOS only)

    func playHaptic() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    func parseChecklist(from rawChecklist: String) -> [String] {
        rawChecklist
            .split(whereSeparator: \.isNewline)
            .map { line in
                line.replacingOccurrences(
                    of: #"^\s*(?:[-*]\s*|\d+\s*[-.):]\s*)"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .prefix(15)
            .map { String($0) }
    }
}
