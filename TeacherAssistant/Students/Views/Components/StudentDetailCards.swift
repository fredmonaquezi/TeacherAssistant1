import SwiftUI

struct StudentDetailSubjectCardView: View, Equatable {
    let model: StudentDetailSubjectCardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.subjectName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(model.assessmentCount) " + "assessments".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", model.averageScore))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(averageColor(model.averageScore))

                    Text("average".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
}

struct StudentDetailRecentGradeRowView: View, Equatable {
    let model: StudentDetailRecentGradeViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.assessmentTitle)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    if let subjectName = model.subjectName {
                        Text(subjectName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let unitName = model.unitName {
                        Text("• \(unitName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(String(format: "%.1f", model.score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(averageColor(model.score))
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
}
