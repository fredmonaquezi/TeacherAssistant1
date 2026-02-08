import SwiftUI
import SwiftData

struct RubricTemplateManagerView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    @Query(sort: \RubricTemplate.name) private var allTemplates: [RubricTemplate]
    
    @State private var selectedTemplate: RubricTemplate?
    @State private var showingTemplateEditor = false
    @State private var showingCreateNew = false
    @State private var templateToDelete: RubricTemplate?
    @State private var showingDeleteAlert = false
    
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
    }

    var content: some View {
        ZStack(alignment: .bottomTrailing) {
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

            #if os(macOS)
            Button {
                showingCreateNew = true
            } label: {
                Label("Create New".localized, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(24)
            #endif
        }
        #if !os(macOS)
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
        #endif
        .sheet(item: $selectedTemplate) { template in
            RubricTemplateEditorView(template: template)
        }
        .sheet(isPresented: $showingCreateNew) {
            CreateNewTemplateSheet()
        }
        .alert(languageManager.localized("Delete Template?"), isPresented: $showingDeleteAlert) {
            Button(languageManager.localized("Cancel"), role: .cancel) {
                templateToDelete = nil
            }
            Button(languageManager.localized("Delete"), role: .destructive) {
                if let templateToDelete {
                    context.delete(templateToDelete)
                    try? context.save()
                }
                templateToDelete = nil
            }
        } message: {
            if let templateToDelete {
                Text(String(
                    format: languageManager.localized("Are you sure you want to delete \"%@\"?"),
                    templateToDelete.name
                ))
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
        let templates = allTemplates.filter { normalized($0.gradeLevel) == normalized(gradeLevel) }
        
        guard !templates.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.purple)
                    
                    Text(displayText(for: gradeLevel))
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
                    
                    Button {
                        templateToDelete = template
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help(languageManager.localized("Delete"))
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayText(for: template.subject))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(subjectColor(template.subject))
                    
                    Text(displayText(for: template.name))
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
        .contextMenu {
            Button(role: .destructive) {
                templateToDelete = template
                showingDeleteAlert = true
            } label: {
                Label(languageManager.localized("Delete"), systemImage: "trash")
            }
        }
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
        let predefined = ["Years 1-3", "Years 4-6", "Years 7-9", "Years 10-12"]
        let templateLevels = allTemplates.map { normalized($0.gradeLevel) }.filter { !$0.isEmpty }
        
        var seen = Set<String>()
        var ordered: [String] = []
        
        for level in predefined {
            if seen.insert(level).inserted {
                ordered.append(level)
            }
        }
        
        for level in templateLevels {
            if seen.insert(level).inserted {
                ordered.append(level)
            }
        }
        
        return ordered
    }
    
    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func totalCriteria(in template: RubricTemplate) -> Int {
        template.categories.reduce(0) { $0 + $1.criteria.count }
    }
    
    func displayText(for value: String) -> String {
        let localized = languageManager.localized(value)
        if localized != value {
            return localized
        }
        return RubricLocalization.localized(value, languageCode: languageManager.currentLanguage.rawValue)
    }
    
    func subjectIcon(_ subject: String) -> String {
        switch normalizeSubject(subject) {
        case "english": return "book.fill"
        case "math": return "function"
        case "science": return "atom"
        case "general": return "star.fill"
        default: return "doc.fill"
        }
    }
    
    func subjectColor(_ subject: String) -> Color {
        switch normalizeSubject(subject) {
        case "english": return .blue
        case "math": return .green
        case "science": return .orange
        case "general": return .purple
        default: return .gray
        }
    }
    
    func normalizeSubject(_ subject: String) -> String {
        let normalized = subject
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        switch normalized {
        case "english", "inglês", "ingles": return "english"
        case "math", "mathematics", "matemática", "matematica": return "math"
        case "science", "ciência", "ciencia", "ciências", "ciencias": return "science"
        case "general", "geral": return "general"
        default: return normalized
        }
    }
}
