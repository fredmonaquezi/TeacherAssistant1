import SwiftUI
import SwiftData

struct AddStudentView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var schoolClass: SchoolClass
    
    @State private var name = ""
    @State private var gender: StudentGender = .preferNotToSay
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    
    /// Validates the current name input
    private var isNameValid: Bool {
        SecurityHelpers.sanitizeName(name) != nil
    }
    
    /// Returns the sanitized name or nil if invalid
    private var sanitizedName: String? {
        SecurityHelpers.sanitizeName(name)
    }

    private func normalizedStudentName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    /// Validation message for the current input
    private var validationMessage: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil // Don't show error for empty field
        }
        if trimmed.count > SecurityHelpers.maxNameLength {
            return "Name is too long (max \(SecurityHelpers.maxNameLength) characters)"
        }
        if SecurityHelpers.sanitizeName(name) == nil {
            return "Name contains invalid characters"
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Add New Student".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Adding to".localized + " \(schoolClass.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Form fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Student Name".localized, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Sarah Johnson", text: $name)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding()
                                .background(
                                    validationMessage != nil ? Color.red.opacity(0.1) : Color.green.opacity(0.1)
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
                        
                        // Gender picker
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Gender (Optional)".localized, systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Picker("Gender".localized, selection: $gender) {
                                ForEach(StudentGender.allCases, id: \.self) { genderOption in
                                    Text(genderOption.rawValue).tag(genderOption)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text("Used for group balancing in group generator".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Preview
                    if !name.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                
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
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Info card
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("Assessment scores will be initialized to 0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                }
            }
            .navigationTitle("New Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let validName = sanitizedName else {
                            validationErrorMessage = "Please enter a valid name"
                            showingValidationError = true
                            return
                        }

                        let normalizedName = normalizedStudentName(validName)
                        let hasDuplicateName = schoolClass.students.contains { student in
                            normalizedStudentName(student.name) == normalizedName
                        }
                        if hasDuplicateName {
                            validationErrorMessage = "A student with this name already exists in this class."
                            showingValidationError = true
                            return
                        }
                        
                        let newStudent = Student(name: validName, gender: gender)
                        newStudent.sortOrder = schoolClass.students.count
                        
                        // Create one score per category
                        for _ in schoolClass.categories {
                            newStudent.scores.append(AssessmentScore(value: 0))
                        }
                        
                        schoolClass.students.append(newStudent)
                        syncStudentResults(for: newStudent)
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

    // MARK: - Background Sync

    func syncStudentResults(for student: Student) {
        let sortedSubjects = schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
        for subject in sortedSubjects {
            for unit in subject.units.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                for assessment in unit.assessments {
                    let existingStudentIDs = Set(assessment.results.compactMap { $0.student?.id })
                    guard !existingStudentIDs.contains(student.id) else { continue }
                    assessment.results.append(StudentResult(student: student, assessment: assessment))
                }
            }
        }
    }
}
