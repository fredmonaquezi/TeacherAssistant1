import SwiftUI

struct StudentProgressRunningRecordCardView: View, Equatable {
    let model: StudentProgressRunningRecordViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.headline)

                    Text(model.date.appDateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", model.accuracy))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(readingLevelColor(model.readingLevel))

                    HStack(spacing: 4) {
                        Image(systemName: model.readingLevel.systemImage)
                            .font(.caption)
                        Text(readingLevelShortName(model.readingLevel))
                            .font(.caption)
                    }
                    .foregroundColor(readingLevelColor(model.readingLevel))
                }
            }

            if !model.notes.isEmpty {
                Divider()

                Text(model.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func readingLevelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }

    private func readingLevelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Ind."
        case .instructional: return "Inst."
        case .frustration: return "Frust."
        }
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
