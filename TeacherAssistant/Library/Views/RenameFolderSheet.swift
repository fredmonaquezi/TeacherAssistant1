import SwiftUI

struct RenameFolderSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appMotionContext) private var motion

    @State private var name: String

    let onSave: (String) -> Void

    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Folder Name", systemImage: "folder.badge.pencil")
                            .font(.headline)
                            .foregroundColor(.accentColor)

                        Text("Update the library folder name. The change applies everywhere this folder appears.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .appMotionReveal(index: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .padding()
                            .appFieldStyle(tint: .accentColor)
                    }
                    .appCardStyle(
                        cornerRadius: 14,
                        borderColor: AppChrome.separator,
                        shadowOpacity: 0.03,
                        shadowRadius: 4,
                        shadowY: 2,
                        tint: .accentColor
                    )
                    .appMotionReveal(index: 1)
                }
                .padding(24)
            }
            .navigationTitle("Rename Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let sanitized = SecurityHelpers.sanitizeName(name) {
                            onSave(sanitized)
                        }
                        dismiss()
                    }
                }
            }
        }
        .appSheetMotion()
        .animation(motion.animation(.standard), value: name)
    }
}
