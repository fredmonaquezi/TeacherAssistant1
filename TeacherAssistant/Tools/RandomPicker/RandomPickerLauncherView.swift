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
    @State private var customCategories: [String] = []
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
    
    var availableStudents: [Student] {
        schoolClass.students.filter { !usedStudentIDs.contains(String(describing: $0.id)) }
    }
    
    var usedStudents: [Student] {
        schoolClass.students.filter { usedStudentIDs.contains(String(describing: $0.id)) }
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Quick Pick Header (clickable)
                    quickPickHeader
                    
                    Divider().padding(.horizontal)
                    
                    // Category Selector
                    categorySelector
                    
                    // Rotation Mode Section
                    rotationSection
                    
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Student Picker".localized)
        }
        .onAppear {
            loadCustomCategories()
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
                            newIDs.insert(String(describing: pickedStudent.id))
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
    }
    
    // MARK: - Quick Pick Header
    
    var quickPickHeader: some View {
        Button {
            isRotationMode = false
            pickRandom()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "shuffle.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Quick Random Pick".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                    Text("Tap here for instant random pick".localized)
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .fontWeight(.semibold)
                
                Text("(any student, no rotation tracking)".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.4), lineWidth: 2)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .disabled(schoolClass.students.isEmpty)
    }
    
    // MARK: - Category Selector
    
    var categorySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Role".localized)
                    .font(.headline)
                Spacer()
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
                    Text("\(availableStudents.count) left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isSelected ? color.opacity(0.15) : Color.gray.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Rotation Section
    
    var rotationSection: some View {
        VStack(spacing: 20) {
            // Title
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                Text("\(selectedCategory) Rotation")
                    .font(.headline)
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
                    Text("🎉 Everyone has been the \(selectedCategory.lowercased())!")
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
                        .background(categoryColor)
                        .cornerRadius(12)
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
                        Text("Pick Next \(selectedCategory)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
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
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    func statBox(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text("\(count)").font(.system(size: 24, weight: .bold)).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    func studentList(title: String, students: [Student], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(students.count))")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            WrappingHStack(spacing: 6) {
                ForEach(students.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { student in
                    Text(student.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.15))
                        .foregroundColor(color == .gray ? .secondary : color)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    func pickRandom() {
        guard !schoolClass.students.isEmpty else { return }
        isSpinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSpinning = false
            pickedStudent = schoolClass.students.randomElement()
        }
    }
    
    func pickRotation() {
        guard !availableStudents.isEmpty else { return }
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
}

// MARK: - Add Custom Category View

struct AddCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    let onAdd: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.pink)
                    .padding(.top, 40)
                
                Text("Add Custom Role".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(10)
                }
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
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.pink.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
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
        VStack(spacing: 40) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "shuffle.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.orange)
                Text("Random Pick!".localized).font(.title2).foregroundColor(.secondary)
                Text(student.name).font(.system(size: 42, weight: .bold)).multilineTextAlignment(.center).padding(.horizontal)
                Text("🎉").font(.system(size: 60))
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done".localized).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(Color.orange).cornerRadius(12)
            }.buttonStyle(.plain).padding(.horizontal, 32).padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.05))
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
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "star.circle.fill").font(.system(size: 100)).foregroundColor(categoryColor)
                Text(String(format: "Today's %@".localized, categoryName.localized)).font(.title3).foregroundColor(.secondary)
                Text(student.name).font(.system(size: 42, weight: .bold)).multilineTextAlignment(.center).padding(.horizontal)
                Text("🎉").font(.system(size: 60))
            }
            Spacer()
            VStack(spacing: 12) {
                Button { 
                    onMarkUsed()
                    dismiss()
                } label: {
                    HStack { Image(systemName: "checkmark.circle.fill"); Text("Mark as Used".localized) }
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                        .background(categoryColor).cornerRadius(12)
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
                        .background(categoryColor.opacity(0.1)).cornerRadius(12)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 32).padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(categoryColor.opacity(0.05))
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

