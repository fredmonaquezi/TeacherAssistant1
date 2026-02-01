import SwiftUI

struct AddSubjectView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var schoolClass: SchoolClass
    
    @State private var name = ""
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    
    /// Validates the current name input
    private var isNameValid: Bool {
        SecurityHelpers.sanitizeName(name) != nil
    }
    
    /// Returns validation message for name field
    private var validationMessage: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count > SecurityHelpers.maxNameLength {
            return "Subject name is too long (max \(SecurityHelpers.maxNameLength) characters)"
        }
        if SecurityHelpers.sanitizeName(name) == nil {
            return "Subject name contains invalid characters"
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "book.badge.plus.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Add New Subject".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Adding to \(schoolClass.name)".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Form field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Subject Name".localized, systemImage: "book.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        TextField("e.g., Mathematics".localized, text: $name)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding()
                            .background(
                                validationMessage != nil ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(validationMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        
                        // Validation feedback
                        if let message = validationMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Character count
                        Text("\(name.count)/\(SecurityHelpers.maxNameLength)")
                            .font(.caption2)
                            .foregroundColor(name.count > SecurityHelpers.maxNameLength ? .red : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    
                    // Preview
                    if !name.isEmpty && isNameValid {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "book.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.headline)
                                    Text(schoolClass.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Info card
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        
                        Text("You can add units and assessments after creating the subject".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                }
            }
            .navigationTitle("New Subject".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add".localized) {
                        guard let sanitizedName = SecurityHelpers.sanitizeName(name) else {
                            validationErrorMessage = "Please enter a valid subject name"
                            showingValidationError = true
                            return
                        }
                        
                        let newSubject = Subject(name: sanitizedName)
                        newSubject.schoolClass = schoolClass
                        newSubject.sortOrder = schoolClass.subjects.count
                        schoolClass.subjects.append(newSubject)
                        dismiss()
                    }
                    .disabled(!isNameValid)
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationErrorMessage)
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 450)
        #endif
    }
}
