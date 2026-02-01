import SwiftUI
import SwiftData

struct RubricTemplateManagerView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    @Query(sort: \RubricTemplate.name) private var allTemplates: [RubricTemplate]
    
    @State private var selectedTemplate: RubricTemplate?
    @State private var showingTemplateEditor = false
    @State private var showingCreateNew = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    headerSection
                    
                    // Templates by grade level
                    ForEach(gradeLevels, id: \.self) { gradeLevel in
                        templateSection(for: gradeLevel)
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Rubric Templates".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateNew = true
                    } label: {
                        Label("Create New".localized, systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                RubricTemplateEditorView(template: template)
            }
            .sheet(isPresented: $showingCreateNew) {
                CreateNewTemplateSheet()
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Rubric Template Library".localized)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Browse, customize, and create development tracking templates".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Template Section
    
    func templateSection(for gradeLevel: String) -> some View {
        let templates = allTemplates.filter { $0.gradeLevel == gradeLevel }
        
        guard !templates.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.purple)
                    
                    Text(gradeLevel.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                ], spacing: 16) {
                    ForEach(templates, id: \.id) { template in
                        templateCard(template)
                    }
                }
                .padding(.horizontal)
            }
        )
    }
    
    // MARK: - Template Card
    
    func templateCard(_ template: RubricTemplate) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: subjectIcon(template.subject))
                        .font(.title)
                        .foregroundColor(subjectColor(template.subject))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.subject.localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(subjectColor(template.subject))
                    
                    Text(template.name.localized)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    statItem(
                        icon: "folder.fill",
                        value: "\(template.categories.count)",
                        label: "Categories".localized
                    )
                    
                    statItem(
                        icon: "list.bullet",
                        value: "\(totalCriteria(in: template))",
                        label: "Criteria".localized
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helpers
    
    var gradeLevels: [String] {
        ["Years 1-3", "Years 4-6", "Years 7-9", "Years 10-12"]
    }
    
    func totalCriteria(in template: RubricTemplate) -> Int {
        template.categories.reduce(0) { $0 + $1.criteria.count }
    }
    
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
}
