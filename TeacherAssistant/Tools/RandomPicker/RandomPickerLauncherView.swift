import SwiftUI
import SwiftData

struct RandomPickerLauncherView: View {
    
    let schoolClass: SchoolClass
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var pickedStudent: Student?
    @State private var isSpinning = false
    @State private var isRotationMode = false
    @State private var selectedCategory = "Helper" // Track which category
    @State private var showingAddCategory = false
    @State private var categoryToDelete: String?
    @State private var showingDeleteCategoryAlert = false
    @State private var customCategories: [String] = []
    @State private var pickedStudents: [Student] = []
    @State private var selectedCandidateIDs: Set<String> = []
    @State private var quickPickCount: Int = 3
    @AppStorage("helperRotation") private var helperRotationData = ""
    @AppStorage("guardianRotation") private var guardianRotationData = ""
    @AppStorage("lineLeaderRotation") private var lineLeaderRotationData = ""
    @AppStorage("messengerRotation") private var messengerRotationData = ""
    @AppStorage("customCategoriesData") private var customCategoriesData = "" // Store custom categories
    @AppStorage("customRotationData") private var customRotationData = "" // Store rotation data for custom categories
    
    let defaultCategories = ["Helper", "Guardian", "Line Leader", "Messenger"]
    
    var categories: [String] {
        defaultCategories + customCategories
    }

    var isSelectedCategoryCustom: Bool {
        customCategories.contains(selectedCategory)
    }
    
    let categoryIcons = ["Helper": "star.fill", "Guardian": "shield.fill", "Line Leader": "figure.walk", "Messenger": "envelope.fill"]
    let categoryColors: [String: Color] = ["Helper": .purple, "Guardian": .blue, "Line Leader": .green, "Messenger": .orange]
    
    var currentRotationData: String {
        switch selectedCategory {
        case "Helper": return helperRotationData
        case "Guardian": return guardianRotationData
        case "Line Leader": return lineLeaderRotationData
        case "Messenger": return messengerRotationData
        default:
            // Custom category - stored in customRotationData as "CategoryName:id1,id2,id3|"
            return getCustomRotation(for: selectedCategory)
        }
    }
    
    func updateRotationData(_ newData: String) {
        switch selectedCategory {
        case "Helper": helperRotationData = newData
        case "Guardian": guardianRotationData = newData
        case "Line Leader": lineLeaderRotationData = newData
        case "Messenger": messengerRotationData = newData
        default:
            // Custom category
            updateCustomRotation(for: selectedCategory, data: newData)
        }
    }
    
    func getCustomRotation(for category: String) -> String {
        let entries = customRotationData.split(separator: "|").map { String($0) }
        for entry in entries {
            let parts = entry.split(separator: ":", maxSplits: 1).map { String($0) }
            if parts.count == 2 && parts[0] == category {
                return parts[1]
            }
        }
        return ""
    }
    
    func updateCustomRotation(for category: String, data: String) {
        var entries = customRotationData.split(separator: "|").map { String($0) }.filter { !$0.isEmpty }
        entries.removeAll { $0.hasPrefix("\(category):") }
        if !data.isEmpty {
            entries.append("\(category):\(data)")
        }
        customRotationData = entries.joined(separator: "|")
    }
    
    var usedStudentIDs: Set<String> {
        Set(currentRotationData.split(separator: ",").map { String($0) })
    }

    var quickPickCandidates: [Student] {
        let sortedStudents = schoolClass.students.sorted(by: { $0.sortOrder < $1.sortOrder })
        guard !selectedCandidateIDs.isEmpty else {
            return sortedStudents
        }
        return sortedStudents.filter { selectedCandidateIDs.contains($0.stableIDString) }
    }
    
    var availableStudents: [Student] {
        schoolClass.students
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .filter { !usedStudentIDs.contains($0.stableIDString) }
    }
    
    var usedStudents: [Student] {
        schoolClass.students
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .filter { usedStudentIDs.contains($0.stableIDString) }
    }
    
    var categoryColor: Color {
        categoryColors[selectedCategory] ?? .pink // Custom categories default to pink
    }
    
