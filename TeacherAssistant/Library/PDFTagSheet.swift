import SwiftUI
import SwiftData

struct PDFTagSheet: View {
    @Environment(\.appMotionContext) private var motion
    let fileName: String
    let onSave: (String, Subject?, Unit?) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Query private var allSubjects: [Subject]
    
    @State private var selectedSubject: Subject?
    @State private var selectedUnit: Unit?
    
    // MARK: - Filtered Data
    
    var validSubjects: [Subject] {
        // Only show subjects that still have a class (not orphaned)
        allSubjects.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    var availableUnits: [Unit] {
        // Only show units that still have a subject (not orphaned)
        selectedSubject?.units.filter { $0.subject != nil }.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
    }
    
    var body: some View {
        
        return NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with icon
                    headerSection
                        .appMotionReveal(index: 0)
                    
                    // File name card
                    fileNameCard
                        .appMotionReveal(index: 1)
                    
                    // Subject picker
                    subjectPickerCard
                        .appMotionReveal(index: 2)
                    
                    // Unit picker (if subject selected)
                    if selectedSubject != nil {
                        unitPickerCard
                            .appMotionReveal(index: 3)
                    }
                    
                    // Summary card
                    summaryCard
                        .appMotionReveal(index: 4)
                    
                    Spacer()
                    
                }
                .padding(24)
            }
            .appSheetBackground(tint: .blue)
            .navigationTitle("Tag PDF")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let sanitizedName = SecurityHelpers.sanitizeFilename(editedFileName)
                        onSave(sanitizedName.isEmpty ? fileName : sanitizedName, selectedSubject, selectedUnit)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onAppear {
                // Initialize the editable filename
                if editedFileName.isEmpty {
                    editedFileName = fileName
                }
                
                // Clear selections if linked objects were deleted
                if let subject = selectedSubject, !validSubjects.contains(where: { $0.id == subject.id }) {
                    selectedSubject = nil
                }
                if let unit = selectedUnit, !availableUnits.contains(where: { $0.id == unit.id }) {
                    selectedUnit = nil
                }
            }
        }
        .appSheetMotion()
        .animation(motion.animation(.standard), value: selectedSubject?.id)
        .animation(motion.animation(.standard), value: selectedUnit?.id)
#if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
#endif
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Link to Curriculum".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Organize your PDF by subject and unit for easy access".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - File Name Card
    
    @State private var editedFileName: String = ""
    
    var fileNameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("File Name", systemImage: "doc.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            TextField("Enter file name", text: $editedFileName)
                .textFieldStyle(.plain)
                .font(.body)
                .fontWeight(.medium)
                .padding()
                .appFieldStyle(tint: .blue)
        }
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.blue.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .blue
        )
    }
    
    
    // MARK: - Subject Picker Card

    var subjectPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("Subject".localized)
                    .font(.headline)
            }
            
            Picker("Select Subject", selection: $selectedSubject) {
                Text("None".localized).tag(nil as Subject?)
                ForEach(validSubjects, id: \.id) { subject in
                    if let className = subject.schoolClass?.name {
                        Text("\(subject.name) - \(className)").tag(subject as Subject?)
                    } else {
                        Text(subject.name).tag(subject as Subject?)
                    }
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
            .onChange(of: selectedSubject) { _, _ in
                selectedUnit = nil // Reset unit when subject changes
            }
            
            if selectedSubject == nil {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Optional - Select a subject to organize this PDF".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .appCardStyle(
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }
            
            // MARK: - Unit Picker Card
            
            var unitPickerCard: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        Text("Unit")
                            .font(.headline)
                    }
                    
                    if availableUnits.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No units available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Create units in this subject first")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(10)
                    } else {
                        Picker("Select Unit", selection: $selectedUnit) {
                            Text("None").tag(nil as Unit?)
                            ForEach(availableUnits, id: \.id) { unit in
                                Text(unit.name).tag(unit as Unit?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppChrome.elevatedBackground)
                        )
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Optional - Select a specific unit within the subject")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .appCardStyle(
                    borderColor: Color.orange.opacity(0.12),
                    tint: .orange
                )
                .transition(motion.transition(.inlineChange))
            }
            
            // MARK: - Summary Card
            
            var summaryCard: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Summary")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    if let subject = selectedSubject {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Subject")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(subject.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if let unit = selectedUnit {
                            Divider()
                            
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(unit.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Not linked")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Text("This PDF will only be in the folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green.opacity(0.1), Color.blue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
