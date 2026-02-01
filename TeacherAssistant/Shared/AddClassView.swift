import SwiftUI
import SwiftData

struct AddClassView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    
    @State private var name = ""
    @State private var grade = ""
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    
    @FocusState private var isInputFocused: Bool
    
    /// Validates the current name input
    private var isNameValid: Bool {
        SecurityHelpers.sanitizeName(name) != nil
    }
    
    /// Validates the current grade input
    private var isGradeValid: Bool {
        SecurityHelpers.sanitizeName(grade) != nil
    }
    
    /// Returns validation message for name field
    private var nameValidationMessage: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count > SecurityHelpers.maxNameLength {
            return "Name is too long"
        }
        if SecurityHelpers.sanitizeName(name) == nil {
            return "Name contains invalid characters"
        }
        return nil
    }
    
    /// Returns validation message for grade field
    private var gradeValidationMessage: String? {
        let trimmed = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count > SecurityHelpers.maxNameLength {
            return "Grade is too long"
        }
        if SecurityHelpers.sanitizeName(grade) == nil {
            return "Grade contains invalid characters"
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Create New Class".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add a class to organize your students".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Class name field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Class Name".localized, systemImage: "person.3.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., 3A, Year 9 English", text: $name)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isInputFocused)
                                .padding()
                                .background(
                                    nameValidationMessage != nil ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(nameValidationMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            
                            if let message = nameValidationMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Grade field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Grade Level".localized, systemImage: "graduationcap.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Year 3, Grade 9", text: $grade)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isInputFocused)
                                .padding()
                                .background(
                                    gradeValidationMessage != nil ? Color.red.opacity(0.1) : Color.green.opacity(0.1)
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(gradeValidationMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            
                            if let message = gradeValidationMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Preview
                        if !name.isEmpty && !grade.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preview".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "building.2.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.headline)
                                        Text(grade)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Helpful tip
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            
                            Text("You can add students and subjects after creating the class".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                }
            }
            .navigationTitle("New Class".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        isInputFocused = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        guard let sanitizedName = SecurityHelpers.sanitizeName(name),
                              let sanitizedGrade = SecurityHelpers.sanitizeName(grade) else {
                            validationErrorMessage = "Please enter valid class name and grade"
                            showingValidationError = true
                            return
                        }
                        
                        let newClass = SchoolClass(name: sanitizedName, grade: sanitizedGrade)
                        newClass.sortOrder = classes.count
                        context.insert(newClass)
                        
                        isInputFocused = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            dismiss()
                        }
                    }
                    .disabled(!isNameValid || !isGradeValid)
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
        .frame(minWidth: 500, minHeight: 550)
        #endif
    }
}
