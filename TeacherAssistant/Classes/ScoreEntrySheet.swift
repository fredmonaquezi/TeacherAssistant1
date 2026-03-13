import SwiftUI
import SwiftData

struct ScoreEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let studentResult: StudentResult
    let maxScore: Double

    @State private var scoreText: String
    @State private var selectedStatus: AssessmentResultStatus

    init(studentResult: StudentResult, maxScore: Double) {
        self.studentResult = studentResult
        self.maxScore = Swift.min(Swift.max(maxScore, 1), 1000)
        _selectedStatus = State(initialValue: studentResult.status)
        if studentResult.isScored {
            _scoreText = State(initialValue: Self.formatScore(studentResult.score))
        } else {
            _scoreText = State(initialValue: "")
        }
    }

    var trimmedScoreText: String {
        scoreText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedScore: Double? {
        let cleaned = trimmedScoreText
            .replacingOccurrences(of: ",", with: ".")
        if cleaned.isEmpty { return nil }
        guard let value = Double(cleaned), value.isFinite, value >= 0 else {
            return nil
        }
        return Swift.min(value, maxScore)
    }

    var scoreTint: Color {
        selectedStatus == .scored && parsedScore == nil ? .red : tintColor(for: selectedStatus)
    }

    var scorePercentText: String? {
        guard selectedStatus == .scored, let parsedScore, maxScore > 0 else { return nil }
        let percent = (parsedScore / maxScore) * 100
        return String(format: "%.0f%%", percent)
    }

    var canSave: Bool {
        switch selectedStatus {
        case .scored:
            return parsedScore != nil
        case .ungraded, .absent, .excused:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                contextCard
                statusCard
                scoreEditorCard
                quickButtons
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .appSheetBackground(tint: .blue)
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
                    Button("Confirm".localized) {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    var contextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let studentName = studentResult.student?.name {
                Text(studentName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if let assessmentTitle = studentResult.assessment?.title {
                Text(assessmentTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                infoPill(
                    title: "Range".localized,
                    value: "0-\(Self.formatScore(maxScore))"
                )

                infoPill(
                    title: "Status".localized,
                    value: localizedStatusLabel(selectedStatus)
                )

                if let scorePercentText {
                    infoPill(
                        title: "Percent".localized,
                        value: scorePercentText
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.10),
            shadowOpacity: 0.04,
            shadowRadius: 6,
            shadowY: 2,
            tint: .blue
        )
    }

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Picker("Status".localized, selection: $selectedStatus) {
                ForEach(AssessmentResultStatus.allCases, id: \.rawValue) { status in
                    Text(localizedStatusLabel(status))
                        .tag(status)
                }
            }
            .pickerStyle(.segmented)

            Text(statusHelpText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: tintColor(for: selectedStatus).opacity(0.14),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: tintColor(for: selectedStatus)
        )
    }

    var scoreEditorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Group {
                    #if os(iOS)
                    SelectAllCommitTextField(
                        placeholder: "0",
                        text: $scoreText,
                        keyboardType: .decimalPad,
                        autoFocus: true,
                        onCommit: saveAndDismiss
                    )
                    #else
                    SelectAllCommitTextField(
                        placeholder: "0",
                        text: $scoreText,
                        autoFocus: true,
                        onCommit: saveAndDismiss
                    )
                    #endif
                }
                .frame(height: 22)
                .padding(.horizontal, 14)
                .frame(width: 120, height: 52)
                .appFieldStyle(
                    tint: scoreTint,
                    isInvalid: selectedStatus == .scored && parsedScore == nil
                )

                VStack(alignment: .leading, spacing: 4) {
                    if selectedStatus == .scored && parsedScore == nil {
                        Text("Enter a valid number".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    } else if selectedStatus != .scored {
                        Text("This assessment will not count toward averages.".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Replaces the current value".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(
                        selectedStatus == .scored
                            ? "Tap Confirm or press Return to save".localized
                            : "Save the selected status for this student.".localized
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: scoreTint.opacity(0.14),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: scoreTint
        )
        .opacity(selectedStatus == .scored ? 1 : 0.72)
    }

    var quickButtons: some View {
        let values = [
            ("0%", 0.0),
            ("50%", maxScore * 0.5),
            ("70%", maxScore * 0.7),
            ("100%", maxScore)
        ]
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Quick Set".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(values, id: \.0) { value in
                    Button {
                        scoreText = Self.formatScore(value.1)
                        selectedStatus = .scored
                    } label: {
                        Text(value.0.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(AppChrome.elevatedBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .blue
        )
        .opacity(selectedStatus == .scored ? 1 : 0.5)
        .allowsHitTesting(selectedStatus == .scored)
    }

    func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppChrome.elevatedBackground)
        )
    }

    func saveAndDismiss() {
        switch selectedStatus {
        case .scored:
            guard let parsedScore else { return }
            studentResult.applyStatus(.scored, score: parsedScore)
        case .ungraded:
            studentResult.applyStatus(.ungraded)
        case .absent:
            studentResult.applyStatus(.absent)
        case .excused:
            studentResult.applyStatus(.excused)
        }

        Task {
            let result = await SaveCoordinator.perform(context: context, reason: "Save score entry")
            if result.didSave {
                dismiss()
            }
        }
    }

    static func formatScore(_ score: Double) -> String {
        if score.rounded() == score {
            return String(Int(score))
        }
        return String(format: "%.1f", score)
    }

    func localizedStatusLabel(_ status: AssessmentResultStatus) -> String {
        switch status {
        case .ungraded:
            return "Ungraded".localized
        case .scored:
            return "Scored".localized
        case .absent:
            return "Absent".localized
        case .excused:
            return "Excused".localized
        }
    }

    var statusHelpText: String {
        switch selectedStatus {
        case .ungraded:
            return "Keeps this student pending for later grading.".localized
        case .scored:
            return "Counts toward averages and performance summaries.".localized
        case .absent:
            return "Marks the student as absent for this assessment.".localized
        case .excused:
            return "Excludes the student from grading for this assessment.".localized
        }
    }

    func tintColor(for status: AssessmentResultStatus) -> Color {
        switch status {
        case .ungraded:
            return .gray
        case .scored:
            return .blue
        case .absent:
            return .orange
        case .excused:
            return .purple
        }
    }
}
