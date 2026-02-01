import SwiftUI
import SwiftData

struct RubricTemplateEditorView: View {
    @Bindable var template: RubricTemplate
    @EnvironmentObject var languageManager: LanguageManager
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var showingAddCategory = false
    @State private var showingAddCriterion: RubricCategory?
    @State private var categoryToDelete: RubricCategory?
    @State private var criterionToDelete: RubricCriterion?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with icon
                    headerSection
                    
                    // Template info card
                    templateInfoCard
                    
                    // Categories section
                    categoriesSection
                    
                }
                .padding()
            }
            .navigationTitle("Edit Template".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized) {
                        try? context.save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(template: template)
            }
            .sheet(item: $showingAddCriterion) { category in
                AddCriterionSheet(category: category)
            }
            .confirmationDialog(
                String(format: "Delete %@?".localized, categoryToDelete?.name ?? "category".localized),
                isPresented: Binding(
                    get: { categoryToDelete != nil },
                    set: { if !$0 { categoryToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete".localized, role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                Text("This will delete all criteria in this category.".localized)
            }
            .confirmationDialog(
                "Delete criterion?".localized,
                isPresented: Binding(
                    get: { criterionToDelete != nil },
                    set: { if !$0 { criterionToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete".localized, role: .destructive) {
                    if let criterion = criterionToDelete {
                        deleteCriterion(criterion)
                    }
                }
            } message: {
                Text("Student ratings for this criterion will be preserved.".localized)
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 800)
        #endif
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: subjectIcon(template.subject))
                .font(.system(size: 50))
                .foregroundColor(subjectColor(template.subject))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.subject.localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(subjectColor(template.subject))
                
                Text(template.name.localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(template.gradeLevel.localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(subjectColor(template.subject).opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Template Info Card
    
    var templateInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Information".localized)
                .font(.headline)
            
            VStack(spacing: 12) {
                infoField(label: "Template Name".localized, text: $template.name)
                infoField(label: "Grade Level".localized, text: $template.gradeLevel)
                infoField(label: "Subject".localized, text: $template.subject)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func infoField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(.primary)  // ← ADD THIS
                .padding()
                .background(cardBackground)
                .cornerRadius(8)
        }
    }
    
    // MARK: - Categories Section
    
    var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories & Criteria".localized)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Add Category".localized, systemImage: "folder.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
            
            if template.categories.isEmpty {
                emptyStateView
            } else {
                ForEach(template.categories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { category in
                    categoryCard(category)
                }
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No categories yet".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showingAddCategory = true
            } label: {
                Text("Add First Category".localized)
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Category Card
    
    func categoryCard(_ category: RubricCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.purple)
                
                Text(category.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(category.criteria.count) criteria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    categoryToDelete = category
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Criteria list
            if category.criteria.isEmpty {
                HStack {
                    Text("No criteria yet".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingAddCriterion = category
                    } label: {
                        Text("Add First".localized)
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(category.criteria.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { criterion in
                    criterionRow(criterion)
                }
            }
            
            // Add criterion button
            if !category.criteria.isEmpty {
                Button {
                    showingAddCriterion = category
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Criterion".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
    
    func criterionRow(_ criterion: RubricCriterion) -> some View {
        NavigationLink {
            EditCriterionView(criterion: criterion)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(criterion.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if !criterion.details.isEmpty {
                        Text(criterion.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button {
                    criterionToDelete = criterion
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    func deleteCategory(_ category: RubricCategory) {
        context.delete(category)
        try? context.save()
        categoryToDelete = nil
    }
    
    func deleteCriterion(_ criterion: RubricCriterion) {
        context.delete(criterion)
        try? context.save()
        criterionToDelete = nil
    }
    
    // MARK: - Helpers
    
    func subjectIcon(_ subject: String) -> String {
        switch subject.lowercased() {
        case "english": return "book.fill"
        case "math", "mathematics": return "function"
        case "science": return "atom"
        case "general": return "star.fill"
        default: return "doc.fill"
        }
    }
    
    func subjectColor(_ subject: String) -> Color {
        switch subject.lowercased() {
        case "english": return .blue
        case "math", "mathematics": return .green
        case "science": return .orange
        case "general": return .purple
        default: return .gray
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

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let template: RubricTemplate
    
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var categoryName = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("New Category".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add a new category to organize criteria".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Form field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Category Name".localized, systemImage: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        TextField("e.g., Critical Thinking, Social Skills".localized, text: $categoryName)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    // Preview
                    if !categoryName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.purple)
                                
                                Text(categoryName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Add Category".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add".localized) {
                        addCategory()
                        dismiss()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
    
    func addCategory() {
        let category = RubricCategory(name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines))
        category.template = template
        category.sortOrder = template.categories.count
        context.insert(category)
        try? context.save()
    }
}

// MARK: - Add Criterion Sheet

struct AddCriterionSheet: View {
    let category: RubricCategory
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var criterionName = ""
    @State private var criterionDetails = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("New Criterion".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(format:"Add a new skill to track in %@".localized, category.name))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Criterion Name".localized, systemImage: "text.alignleft")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Critical Thinking Skills".localized, text: $criterionName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Description (Optional)".localized, systemImage: "text.quote")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Analyzes information and draws conclusions".localized, text: $criterionDetails, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // Preview
                        if !criterionName.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preview".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(criterionName)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    
                                    if !criterionDetails.isEmpty {
                                        Text(criterionDetails)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.purple.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Criterion".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add".localized) {
                        addCriterion()
                        dismiss()
                    }
                    .disabled(criterionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
    }
    
    func addCriterion() {
        let criterion = RubricCriterion(
            name: criterionName.trimmingCharacters(in: .whitespacesAndNewlines),
            details: criterionDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        criterion.category = category
        criterion.sortOrder = category.criteria.count
        context.insert(criterion)
        try? context.save()
    }
}

// MARK: - Edit Criterion View

struct EditCriterionView: View {
    @Bindable var criterion: RubricCriterion
    @EnvironmentObject var languageManager: LanguageManager
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Section("Criterion Details".localized) {
                TextField("Criterion Name".localized, text: $criterion.name)
                TextField("Description".localized, text: $criterion.details, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle("Edit Criterion".localized)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done".localized) {
                    try? context.save()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Create New Template Sheet

struct CreateNewTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var templateName = ""
    @State private var gradeLevel = ""
    @State private var subject = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("Create New Template".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Build a custom rubric from scratch".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Template Name".localized, systemImage: "doc.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Advanced Writing Skills".localized, text: $templateName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Grade Level".localized, systemImage: "graduationcap.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., Years 7-9".localized, text: $gradeLevel)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Subject".localized, systemImage: "book.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("e.g., English, Math, Science".localized, text: $subject)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Template".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create".localized) {
                        createTemplate()
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || gradeLevel.isEmpty || subject.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
    }
    
    func createTemplate() {
        let template = RubricTemplate(
            name: templateName,
            gradeLevel: gradeLevel,
            subject: subject
        )
        context.insert(template)
        try? context.save()
    }
}