    var categoryIcon: String {
        categoryIcons[selectedCategory] ?? "flag.fill" // Custom categories default to flag
    }
    
    func localizedCategoryName(_ category: String) -> String {
        category.localized
    }
    
    var localizedSelectedCategory: String {
        languageManager.localized(selectedCategory)
    }
    
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
        .onAppear {
            loadCustomCategories()
            ensureStableIDs()
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCustomCategoryView(onAdd: { newCategory in
                customCategories.append(newCategory)
                saveCustomCategories()
                selectedCategory = newCategory
            })
        }
        .sheet(
            isPresented: Binding(
                get: { pickedStudent != nil },
                set: { if !$0 { pickedStudent = nil } }
            )
        ) {
            if let pickedStudent {
                if isRotationMode {
                    RotationPickResultView(
                        student: pickedStudent,
                        categoryName: selectedCategory,
                        categoryColor: categoryColor,
                        onMarkUsed: {
                            let currentIDs = Set(currentRotationData.split(separator: ",").map { String($0) })
                            var newIDs = currentIDs
                            newIDs.insert(pickedStudent.stableIDString)
                            updateRotationData(newIDs.joined(separator: ","))
                        },
                        onSkip: {
                            // Do nothing - just close the sheet
                        }
                    )
                } else {
                    QuickResultView(student: pickedStudent)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { !pickedStudents.isEmpty },
                set: { if !$0 { pickedStudents = [] } }
            )
        ) {
            MultiQuickResultView(
                students: pickedStudents,
                onPickAgain: {
                    pickedStudents = []
                    pickMultiple(count: quickPickCount)
                }
            )
        }
        .alert("Delete Custom Role?".localized, isPresented: $showingDeleteCategoryAlert) {
            Button("Cancel".localized, role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete".localized, role: .destructive) {
                if let categoryToDelete {
                    deleteCustomCategory(categoryToDelete)
                }
                categoryToDelete = nil
            }
        } message: {
            Text("This will remove the role and its saved rotation history.".localized)
        }
        .macNavigationDepth()
    }

    var content: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                quickDrawSection
                
                // Category Selector
                categorySelector
                
