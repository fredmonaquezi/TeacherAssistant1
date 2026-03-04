import SwiftUI
import SwiftData

struct CopyCriteriaSheet: View {
    
    let step: UnitDetailView.CopyStep
    let unit: Unit
    
    @Binding var selectedSubject: Subject?
    @Binding var selectedSourceUnit: Unit?
    @Binding var copyStep: UnitDetailView.CopyStep?
    
    var body: some View {
        NavigationStack {
            switch step {
                
            case .chooseSubject:
                chooseSubjectView
                
            case .chooseUnit:
                if selectedSubject != nil {
                    chooseUnitView
                }
                
            case .confirm:
                if selectedSourceUnit != nil {
                    confirmView
                }
            }
        }
        .appSheetBackground(tint: .orange)
    }
    
    // MARK: - Choose Subject View
    
    var chooseSubjectView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Copy Assessments".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a subject to copy assessments from".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal)
                .appCardStyle(
                    cornerRadius: 16,
                    borderColor: Color.orange.opacity(0.14),
                    tint: .orange
                )
                
                // Subjects Grid
                let subjects = subjectsInCurrentClass()
                
                if subjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No subjects found".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create subjects first to copy assessments".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .appCardStyle(
                        cornerRadius: 12,
                        borderColor: Color.orange.opacity(0.10),
                        shadowOpacity: 0.03,
                        shadowRadius: 5,
                        shadowY: 2,
                        tint: .orange
                    )
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(subjects, id: \.id) { subject in
                            subjectCard(subject)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Step 1: Choose Subject".localized)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    reset()
                }
            }
        }
    }
    
    func subjectCard(_ subject: Subject) -> some View {
        Button {
            selectedSubject = subject
            copyStep = .chooseUnit
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "book.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(spacing: 4) {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("\(subject.units.count) \(subject.units.count == 1 ? "unit".localized : "units".localized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .appCardStyle(
                cornerRadius: 12,
                borderColor: Color.blue.opacity(0.20),
                lineWidth: 1.6,
                tint: .blue
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Choose Unit View
    
    var chooseUnitView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    if let subject = selectedSubject {
                        Text(subject.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose a unit to copy assessments from".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal)
                .appCardStyle(
                    cornerRadius: 16,
                    borderColor: Color.green.opacity(0.14),
                    tint: .green
                )
                
                // Units List
                if let subject = selectedSubject {
                    let units = subject.units.sorted { $0.sortOrder < $1.sortOrder }.filter { $0.id != unit.id }
                    
                    if units.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No other units found".localized)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("This subject has no other units to copy from".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .appCardStyle(
                            cornerRadius: 12,
                            borderColor: Color.green.opacity(0.10),
                            shadowOpacity: 0.03,
                            shadowRadius: 5,
                            shadowY: 2,
                            tint: .green
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(units, id: \.id) { sourceUnit in
                                unitCard(sourceUnit)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Step 2: Choose Unit".localized)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    reset()
                }
            }
        }
    }
    
    func unitCard(_ sourceUnit: Unit) -> some View {
        Button {
            selectedSourceUnit = sourceUnit
            copyStep = .confirm
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceUnit.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(sourceUnit.assessments.count) \(sourceUnit.assessments.count == 1 ? "assessment".localized : "assessments".localized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .appCardStyle(
                cornerRadius: 12,
                borderColor: Color.green.opacity(0.12),
                tint: .green
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Confirm View
    
    var confirmView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon and Title
                VStack(spacing: 20) {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 70))
                        .foregroundColor(.orange)
                    
                    Text("Ready to Copy".localized)
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 60)
                
                // Copy Info Card
                VStack(spacing: 24) {
                    // From
                    if let sourceUnit = selectedSourceUnit {
                        VStack(spacing: 12) {
                            HStack {
                                Text("From".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sourceUnit.name)
                                        .font(.headline)
                                    Text("\(sourceUnit.assessments.count) assessments".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .appCardStyle(
                                cornerRadius: 10,
                                borderColor: Color.green.opacity(0.14),
                                shadowOpacity: 0.03,
                                shadowRadius: 4,
                                shadowY: 1,
                                tint: .green
                            )
                        }
                        
                        // Arrow
                        Image(systemName: "arrow.down")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        // To
                        VStack(spacing: 12) {
                            HStack {
                                Text("To".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(unit.name)
                                        .font(.headline)
                                    Text("Current unit".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .appCardStyle(
                                cornerRadius: 10,
                                borderColor: Color.blue.opacity(0.14),
                                shadowOpacity: 0.03,
                                shadowRadius: 4,
                                shadowY: 1,
                                tint: .blue
                            )
                        }
                    }
                }
                .padding()
                .appCardStyle(
                    cornerRadius: 16,
                    borderColor: Color.orange.opacity(0.10),
                    tint: .orange
                )
                .padding(.horizontal)
                
                // Info message
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("This will copy all assessment names to your current unit".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Step 3: Confirm".localized)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized) {
                    reset()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                if let sourceUnit = selectedSourceUnit {
                    Button {
                        copyCriteria(from: sourceUnit)
                        reset()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Assessments".localized)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func subjectsInCurrentClass() -> [Subject] {
        if let schoolClass = unit.subject?.schoolClass {
            return schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
        }
        return []
    }
    
    func copyCriteria(from sourceUnit: Unit) {
        let existingCount = unit.assessments.count
        let sourceSorted = sourceUnit.assessments.sorted { $0.sortOrder < $1.sortOrder }
        let classStudents = unit.subject?.schoolClass?.students ?? []
        
        for (index, old) in sourceSorted.enumerated() {
            let newAssessment = Assessment(title: old.title, maxScore: old.safeMaxScore)
            newAssessment.unit = unit
            newAssessment.sortOrder = existingCount + index
            unit.assessments.append(newAssessment)

            let existingStudentIDs = Set(newAssessment.results.compactMap { $0.student?.id })
            for student in classStudents where !existingStudentIDs.contains(student.id) {
                newAssessment.results.append(StudentResult(student: student, assessment: newAssessment))
            }
        }
    }
    
    func reset() {
        copyStep = nil
        selectedSubject = nil
        selectedSourceUnit = nil
    }
}
