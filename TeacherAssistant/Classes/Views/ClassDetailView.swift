import SwiftUI
import SwiftData

struct ClassDetailView: View {
    
    @Bindable var schoolClass: SchoolClass
    @ObservedObject var timerManager: ClassroomTimerManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appMotionContext) private var motion
    
    @State private var showingAddStudent = false
    @State private var showingAddSubject = false
    @State private var showingCategories = false
    @State private var pickedStudent: Student?
    @State private var showingGroupGenerator = false
    @State private var liveWorkspaceSection: LiveWorkspaceSection?
    
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
                        openLiveWorkspace(.attendance)
                    }
                    .disabled(schoolClass.students.isEmpty)

                    Button("🎯 " + "Classroom Session".localized) {
                        openLiveWorkspace(.session)
                    }
                    .disabled(schoolClass.students.isEmpty)

                    Button("📍 " + "Live Check-In".localized) {
                        openLiveWorkspace(.checkIn)
                    }
                    .disabled(schoolClass.students.isEmpty)

                    Button("🪑 " + "Seating Chart".localized) {
                        openLiveWorkspace(.seating)
                    }
                    .disabled(schoolClass.students.isEmpty)

                    Button("📝 " + "Assignments".localized) {
                        openLiveWorkspace(.assignments)
                    }
                    .disabled(schoolClass.subjects.flatMap(\.units).isEmpty)
                    
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
                .appSheetMotion()
        }
        .sheet(isPresented: $showingAddSubject) {
            AddSubjectView(schoolClass: schoolClass)
                .appSheetMotion()
        }
        .sheet(isPresented: $showingCategories) {
            ClassCategoriesView(schoolClass: schoolClass)
                .appSheetMotion()
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
                .appSheetMotion()
            }
        }
        .sheet(isPresented: $showingGroupGenerator) {
            #if os(macOS)
            NavigationStack {
                AdvancedGroupGeneratorView(schoolClass: schoolClass, showsDismissButton: true)
                    .appSheetMotion()
            }
            #else
            AdvancedGroupGeneratorView(schoolClass: schoolClass, showsDismissButton: true)
                .appSheetMotion()
            #endif
        }
        .navigationDestination(item: $liveWorkspaceSection) { section in
            LiveWorkspaceView(
                schoolClass: schoolClass,
                timerManager: timerManager,
                initialSection: section
            )
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
            VStack(alignment: .leading, spacing: PlatformSpacing.sectionSpacing + 8) {
                // Class info header
                classInfoHeader
                    .appMotionReveal(index: 0)
                
                // Quick actions
                quickActionsSection
                    .appMotionReveal(index: 1)
                
                // Subjects section
                subjectsSection
                    .appMotionReveal(index: 2)
                
                // Students section
                studentsSection
                    .appMotionReveal(index: 3)
                
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
                .appCardStyle(
                    cornerRadius: 16,
                    borderColor: Color.blue.opacity(0.16),
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2,
                    tint: .blue
                )
            
            // Class info
            VStack(alignment: .leading, spacing: 8) {
                Text(schoolClass.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let schoolYear = schoolClass.schoolYear, !schoolYear.isEmpty {
                    Text("\(schoolClass.grade) • \(schoolYear)")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.secondary)
                } else {
                    Text(schoolClass.grade)
                        .font(.title3.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 20) {
                    classHeaderBadge(
                        icon: "person.3.fill",
                        text: "\(schoolClass.students.count) \(schoolClass.students.count == 1 ? "Student".localized : "Students".localized)"
                    )

                    classHeaderBadge(
                        icon: "book.fill",
                        text: "\(schoolClass.subjects.count) \(schoolClass.subjects.count == 1 ? "Subject".localized : "Subjects".localized)"
                    )
                }
            }
            
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.12),
            tint: .blue
        )
    }
    
    // MARK: - Quick Actions
    
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localized("Quick Actions"))
                .font(AppTypography.sectionTitle)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
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
                    openLiveWorkspace(.attendance)
                }

                quickActionButton(
                    title: languageManager.localized("Session Mode"),
                    icon: "play.rectangle.fill",
                    color: .red,
                    disabled: schoolClass.students.isEmpty
                ) {
                    openLiveWorkspace(.session)
                }

                quickActionButton(
                    title: languageManager.localized("Live Check-In"),
                    icon: "waveform.path.ecg.rectangle",
                    color: .indigo,
                    disabled: schoolClass.students.isEmpty
                ) {
                    openLiveWorkspace(.checkIn)
                }

                quickActionButton(
                    title: languageManager.localized("Seating Chart"),
                    icon: "chair.fill",
                    color: .indigo,
                    disabled: schoolClass.students.isEmpty
                ) {
                    openLiveWorkspace(.seating)
                }

                quickActionButton(
                    title: languageManager.localized("Assignments"),
                    icon: "list.clipboard",
                    color: .teal,
                    disabled: schoolClass.subjects.flatMap(\.units).isEmpty
                ) {
                    openLiveWorkspace(.assignments)
                }
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force this section to refresh
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.orange.opacity(0.10),
            tint: .orange
        )
    }
    
    func quickActionButton(title: String, icon: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(disabled ? .secondary : color)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(disabled ? .secondary : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .appCardStyle(
                cornerRadius: 12,
                borderColor: (disabled ? Color.gray : color).opacity(0.14),
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: disabled ? nil : color
            )
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(disabled)
    }

    private func openLiveWorkspace(_ section: LiveWorkspaceSection) {
        liveWorkspaceSection = section
    }

    // MARK: - Subjects Section
    
    @ViewBuilder
    var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text(languageManager.localized("Subjects"))
                    .font(AppTypography.sectionTitle)
                
                Spacer()
                
                Button {
                    withAnimation(motion.animation(.quick, interactive: true)) {
                        showingAddSubject = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(languageManager.localized("Add Subject"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(AppPressableButtonStyle())
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
                        .buttonStyle(AppPressableButtonStyle())
                    }
                }
            }
        }
        .id(languageManager.currentLanguage) // 🔄 Force this section to refresh
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.10),
            tint: .blue
        )
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
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.green.opacity(0.10),
            tint: .green
        )
    }
    
    // MARK: - Empty State
    
    func emptyStateView(icon: String, title: String, message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(AppTypography.cardTitle)
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
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(AppPressableButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.blue.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .blue
        )
    }
    
    // MARK: - iPad / iPhone Layout
    
    @ViewBuilder
    var iPadLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlatformSpacing.sectionSpacing) {
                
                // Class info header
                classInfoHeader
                    .appMotionReveal(index: 0)
                
                // Quick actions
                quickActionsSection
                    .appMotionReveal(index: 1)
                
                // Subjects section
                iOSSubjectsSection
                    .appMotionReveal(index: 2)
                
                // Students section
                iOSStudentsSection
                    .appMotionReveal(index: 3)
                
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
                    .font(AppTypography.sectionTitle)
                
                Spacer()
                
                Button {
                    withAnimation(motion.animation(.quick, interactive: true)) {
                        showingAddSubject = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(languageManager.localized("Add Subject"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .buttonStyle(AppPressableButtonStyle())
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
                        .buttonStyle(AppPressableButtonStyle())
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
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.blue.opacity(0.10),
            tint: .blue
        )
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
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.green.opacity(0.10),
            tint: .green
        )
    }

    var studentsHeader: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.green)
            Text(languageManager.localized("Students"))
                .font(AppTypography.sectionTitle)
            
            Spacer()
            
            Button {
                withAnimation(motion.animation(.quick, interactive: true)) {
                    showingAddStudent = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text(languageManager.localized("Add Student"))
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            .buttonStyle(AppPressableButtonStyle())
        }
    }

    func studentsGrid(minimum: CGFloat, maximum: CGFloat, spacing: CGFloat) -> some View {
        let columns = [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing)]
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(orderedStudents.enumerated()), id: \.element.id) { index, student in
                NavigationLink {
                    StudentDetailView(student: student)
                } label: {
                    StudentCardView(student: student, onDelete: {
                        studentToDelete = student
                        showingDeleteStudentAlert = true
                    })
                }
                .buttonStyle(AppPressableButtonStyle())
                .appMotionReveal(index: index)
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
        pickedStudent = StudentRandomizer.pickFairStudent(
            from: sorted,
            scope: StudentRandomizer.generalScope(for: schoolClass)
        )
    }

    func classHeaderBadge(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AppChrome.elevatedBackground)
            )
    }
}
