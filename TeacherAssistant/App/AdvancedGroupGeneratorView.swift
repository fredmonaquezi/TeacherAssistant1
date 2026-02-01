import SwiftUI
import SwiftData

struct AdvancedGroupGeneratorView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    let schoolClass: SchoolClass
    
    @State private var groupSize: Int = 4
    @State private var groups: [[Student]] = []
    
    // Advanced options
    @State private var balanceGender: Bool = false
    @State private var balanceAbility: Bool = false
    @State private var respectSeparations: Bool = true
    @State private var showingSettings: Bool = true // Start expanded so users can see the options
    @State private var showingSeparationEditor: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Card
                    headerCard
                    
                    // Controls Card
                    controlsCard
                    
                    // Advanced Options
                    advancedOptionsCard
                    
                    // Results Section
                    if groups.isEmpty {
                        emptyStateView
                    } else {
                        resultsSection
                    }
                    
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(languageManager.localized("Group Generator"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingSeparationEditor = true
                    } label: {
                        Label(languageManager.localized("Separations"), systemImage: "person.2.slash")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Done")) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showingSeparationEditor) {
            StudentSeparationEditor(schoolClass: schoolClass)
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 600)
        #endif
    }
    
    // MARK: - Header Card
    
    var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            
            Text("Smart Group Generator".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create balanced student groups with advanced options".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Class info
            HStack(spacing: 20) {
                infoItem(icon: "person.2.fill", label: languageManager.localized("Students"), value: "\(schoolClass.students.count)")
                infoItem(icon: "rectangle.3.group.fill", label: languageManager.localized("Groups"), value: groups.isEmpty ? "—" : "\(groups.count)")
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func infoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Controls Card
    
    var controlsCard: some View {
        VStack(spacing: 16) {
            Text("Group Settings".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Group size control
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Students per group".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(groupSize) \(groupSize == 1 ? languageManager.localized("student") : languageManager.localized("students"))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        if groupSize > 2 {
                            groupSize -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(groupSize > 2 ? .purple : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupSize <= 2)
                    
                    Button {
                        if groupSize < 10 {
                            groupSize += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(groupSize < 10 ? .purple : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupSize >= 10)
                }
            }
            
            Divider()
            
            // Expected groups info
            if !schoolClass.students.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("This will create approximately \(expectedGroupCount) groups".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Generate button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    generateGroups()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(groups.isEmpty ? "Generate Smart Groups".localized : "Regenerate Groups".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var expectedGroupCount: Int {
        let students = schoolClass.students.count
        return (students + groupSize - 1) / groupSize
    }
    
    // MARK: - Advanced Options Card
    
    var advancedOptionsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Advanced Options".localized)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingSettings.toggle()
                    }
                } label: {
                    Image(systemName: showingSettings ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            if showingSettings {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Balance gender toggle
                    Toggle(isOn: $balanceGender) {
                        HStack {
                            Image(systemName: "person.2.badge.gearshape")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Balance Gender".localized)
                                    .font(.subheadline)
                                Text("Try to distribute genders evenly across groups".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Balance ability toggle
                    Toggle(isOn: $balanceAbility) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Balance Ability Levels".localized)
                                    .font(.subheadline)
                                Text("Mix students who need help with others".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Respect separations toggle
                    Toggle(isOn: $respectSeparations) {
                        HStack {
                            Image(systemName: "person.2.slash")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Respect Separation Rules".localized)
                                    .font(.subheadline)
                                Text("Avoid pairing students in separation list".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No groups yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Configure your settings and click 'Generate Smart Groups'".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Results Section
    
    var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Generated Groups".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Summary badges
                HStack(spacing: 8) {
                    if balanceGender {
                        Badge(icon: "person.2.badge.gearshape", color: .blue)
                    }
                    if balanceAbility {
                        Badge(icon: "chart.bar", color: .green)
                    }
                    if respectSeparations {
                        Badge(icon: "person.2.slash", color: .red)
                    }
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
            ], spacing: 16) {
                ForEach(groups.indices, id: \.self) { index in
                    ModernGroupCard(
                        index: index,
                        students: groups[index],
                        totalGroups: groups.count
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Logic
    
    func generateGroups() {
        var availableStudents = schoolClass.students
        groups = []
        
        // If balancing ability, sort students by ability level first
        if balanceAbility {
            availableStudents.sort { s1, s2 in
                (s1.needsHelp ? 0 : 1) < (s2.needsHelp ? 0 : 1)
            }
        } else {
            availableStudents.shuffle()
        }
        
        // Get separation pairs
        let separations = respectSeparations ? getSeparationPairs() : []
        
        // Create groups
        while !availableStudents.isEmpty {
            var group: [Student] = []
            var attempts = 0
            let maxAttempts = 100
            
            while group.count < groupSize && !availableStudents.isEmpty && attempts < maxAttempts {
                attempts += 1
                
                // If this is the first student in the group, just pick one
                if group.isEmpty {
                    if let student = pickBestStudent(from: availableStudents, for: group, separations: separations) {
                        group.append(student)
                        availableStudents.removeAll { $0.id == student.id }
                    } else if let fallback = availableStudents.first {
                        group.append(fallback)
                        availableStudents.removeAll { $0.id == fallback.id }
                    }
                } else {
                    // Pick next student considering all constraints
                    if let student = pickBestStudent(from: availableStudents, for: group, separations: separations) {
                        group.append(student)
                        availableStudents.removeAll { $0.id == student.id }
                    } else {
                        break
                    }
                }
            }
            
            if !group.isEmpty {
                groups.append(group)
            }
        }
    }
    
    func pickBestStudent(from students: [Student], for group: [Student], separations: Set<StudentPair>) -> Student? {
        var candidates = students
        
        // Filter out separated students
        if respectSeparations && !group.isEmpty {
            candidates = candidates.filter { candidate in
                !group.contains { existing in
                    separations.contains(StudentPair(student1: existing.id, student2: candidate.id))
                }
            }
        }
        
        if candidates.isEmpty {
            return nil
        }
        
        // If balancing gender, try to pick different gender
        if balanceGender && !group.isEmpty {
            let gendersInGroup = Set(group.map { $0.genderEnum })
            let differentGender = candidates.first { !gendersInGroup.contains($0.genderEnum) }
            if let student = differentGender {
                return student
            }
        }
        
        // If balancing ability, alternate
        if balanceAbility && !group.isEmpty {
            let hasNeedHelp = group.contains { $0.needsHelp }
            if hasNeedHelp {
                // Pick someone who doesn't need help
                if let student = candidates.first(where: { !$0.needsHelp }) {
                    return student
                }
            } else {
                // Pick someone who needs help
                if let student = candidates.first(where: { $0.needsHelp }) {
                    return student
                }
            }
        }
        
        // Otherwise, return first available
        return candidates.first
    }
    
    func getSeparationPairs() -> Set<StudentPair> {
        var pairs = Set<StudentPair>()
        
        for student in schoolClass.students {
            let separatedIDStrings = student.separationList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            for idString in separatedIDStrings {
                // Find student with matching ID string
                if let separatedStudent = schoolClass.students.first(where: { String(describing: $0.id) == idString }) {
                    pairs.insert(StudentPair(student1: student.id, student2: separatedStudent.id))
                }
            }
        }
        
        return pairs
    }
    var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

// MARK: - Helper Types

struct StudentPair: Hashable {
    let student1: PersistentIdentifier
    let student2: PersistentIdentifier
    
    init(student1: PersistentIdentifier, student2: PersistentIdentifier) {
        // Always store in sorted order so (A,B) == (B,A)
        let id1String = String(describing: student1)
        let id2String = String(describing: student2)
        if id1String < id2String {
            self.student1 = student1
            self.student2 = student2
        } else {
            self.student1 = student2
            self.student2 = student1
        }
    }
}

struct Badge: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.caption)
            .foregroundColor(.white)
            .padding(6)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - Separation Editor

struct StudentSeparationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var schoolClass: SchoolClass
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(schoolClass.students.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { student in
                    StudentSeparationRow(student: student, allStudents: schoolClass.students)
                }
            }
            .navigationTitle("Student Separations".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized) {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}

struct StudentSeparationRow: View {
    @Bindable var student: Student
    let allStudents: [Student]
    
    @State private var selectedStudents: Set<PersistentIdentifier> = []
    
    var body: some View {
        Section {
            ForEach(otherStudents, id: \.id) { otherStudent in
                Toggle(isOn: Binding(
                    get: { selectedStudents.contains(otherStudent.id) },
                    set: { isOn in
                        if isOn {
                            selectedStudents.insert(otherStudent.id)
                        } else {
                            selectedStudents.remove(otherStudent.id)
                        }
                        updateSeparationList()
                    }
                )) {
                    Text(otherStudent.name)
                }
            }
        } header: {
            Text("\(student.name) should NOT be grouped with:".localized)
        }
        .onAppear {
            loadSeparations()
        }
    }
    
    var otherStudents: [Student] {
        allStudents.filter { $0.id != student.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func loadSeparations() {
        let idStrings = student.separationList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        selectedStudents = Set(allStudents.filter { student in
            idStrings.contains(String(describing: student.id))
        }.map { $0.id })
    }
    
    func updateSeparationList() {
        student.separationList = selectedStudents.map { String(describing: $0) }.joined(separator: ",")
    }
}

// MARK: - Modern Group Card (reuse existing)

struct ModernGroupCard: View {
    let index: Int
    let students: [Student]
    let totalGroups: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Group \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(students.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding()
            .background(gradientForGroup(index))
            
            // Students list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(students, id: \.id) { student in
                    HStack(spacing: 8) {
                        Image(systemName: genderIcon(student.genderEnum))
                            .foregroundColor(genderColor(student.genderEnum))
                            .font(.caption)
                        
                        Text(student.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if student.needsHelp {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    func gradientForGroup(_ index: Int) -> LinearGradient {
        let colors: [(Color, Color)] = [
            (.purple, .blue),
            (.blue, .cyan),
            (.green, .mint),
            (.orange, .yellow),
            (.pink, .purple),
            (.red, .orange)
        ]
        
        let colorPair = colors[index % colors.count]
        return LinearGradient(
            colors: [colorPair.0, colorPair.1],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    func genderIcon(_ gender: StudentGender) -> String {
        switch gender {
        case .male: return "person.fill"
        case .female: return "person.fill"
        case .nonBinary: return "person.fill"
        case .preferNotToSay: return "person.fill"
        }
    }
    
    func genderColor(_ gender: StudentGender) -> Color {
        switch gender {
        case .male: return .blue
        case .female: return .pink
        case .nonBinary: return .purple
        case .preferNotToSay: return .gray
        }
    }
    var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
