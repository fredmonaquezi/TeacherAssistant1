import SwiftUI
import SwiftUI
import SwiftData

struct ClassDetailView: View {
    
    @Bindable var schoolClass: SchoolClass
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var showingAddStudent = false
    @State private var showingAddSubject = false
    @State private var showingCategories = false
    @State private var pickedStudent: Student?
    @State private var showingGroupGenerator = false
    @State private var showingAttendance = false
    
    @State private var studentToDelete: Student?
    @State private var subjectToDelete: Subject?
    @State private var showingDeleteStudentAlert = false
    @State private var showingDeleteSubjectAlert = false
        
    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iPadLayout
            #endif
        }
        .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
        #if !os(macOS)
        .navigationTitle(schoolClass.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddStudent = true
                    } label: {
                        Label("Add Student".localized, systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        showingAddSubject = true
                    } label: {
                        Label("Add Subject".localized, systemImage: "book.badge.plus")
                    }
                    
                    Divider()
                    
                    Button("🎲 " + "Pick Random Student".localized) {
                        pickRandomStudent()
                    }
                    .disabled(schoolClass.students.isEmpty)
                    
                    Button("👥 " + "Group Generator".localized) {
                        showingGroupGenerator = true
                    }
                    .disabled(schoolClass.students.isEmpty)
                    
                    Button("📋 " + "Take Attendance".localized) {
                        showingAttendance = true
                    }
                    .disabled(schoolClass.students.isEmpty)
                    
                    Divider()
                    
                    Button("⚙️ " + "Assessment Categories".localized) {
                        showingCategories = true
                    }
                    
                } label: {
                    Label("Actions".localized, systemImage: "ellipsis.circle")
                }
            }
        }
        #endif
        .sheet(isPresented: $showingAddStudent) {
            AddStudentView(schoolClass: schoolClass)
        }
        .sheet(isPresented: $showingAddSubject) {
            AddSubjectView(schoolClass: schoolClass)
        }
        .sheet(isPresented: $showingCategories) {
            ClassCategoriesView(schoolClass: schoolClass)
        }
        .sheet(
            isPresented: Binding(
                get: { pickedStudent != nil },
                set: { if !$0 { pickedStudent = nil } }
            )
        ) {
            if let pickedStudent {
                RandomPickerResultView(student: pickedStudent, onPickAgain: {
                    self.pickedStudent = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pickRandomStudent()
                    }
                })
            }
        }
        .sheet(isPresented: $showingGroupGenerator) {
            #if os(macOS)
            NavigationStack {
                AdvancedGroupGeneratorView(schoolClass: schoolClass)
            }
            #else
            AdvancedGroupGeneratorView(schoolClass: schoolClass)
            #endif
        }
        .sheet(isPresented: $showingAttendance) {
            #if os(macOS)
            NavigationStack {
                AttendanceListView(schoolClass: schoolClass)
            }
            #else
            AttendanceListView(schoolClass: schoolClass)
            #endif
        }
        .alert("Delete Student?".localized, isPresented: $showingDeleteStudentAlert) {
            Button("Cancel".localized, role: .cancel) {
                studentToDelete = nil
            }
            Button("Delete".localized, role: .destructive) {
                if let studentToDelete {
                    schoolClass.students.removeAll { $0.id == studentToDelete.id }
                    let sorted = schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
                    for (index, student) in sorted.enumerated() {
                        student.sortOrder = index
                    }
                }
                studentToDelete = nil
            }
        } message: {
            if let studentToDelete {
                Text(String(format: "Are you sure you want to delete \"%@\"? All their grades and attendance records will be lost.".localized, studentToDelete.name))
            }
        }
        .alert("Delete Subject?".localized, isPresented: $showingDeleteSubjectAlert) {
            Button("Cancel", role: .cancel) {
                subjectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let subjectToDelete {
                    if let index = schoolClass.subjects.firstIndex(where: { $0.id == subjectToDelete.id }) {
                        schoolClass.subjects.remove(at: index)
                    }
                }
                subjectToDelete = nil
            }
        } message: {
            if let subjectToDelete {
                Text(String(format: "Are you sure you want to delete \"%@\"? All units, assessments and grades inside this subject will be lost.".localized, subjectToDelete.name))
            }
        }
        .macNavigationDepth()
    }

    var orderedStudents: [Student] {
        schoolClass.students.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    // MARK: - Mac Layout
    
    @ViewBuilder
    var macOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Class info header
                classInfoHeader
                
                // Quick actions
                quickActionsSection
                
                // Subjects section
                subjectsSection
                
                // Students section
                studentsSection
                
            }
            .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
            .padding()
        }
    }
    
    // MARK: - Class Info Header
    
    var classInfoHeader: some View {
        HStack(spacing: 20) {
            // Class icon
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
            
            // Class info
            VStack(alignment: .leading, spacing: 8) {
                Text(schoolClass.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(schoolClass.grade)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Label("\(schoolClass.students.count) \(schoolClass.students.count == 1 ? "Student".localized : "Students".localized)", systemImage: "person.3.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label("\(schoolClass.subjects.count) \(schoolClass.subjects.count == 1 ? "Subject".localized : "Subjects".localized)", systemImage: "book.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions
    
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localized("Quick Actions"))
                .font(.headline)
            
            HStack(spacing: 12) {
                quickActionButton(
                    title: languageManager.localized("Random Picker"),
                    icon: "shuffle",
                    color: .orange,
                    disabled: schoolClass.students.isEmpty
                ) {
                    pickRandomStudent()
                }
                
                quickActionButton(
                    title: languageManager.localized("Groups"),
                    icon: "person.3.fill",
                    color: .purple,
                    disabled: schoolClass.students.isEmpty
                ) {
                    showingGroupGenerator = true
                }
                
                quickActionButton(
                    title: languageManager.localized("Attendance"),
                    icon: "checklist",
                    color: .blue,
                    disabled: schoolClass.students.isEmpty
                ) {
                    showingAttendance = true
                }
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force this section to refresh
    }
    
    func quickActionButton(title: String, icon: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(disabled ? .secondary : color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(disabled ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(disabled ? Color.gray.opacity(0.1) : color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Subjects Section
    
    @ViewBuilder
    var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text(languageManager.localized("Subjects"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    showingAddSubject = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(languageManager.localized("Add Subject"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if schoolClass.subjects.isEmpty {
                emptyStateView(
                    icon: "book",
                    title: "No Subjects Yet".localized,
                    message: "Add your first subject to organize your curriculum".localized,
                    actionTitle: "Add Subject".localized
                ) {
                    showingAddSubject = true
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 20)
                ], spacing: 20) {
                    ForEach(schoolClass.subjects.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { subject in
                        NavigationLink {
                            SubjectDetailView(subject: subject)
                        } label: {
                            SubjectCardView(subject: subject, onDelete: {
                                subjectToDelete = subject
                                showingDeleteSubjectAlert = true
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force this section to refresh
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Students Section
    
    @ViewBuilder
    var studentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            studentsHeader
            
            if schoolClass.students.isEmpty {
                emptyStateView(
                    icon: "person.badge.plus",
                    title: "No Students Yet".localized,
                    message: "Add students to start tracking their progress".localized,
                    actionTitle: "Add Student".localized
                ) {
                    showingAddStudent = true
                }
            } else {
                studentsGrid(minimum: 240, maximum: 320, spacing: 16)
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force this section to refresh
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Empty State
    
    func emptyStateView(icon: String, title: String, message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: action) {
                Text(actionTitle)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - iPad / iPhone Layout
    
    @ViewBuilder
    var iPadLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Class info header
                classInfoHeader
                
                // Quick actions
                quickActionsSection
                
                // Subjects section
                iOSSubjectsSection
                
                // Students section
                iOSStudentsSection
                
            }
            .id(languageManager.currentLanguage) // 🔄 Force refresh when language changes
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - iOS Subjects Section
    
    @ViewBuilder
    var iOSSubjectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text(languageManager.localized("Subjects"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    showingAddSubject = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(languageManager.localized("Add Subject"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if schoolClass.subjects.isEmpty {
                emptyStateView(
                    icon: "book",
                    title: "No Subjects Yet".localized,
                    message: "Add your first subject to organize your curriculum".localized,
                    actionTitle: "Add Subject".localized
                ) {
                    showingAddSubject = true
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 320), spacing: 14)
                ], spacing: 14) {
                    ForEach(schoolClass.subjects.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { subject in
                        NavigationLink {
                            SubjectDetailView(subject: subject)
                        } label: {
                            SubjectCardView(subject: subject, onDelete: {
                                subjectToDelete = subject
                                showingDeleteSubjectAlert = true
                            })
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                subjectToDelete = subject
                                showingDeleteSubjectAlert = true
                            } label: {
                                Label("Delete".localized, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .id(languageManager.currentLanguage)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - iOS Students Section
    
    @ViewBuilder
    var iOSStudentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            studentsHeader
            
            if schoolClass.students.isEmpty {
                emptyStateView(
                    icon: "person.badge.plus",
                    title: "No Students Yet".localized,
                    message: "Add students to start tracking their progress".localized,
                    actionTitle: "Add Student".localized
                ) {
                    showingAddStudent = true
                }
            } else {
                studentsGrid(minimum: 150, maximum: 320, spacing: 14)
            }
        }
        .id(languageManager.currentLanguage)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }

    var studentsHeader: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.green)
            Text(languageManager.localized("Students"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                showingAddStudent = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text(languageManager.localized("Add Student"))
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            .buttonStyle(.plain)
        }
    }

    func studentsGrid(minimum: CGFloat, maximum: CGFloat, spacing: CGFloat) -> some View {
        let columns = [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing)]
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(orderedStudents, id: \.id) { student in
                NavigationLink {
                    StudentDetailView(student: student)
                } label: {
                    StudentCardView(student: student, onDelete: {
                        studentToDelete = student
                        showingDeleteStudentAlert = true
                    })
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    studentToDelete = student
                    showingDeleteStudentAlert = true
                } label: {
                    Label("Delete".localized, systemImage: "trash")
                }
            }
        }
    }
    }
    
    // MARK: - Reorder
    
    func moveStudents(from source: IndexSet, to destination: Int) {
        var sorted = schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)

        for (index, student) in sorted.enumerated() {
            student.sortOrder = index
        }
    }
    
    func moveSubjects(from source: IndexSet, to destination: Int) {
        var sorted = schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)

        for (index, subject) in sorted.enumerated() {
            subject.sortOrder = index
        }
    }

    
    // MARK: - Delete Flow
    
    func askToDeleteStudents(at offsets: IndexSet) {
        let sorted = schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
        guard let index = offsets.first else { return }

        studentToDelete = sorted[index]
        showingDeleteStudentAlert = true
    }
    
    func askToDeleteSubjects(at offsets: IndexSet) {
        let sorted = schoolClass.subjects.sorted { $0.sortOrder < $1.sortOrder }
        guard let index = offsets.first else { return }

        subjectToDelete = sorted[index]
        showingDeleteSubjectAlert = true
    }
    
    // MARK: - Actions
    
    func pickRandomStudent() {
        guard !schoolClass.students.isEmpty else { return }
        let sorted = schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
        pickedStudent = sorted.randomElement()
    }
}