                // Rotation Mode Section
                rotationSection
                
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle("Student Picker".localized)
        #endif
        .appSheetBackground(tint: .orange)
    }
    
    // MARK: - Quick Pick Header
    
    var quickDrawSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        Text("Quick Draws".localized)
                            .font(AppTypography.sectionTitle)
                    }

                    Text("Fast random picks from the full class or a filtered quick-draw pool.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Text(selectedCandidateIDs.isEmpty ? "Full Class".localized : "Custom Pool".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.12))
                    )
            }

            Button {
                isRotationMode = false
                pickRandom()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shuffle.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quick Random Pick".localized)
                            .font(.headline)
                        Text("One instant draw, no rotation tracking".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.orange.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(quickPickCandidates.isEmpty)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Multi-Winner Draw".localized)
                            .font(AppTypography.cardTitle)
                        Text(String(format: languageManager.localized("Pick up to %d unique students"), min(quickPickCount, quickPickCandidates.count)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(quickPickCount)")
                        .font(.title3.monospacedDigit())
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .frame(minWidth: 44)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.orange.opacity(0.1))
                        )
                }

                Stepper(
                    value: $quickPickCount,
                    in: 2...max(2, min(10, schoolClass.students.count))
                ) {
                    Text(String(format: languageManager.localized("Draw %d winners"), quickPickCount))
                        .font(.subheadline)
                }
                .disabled(schoolClass.students.count < 2)

                Button {
                    isRotationMode = false
                    pickMultiple(count: quickPickCount)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.3.sequence.fill")
                        Text(String(format: languageManager.localized("Pick %d Winners"), quickPickCount))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: languageManager.localized("Up to %d"), min(quickPickCount, quickPickCandidates.count)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppChrome.elevatedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(quickPickCandidates.count < 2)
            }
            .padding()
            .appCardStyle(
                cornerRadius: 18,
                borderColor: Color.orange.opacity(0.16),
                tint: .orange
            )

            quickDrawPoolSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Category Selector
    
    var categorySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Role".localized)
                    .font(AppTypography.cardTitle)
                Spacer()
                if isSelectedCategoryCustom {
                    Button {
                        categoryToDelete = selectedCategory
                        showingDeleteCategoryAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete Custom".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showingAddCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom".localized)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.purple.opacity(0.12),
            tint: .purple
        )
        .padding(.horizontal)
    }
    
    func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        let color = categoryColors[category] ?? .purple
        let icon = categoryIcons[category] ?? "star.fill"
        
        return Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? color : .secondary)
                
                Text(category.localized)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if isSelected {
                    Text(String(format: languageManager.localized("%d left"), availableStudents.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .appCardStyle(
                cornerRadius: 12,
                borderColor: (isSelected ? color : AppChrome.separator).opacity(isSelected ? 0.8 : 1),
                lineWidth: isSelected ? 2 : 1,
                shadowOpacity: 0.03,
                shadowRadius: 5,
                shadowY: 2,
                tint: isSelected ? color : nil
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Rotation Section

    var quickDrawPoolSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(.blue)
                        Text("Quick Draw Pool".localized)
                            .font(AppTypography.cardTitle)
                    }
                    Text(poolSummaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !selectedCandidateIDs.isEmpty {
                    Button {
                        selectedCandidateIDs.removeAll()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear Filter".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            WrappingHStack(spacing: 8) {
                ForEach(schoolClass.students.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { student in
                    candidateChip(for: student)
                }
            }
            .padding(14)
            .appCardStyle(
                cornerRadius: 16,
                borderColor: Color.blue.opacity(0.12),
                shadowOpacity: 0.02,
                shadowRadius: 4,
                shadowY: 1,
                tint: .blue
            )
        }
    }
    
    var rotationSection: some View {
        VStack(spacing: 20) {
            // Title
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                Text(String(format: languageManager.localized("%@ Rotation"), localizedSelectedCategory))
                    .font(AppTypography.sectionTitle)
                Spacer()
            }
            .padding(.horizontal)
            
            Text("Fair rotation - everyone gets a turn!".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Stats
            HStack(spacing: 12) {
                statBox(title: "Available".localized, count: availableStudents.count, icon: "checkmark.circle.fill", color: .green)
                statBox(title: "Used".localized, count: usedStudents.count, icon: "clock.fill", color: .orange)
                statBox(title: "Total".localized, count: schoolClass.students.count, icon: "person.3.fill", color: categoryColor)
            }
            .padding(.horizontal)

            if !usedStudents.isEmpty {
                Button {
                    updateRotationData("")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear used students".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            
            // Spinner
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 70))
                    .foregroundColor(categoryColor)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default,
                        value: isSpinning
                    )
            }
            .padding(.vertical)
            
            // Pick or Reset Button
            if availableStudents.isEmpty && !schoolClass.students.isEmpty {
                VStack(spacing: 16) {
                    Text(String(
                        format: languageManager.localized("Everyone has been the %@!"),
                        localizedSelectedCategory.lowercased()
                    ))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        updateRotationData("")
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset & Start Over".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(categoryColor)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            } else {
                Button {
                    isRotationMode = true
                    pickRotation()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(String(format: languageManager.localized("Pick Next %@"), localizedSelectedCategory))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [categoryColor, categoryColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(categoryColor.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: categoryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSpinning || schoolClass.students.isEmpty)
                .padding(.horizontal)
            }
            
            // Student Lists
            if !availableStudents.isEmpty || !usedStudents.isEmpty {
                VStack(spacing: 16) {
                    if !availableStudents.isEmpty {
                        studentList(title: "Available", students: availableStudents, color: .green)
                    }
                    if !usedStudents.isEmpty {
                        studentList(title: "Already Used", students: usedStudents, color: .gray)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .appCardStyle(
            cornerRadius: 16,
            borderColor: categoryColor.opacity(0.12),
            tint: categoryColor
        )
        .padding(.horizontal)
    }

    func candidateChip(for student: Student) -> some View {
        let studentID = student.stableIDString
        let isSelected = selectedCandidateIDs.contains(studentID)

        return Button {
            if isSelected {
                selectedCandidateIDs.remove(studentID)
            } else {
                selectedCandidateIDs.insert(studentID)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                Text(student.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.14) : AppChrome.elevatedBackground)
            .foregroundColor(isSelected ? .blue : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.45) : Color.black.opacity(0.04), lineWidth: 1.2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    func statBox(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text("\(count)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appCardStyle(
            cornerRadius: 10,
            borderColor: color.opacity(0.16),
            shadowOpacity: 0.03,
            shadowRadius: 4,
            shadowY: 1,
            tint: color
        )
    }
    
    func studentList(title: String, students: [Student], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: languageManager.localized("%@ (%d)"), title, students.count))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            WrappingHStack(spacing: 6) {
                ForEach(students.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { student in
                    Text(student.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.15))
                        )
                        .foregroundColor(color == .gray ? .secondary : color)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func pickRandom() {
        guard !quickPickCandidates.isEmpty else { return }
        pickedStudents = []
        isSpinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSpinning = false
            pickedStudent = quickPickCandidates.randomElement()
        }
    }
    
    func pickMultiple(count: Int) {
        guard !quickPickCandidates.isEmpty else { return }
        pickedStudent = nil
        isSpinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSpinning = false
            let winners = Array(quickPickCandidates.shuffled().prefix(max(1, min(count, quickPickCandidates.count))))
            pickedStudents = winners
        }
    }
    
    func pickRotation() {
        guard !availableStudents.isEmpty else { return }
        pickedStudents = []
        isSpinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSpinning = false
            pickedStudent = availableStudents.randomElement()
        }
    }
    
    // MARK: - Custom Category Management
    
    func loadCustomCategories() {
        if !customCategoriesData.isEmpty {
            customCategories = customCategoriesData.split(separator: "|").map { String($0) }
        }
    }
    
    func saveCustomCategories() {
        customCategoriesData = customCategories.joined(separator: "|")
    }

    func deleteCustomCategory(_ category: String) {
        customCategories.removeAll { $0 == category }
        saveCustomCategories()
        updateCustomRotation(for: category, data: "")

        if selectedCategory == category {
            selectedCategory = defaultCategories.first ?? "Helper"
        }
    }

    func ensureStableIDs() {
        var seen: Set<String> = []
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")

        for student in schoolClass.students {
            if student.uuid == zeroUUID {
                student.uuid = UUID()
            }

            var id = student.stableIDString
            if id.isEmpty || seen.contains(id) {
                student.uuid = UUID()
                id = student.stableIDString
            }
            seen.insert(id)
        }
    }

    var poolSummaryText: String {
        if schoolClass.students.isEmpty {
            return "No students in this class yet.".localized
        }

        if selectedCandidateIDs.isEmpty {
            return languageManager.localized("Tap names below to limit quick draws to a smaller group. Role rotations still use the full class.")
        }

        return String(
            format: languageManager.localized("%d selected for quick draws from %d students"),
            quickPickCandidates.count,
            schoolClass.students.count
        )
    }
}

// MARK: - Add Custom Category View

struct AddCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    let onAdd: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.pink)
                    .padding(.top, 40)
                
                Text("Add Custom Role".localized)
                    .font(AppTypography.sectionTitle)
                
                Text("Create your own classroom role".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role Name".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("e.g., Door Holder, Snack Monitor".localized, text: $categoryName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .appFieldStyle(tint: .pink)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .appCardStyle(
                    cornerRadius: 14,
                    borderColor: Color.pink.opacity(0.12),
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2,
                    tint: .pink
                )
                .padding(.horizontal)
                
                if !categoryName.isEmpty {
                    VStack(spacing: 8) {
                        Text("Preview".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .font(.title2)
                                .foregroundColor(.pink)
                            Text(categoryName.localized)
                                .font(AppTypography.cardTitle)
                        }
                        .padding()
                        .appCardStyle(
                            cornerRadius: 10,
                            borderColor: Color.pink.opacity(0.14),
                            shadowOpacity: 0.03,
                            shadowRadius: 4,
                            shadowY: 1,
                            tint: .pink
                        )
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .appSheetBackground(tint: .pink)
            .navigationTitle("New Role".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add".localized) {
                        onAdd(categoryName)
                        dismiss()
                    }
                    .disabled(categoryName.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
}

// MARK: - Quick Result View

struct QuickResultView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: PlatformSpacing.sectionSpacing) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "shuffle.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.orange)
                Text("Random Pick!".localized).font(AppTypography.sectionTitle).foregroundColor(.secondary)
                Text(student.name).font(.system(size: 42, weight: .bold, design: .rounded)).multilineTextAlignment(.center).padding(.horizontal)
                Text("🎉").font(.system(size: 60))
            }
            .padding(24)
            .appCardStyle(
                cornerRadius: 20,
                borderColor: Color.orange.opacity(0.16),
                tint: .orange
            )
            .padding(.horizontal, 24)
            Spacer()
            Button { dismiss() } label: {
                Text("Done".localized).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange)
                    )
            }.buttonStyle(.plain).padding(.horizontal, 24).padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSheetBackground(tint: .orange)
    }
}

struct MultiQuickResultView: View {
    let students: [Student]
    let onPickAgain: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 88))
                        .foregroundColor(.orange)

                    Text("Selected Winners".localized)
                        .font(AppTypography.sectionTitle)

                    Text(String(format: "%d students selected".localized, students.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(Array(students.enumerated()), id: \.element.id) { index, student in
                        HStack(spacing: 14) {
                            Text("\(index + 1)")
                                .font(AppTypography.cardTitle)
                                .foregroundColor(.orange)
                                .frame(width: 28, height: 28)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Circle())

                            Text(student.name)
                                .font(AppTypography.cardTitle)

                            Spacer()
                        }
                        .padding()
                        .appCardStyle(
                            cornerRadius: 14,
                            borderColor: Color.orange.opacity(0.12),
                            shadowOpacity: 0.03,
                            shadowRadius: 5,
                            shadowY: 2,
                            tint: .orange
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onPickAgain()
                    } label: {
                        HStack {
                            Image(systemName: "shuffle")
                            Text("Pick Again".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("Done".localized)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .appCardStyle(
                                cornerRadius: 12,
                                borderColor: AppChrome.separator,
                                shadowOpacity: 0.02,
                                shadowRadius: 4,
                                shadowY: 1
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSheetBackground(tint: .orange)
            .navigationTitle("")
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}
// MARK: - Rotation Result View

struct RotationPickResultView: View {
    let student: Student
    let categoryName: String
    let categoryColor: Color
    let onMarkUsed: () -> Void
    let onSkip: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: PlatformSpacing.sectionSpacing) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "star.circle.fill").font(.system(size: 100)).foregroundColor(categoryColor)
                Text(String(format: "Today's %@".localized, categoryName.localized)).font(AppTypography.cardTitle).foregroundColor(.secondary)
                Text(student.name).font(.system(size: 42, weight: .bold, design: .rounded)).multilineTextAlignment(.center).padding(.horizontal)
                Text("🎉").font(.system(size: 60))
            }
            .padding(24)
            .appCardStyle(
                cornerRadius: 20,
                borderColor: categoryColor.opacity(0.18),
                tint: categoryColor
            )
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 12) {
                Button { 
                    onMarkUsed()
                    dismiss()
                } label: {
                    HStack { Image(systemName: "checkmark.circle.fill"); Text("Mark as Used".localized) }
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(categoryColor)
                        )
                }.buttonStyle(.plain)
                Button { 
                    dismiss()
                    // Call onSkip after a delay to avoid state conflicts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSkip()
                    }
                } label: {
                    HStack { Image(systemName: "xmark.circle"); Text("Skip (Student Absent)".localized) }
                        .font(.subheadline).foregroundColor(categoryColor).frame(maxWidth: .infinity).padding()
                        .appCardStyle(
                            cornerRadius: 12,
                            borderColor: categoryColor.opacity(0.14),
                            shadowOpacity: 0.02,
                            shadowRadius: 4,
                            shadowY: 1,
                            tint: categoryColor
                        )
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24).padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSheetBackground(tint: categoryColor)
    }
}

// MARK: - Wrapping HStack

struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    private func flow(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}
