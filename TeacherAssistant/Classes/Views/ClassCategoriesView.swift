import SwiftUI
import SwiftData

struct ClassCategoriesView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var schoolClass: SchoolClass
    
    @State private var newCategoryName = ""
    @State private var categoryToDelete: AssessmentCategory?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with explanation
                    headerSection
                    
                    // Existing categories
                    if schoolClass.categories.isEmpty {
                        emptyStateView
                    } else {
                        categoriesSection
                    }
                    
                    // Add new category
                    addCategorySection
                    
                }
                .padding()
            }
            .navigationTitle("Assessment Categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Delete Category?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete,
                       let index = schoolClass.categories.firstIndex(where: { $0.id == category.id }) {
                        schoolClass.categories.remove(at: index)
                        
                        // Remove corresponding scores from all students
                        for student in schoolClass.students {
                            if student.scores.indices.contains(index) {
                                student.scores.remove(at: index)
                            }
                        }
                    }
                    categoryToDelete = nil
                }
            } message: {
                Text("This will remove this category and all associated scores from students.".localized)
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Assessment Categories".localized)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Organize grades into categories like Tests, Homework, and Participation".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Empty State
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Categories Yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add categories to organize your grades".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Categories Section
    
    var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("Current Categories".localized)
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(schoolClass.categories.enumerated()), id: \.element.id) { index, category in
                    categoryRow(category: category, index: index)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func categoryRow(category: AssessmentCategory, index: Int) -> some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .cornerRadius(14)
            
            // Category name (editable)
            if let bindingIndex = schoolClass.categories.firstIndex(where: { $0.id == category.id }) {
                TextField("Category name", text: $schoolClass.categories[bindingIndex].title)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            
            // Delete button
            Button {
                categoryToDelete = category
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Add Category Section
    
    var addCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                Text("Add New Category".localized)
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                TextField("e.g., Tests, Homework, Participation", text: $newCategoryName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                
                Button {
                    addCategory()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Category".localized)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newCategoryName.isEmpty ? Color.gray.opacity(0.3) : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(newCategoryName.isEmpty)
            }
            
            // Helpful tip
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Text("Common categories: Tests, Quizzes, Homework, Projects, Participation, Classwork".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let cat = AssessmentCategory(title: trimmedName)
        schoolClass.categories.append(cat)
        
        // Add a score entry for each existing student
        for student in schoolClass.students {
            student.scores.append(AssessmentScore(value: 0))
        }
        
        newCategoryName = ""
    }
}
