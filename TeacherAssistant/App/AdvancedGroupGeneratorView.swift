import SwiftUI
import SwiftData

struct AdvancedGroupGeneratorView: View {
    
    @EnvironmentObject var languageManager: LanguageManager
    
    let schoolClass: SchoolClass
    
    @State private var groupSize: Int = 4
    @State private var groups: [[Student]] = []
    
    // Advanced options
    @State private var balanceGender: Bool = false
    @State private var balanceAbility: Bool = false
    @State private var pairSupportPartners: Bool = false
    @State private var respectSeparations: Bool = true
    @State private var showingSettings: Bool = true // Start expanded so users can see the options
    @State private var showingSeparationEditor: Bool = false
    @State private var generationNotice: String?
    @State private var generationNoticeIsWarning: Bool = false
    
    var body: some View {
        Group {
            #if os(macOS)
            content
            #else
            NavigationStack {
                content
            }
            #endif
        }
        .sheet(isPresented: $showingSeparationEditor) {
            StudentSeparationEditor(schoolClass: schoolClass)
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 600)
        #endif
        .macNavigationDepth()
    }

    var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                #if os(macOS)
                groupActionsRow
                #endif
                
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
        #if !os(macOS)
        .navigationTitle(languageManager.localized("Group Generator"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSeparationEditor = true
                } label: {
                    Label(languageManager.localized("Separations"), systemImage: "person.2.slash")
                }
            }
        }
        #endif
    }

    #if os(macOS)
    var groupActionsRow: some View {
        HStack {
            Button {
                showingSeparationEditor = true
            } label: {
                Label(languageManager.localized("Separations"), systemImage: "person.2.slash")
            }

            Spacer()
        }
        .padding(.horizontal)
    }
    #endif
    
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
                    
                    Text(String(
                        format: languageManager.localized("This will create approximately %d groups"),
                        expectedGroupCount
                    ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let generationNotice {
                HStack(spacing: 8) {
                    Image(systemName: generationNoticeIsWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(generationNoticeIsWarning ? .orange : .green)
                    Text(generationNotice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

                    // Pair support partners toggle
                    Toggle(isOn: $pairSupportPartners) {
                        HStack {
                            Image(systemName: "person.2.wave.2.fill")
                                .foregroundColor(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pair Support Partners".localized)
                                    .font(.subheadline)
                                Text("Try to place students needing help with supportive peers".localized)
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
                    if pairSupportPartners {
                        Badge(icon: "person.2.wave.2.fill", color: .teal)
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
        let classStudents = schoolClass.students.sorted { $0.sortOrder < $1.sortOrder }
        guard !classStudents.isEmpty else {
            groups = []
            generationNotice = nil
            generationNoticeIsWarning = false
            return
        }

        var options = GroupingEngineOptions(
            balanceGender: balanceGender,
            balanceAbility: balanceAbility,
            pairSupportPartners: pairSupportPartners,
            respectSeparations: respectSeparations
        )
        let usingAdvancedRules = balanceGender || balanceAbility || pairSupportPartners || respectSeparations
        options.maxAttempts = usingAdvancedRules ? 32 : 1

        let studentsByStableID = Dictionary(uniqueKeysWithValues: classStudents.map { ($0.stableIDString, $0) })
        let stableIDByLegacyPersistentID = Dictionary(uniqueKeysWithValues: classStudents.map { (String(describing: $0.id), $0.stableIDString) })
        let knownStableIDs = Set(studentsByStableID.keys)

        let engineStudents = classStudents.map { student in
            let resolvedSeparationIDs = student.separationTokens.compactMap { token -> String? in
                if knownStableIDs.contains(token) { return token }
                return stableIDByLegacyPersistentID[token]
            }
            return GroupingEngineStudent(
                id: student.stableIDString,
                name: student.name,
                gender: student.gender,
                needsHelp: student.needsHelp,
                isSupportPartner: student.isSupportPartnerCandidate,
                separationIDs: Array(Set(resolvedSeparationIDs))
            )
        }
        let generationResult = GroupingEngine.generateGroups(
            students: engineStudents,
            preferredGroupSize: groupSize,
            options: options
        )

        groups = generationResult.groups.map { group in
            group.compactMap { studentsByStableID[$0.id] }
        }.filter { !$0.isEmpty }

        let notice = engineNotice(for: generationResult)
        generationNotice = notice.text
        generationNoticeIsWarning = notice.isWarning
    }

    func engineNotice(for result: GroupingEngineResult) -> (text: String, isWarning: Bool) {
        if groups.isEmpty {
            return (languageManager.localized("No groups were generated."), true)
        }

        switch result.strategy {
        case .strict:
            return (
                String(
                    format: languageManager.localized("Generated %d balanced groups."),
                    groups.count
                ),
                false
            )
        case .relaxedConstraints:
            if result.separationConflicts > 0 {
                return (
                    String(
                        format: languageManager.localized("Used fallback strategy: constraints were relaxed and %d separation conflict(s) remain."),
                        result.separationConflicts
                    ),
                    true
                )
            }
            return (
                languageManager.localized("Used fallback strategy: regenerated with relaxed ordering to satisfy constraints."),
                false
            )
        case .forcedPlacement:
            return (
                String(
                    format: languageManager.localized("Used emergency fallback placement. %d separation conflict(s) remain."),
                    result.separationConflicts
                ),
                true
            )
        case .failed:
            return (
                String(
                    format: languageManager.localized("Could not satisfy all rules. %d student(s) could not be assigned."),
                    result.unassignedCount
                ),
                true
            )
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
    @EnvironmentObject var languageManager: LanguageManager
    
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
            Text(String(format: languageManager.localized("%@ should NOT be grouped with:"), student.name))
        }
        .onAppear {
            loadSeparations()
        }
    }
    
    var otherStudents: [Student] {
        allStudents.filter { $0.id != student.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func loadSeparations() {
        selectedStudents = Set(
            otherStudents
                .filter { student.hasSeparation(with: $0) }
                .map { $0.id }
        )
    }
    
    func updateSeparationList() {
        let selectedUUIDs = allStudents
            .filter { selectedStudents.contains($0.id) }
            .map(\.stableIDString)
            .sorted()
        student.separationList = selectedUUIDs.joined(separator: ",")
    }
}

// MARK: - Modern Group Card (reuse existing)

struct ModernGroupCard: View {
    let index: Int
    let students: [Student]
    let totalGroups: Int
    
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(String(format: languageManager.localized("Group %d"), index + 1))
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
