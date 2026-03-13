import SwiftUI
import SwiftData

struct CalendarHeaderSectionView: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarRootView.CalendarViewMode
    let localeIdentifier: String
    @Environment(\.appMotionContext) private var motion

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    withAnimation(motion.animation(.standard)) {
                        shiftDate(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(AppPressableButtonStyle())

                Spacer()

                Text(monthTitle(for: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    withAnimation(motion.animation(.standard)) {
                        shiftDate(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(AppPressableButtonStyle())
            }

            Picker("View Mode".localized, selection: $viewMode) {
                ForEach(CalendarRootView.CalendarViewMode.allCases, id: \.rawValue) { mode in
                    Text(mode.localizedLabel).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }

    private func shiftDate(by amount: Int) {
        let component: Calendar.Component = viewMode == .month ? .month : .weekOfYear
        selectedDate = Calendar.current.date(byAdding: component, value: amount, to: selectedDate) ?? selectedDate
    }

    private func monthTitle(for date: Date) -> String {
        CalendarLocalizedFormatting.monthTitle(
            for: date,
            localeIdentifier: localeIdentifier,
            in: viewMode
        )
    }
}

struct CalendarFilterSectionView: View {
    let classes: [SchoolClass]
    @Binding var selectedClassID: PersistentIdentifier?
    let onSelectToday: () -> Void
    @Environment(\.appMotionContext) private var motion

    var body: some View {
        HStack(spacing: 12) {
            Text("Class".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Class".localized, selection: $selectedClassID) {
                Text("All Classes".localized).tag(PersistentIdentifier?.none)
                ForEach(classes, id: \.persistentModelID) { schoolClass in
                    Text(schoolClass.name).tag(PersistentIdentifier?.some(schoolClass.persistentModelID))
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Button {
                withAnimation(motion.animation(.standard)) {
                    onSelectToday()
                }
            } label: {
                Text("Today".localized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .appCardStyle(
                        cornerRadius: 10,
                        borderColor: Color.blue.opacity(0.16),
                        shadowOpacity: 0.02,
                        shadowRadius: 4,
                        shadowY: 1,
                        tint: .blue
                    )
            }
            .buttonStyle(AppPressableButtonStyle())
        }
        .padding(.horizontal, 4)
    }
}
