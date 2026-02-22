import SwiftUI

struct ScoreEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let studentResult: StudentResult
    let maxScore: Double

    @State private var scoreText: String

    init(studentResult: StudentResult, maxScore: Double) {
        self.studentResult = studentResult
        self.maxScore = Swift.min(Swift.max(maxScore, 1), 1000)
        if studentResult.score > 0 {
            _scoreText = State(initialValue: Self.formatScore(studentResult.score))
        } else {
            _scoreText = State(initialValue: "")
        }
    }

    var parsedScore: Double? {
        let cleaned = scoreText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if cleaned.isEmpty { return 0 }
        guard let value = Double(cleaned), value.isFinite, value >= 0 else {
            return nil
        }
        return Swift.min(value, maxScore)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set Score".localized)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let studentName = studentResult.student?.name {
                        Text(studentName)
                            .font(.headline)
                    }

                    if let assessmentTitle = studentResult.assessment?.title {
                        Text(assessmentTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Score".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    #if os(iOS)
                    TextField("0", text: $scoreText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(parsedScore == nil ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    #else
                    TextField("0", text: $scoreText)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(parsedScore == nil ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    #endif

                    Text(String(format: "Valid range: 0 to %@".localized, Self.formatScore(maxScore)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                quickButtons

                Spacer()
            }
            .padding()
            .navigationTitle("Score Entry".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        studentResult.score = parsedScore ?? 0
                        dismiss()
                    }
                    .disabled(parsedScore == nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    var quickButtons: some View {
        let values = [
            ("0%", 0.0),
            ("50%", maxScore * 0.5),
            ("70%", maxScore * 0.7),
            ("100%", maxScore)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Quick Set".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(values, id: \.0) { value in
                    Button {
                        scoreText = Self.formatScore(value.1)
                    } label: {
                        Text(value.0.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    static func formatScore(_ score: Double) -> String {
        if score.rounded() == score {
            return String(Int(score))
        }
        return String(format: "%.1f", score)
    }
}
