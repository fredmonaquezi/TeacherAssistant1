import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class ClassroomTimerManager: ObservableObject {

    @Published var isRunning: Bool = false
    @Published var isExpanded: Bool = true

    @Published var totalSeconds: Int = 0
    @Published var remainingSeconds: Int = 0
    @Published var showTimesUp: Bool = false
    @Published var checklist: [String] = []

    private var timer: Timer?
    private var player: AVAudioPlayer?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    func start(minutes: Int, checklist: [String] = []) {
        start(seconds: minutes * 60, checklist: checklist)
    }

    func start(seconds: Int, checklist: [String] = []) {
        reset()   // 🔥 always start from a clean state
        
        guard seconds > 0 else { return }

        let sanitizedChecklist = checklist
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        showTimesUp = false
        totalSeconds = seconds
        remainingSeconds = seconds
        self.checklist = Array(sanitizedChecklist.prefix(15))
        isRunning = true
        isExpanded = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        stopSound()
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finish()
            return
        }
        remainingSeconds -= 1
    }

    private func finish() {
        stopTimerOnly()
        playSound()
        showTimesUp = true
    }

    // MARK: - Sound

    private func playSound() {
        guard let url = Bundle.main.url(forResource: "timer_end", withExtension: "wav") else {
            SecureLogger.warning("Sound file not found")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // 🔁 Loop until user dismisses
            player?.play()
        } catch {
            SecureLogger.error("Could not play sound", error: error)
        }
    }

    private func stopSound() {
        player?.stop()
        player = nil
    }

    // MARK: - Reset / Dismiss Logic

    /// Stops timer but does NOT touch UI state
    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Call this when user taps "Dismiss" on Time's Up
    func dismissTimesUpAndReset() {
        stopSound()
        stopTimerOnly()
        
        // Reset all UI-driving state
        showTimesUp = false
        isRunning = false
        isExpanded = false
        
        totalSeconds = 0
        remainingSeconds = 0
        checklist = []
    }

    /// Full reset (used before starting a new timer)
    func reset() {
        stopSound()
        stopTimerOnly()
        
        showTimesUp = false
        isRunning = false
        isExpanded = false
        
        totalSeconds = 0
        remainingSeconds = 0
        checklist = []
    }


    // MARK: - UI Helpers

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
