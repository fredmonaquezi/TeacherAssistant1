import SwiftUI

struct RenameFolderSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String

    let onSave: (String) -> Void

    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("Name", text: $name)
                }
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
    }
}
