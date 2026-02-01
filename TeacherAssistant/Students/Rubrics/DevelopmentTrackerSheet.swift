import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct DevelopmentTrackerSheet: View {
    let student: Student
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var allTemplates: [RubricTemplate]
    @Query private var allScores: [DevelopmentScore]
    
    @State private var selectedTemplate: RubricTemplate?
    @State private var ratings: [UUID: Int] = [:] // criterion ID -> rating
    @State private var notes: [UUID: String] = [:] // criterion ID -> notes
    
    var availableTemplates: [RubricTemplate] {
        // Filter templates by student's grade level if available
        // For now, show all templates
        allTemplates.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Student info header
                    headerSection
                    
                    // Template selector
                    if availableTemplates.isEmpty {
                        emptyTemplatesView
                    } else {
                        templateSelector
                        
                        // Rating sections
                        if let template = selectedTemplate {
                            ForEach(template.categories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { category in
                                categorySection(category)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Development Tracking")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRatings()
                        dismiss()
                    }
                    .disabled(ratings.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 700)
        #endif
        .onAppear {
            loadExistingRatings()
            if selectedTemplate == nil {
                selectedTemplate = availableTemplates.first
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(student.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let className = student.schoolClass?.name {
                    Text(className)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Rate development criteria below".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Template Selector
    
    var templateSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rubric Template".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Picker("Template", selection: $selectedTemplate) {
                ForEach(availableTemplates, id: \.id) { template in
                    Text(template.name).tag(template as RubricTemplate?)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
        }
    }
    
    func categorySection(_ category: RubricCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.purple)
                
                Text(category.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            ForEach(category.criteria.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { criterion in
                criterionCard(criterion)
            }
        }
        .padding(16)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(16)
    }
    
    // MARK: - Criterion Card

    func criterionCard(_ criterion: RubricCriterion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Criterion name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)  // ← Better contrast
                
                if !criterion.details.isEmpty {
                    Text(criterion.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Star rating selector
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        ratings[criterion.id] = rating
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: (ratings[criterion.id] ?? 0) >= rating ? "star.fill" : "star")
                                .font(.system(size: 28))  // ← Bigger stars
                                .foregroundColor((ratings[criterion.id] ?? 0) >= rating ? ratingColor(rating) : .gray.opacity(0.3))
                            
                            Text("\(rating)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)  // ← Better contrast
                        }
                        .frame(width: 44, height: 44)  // ← Bigger tap target
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            
            // Current rating label
            if let currentRating = ratings[criterion.id] {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ratingColor(currentRating))
                    
                    Text(ratingLabel(currentRating))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ratingColor(currentRating))
                }
                .padding(.vertical, 4)
            } else {
                Text("Tap a star to rate".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 4)
            }
            
            // Notes field
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (Optional)".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Add notes about this skill...", text: Binding(
                    get: { notes[criterion.id] ?? "" },
                    set: { notes[criterion.id] = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(2...4)
            }
        }
        .padding(16)
        .background(cardBackground)  // ← Platform-appropriate background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Empty Templates View
    
    var emptyTemplatesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Rubric Templates".localized)
                .font(.headline)
            
            Text("Please create rubric templates first".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Helpers
    
    func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
    
    func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "Needs Significant Support"
        case 2: return "Beginning to Develop"
        case 3: return "Developing"
        case 4: return "Proficient"
        case 5: return "Mastering / Exceeding"
        default: return "Not Rated"
        }
    }
    
    func loadExistingRatings() {
        let studentScores = allScores.filter { $0.student?.id == student.id }
        
        // Get most recent rating for each criterion
        var latestRatings: [UUID: DevelopmentScore] = [:]
        
        for score in studentScores {
            guard let criterionID = score.criterion?.id else { continue }
            
            if let existing = latestRatings[criterionID] {
                if score.date > existing.date {
                    latestRatings[criterionID] = score
                }
            } else {
                latestRatings[criterionID] = score
            }
        }
        
        // Pre-fill ratings
        for (criterionID, score) in latestRatings {
            ratings[criterionID] = score.rating
            if !score.notes.isEmpty {
                notes[criterionID] = score.notes
            }
        }
    }
    
    func saveRatings() {
        let saveDate = Date()
        
        for (criterionID, rating) in ratings {
            // Find the criterion
            guard let criterion = findCriterion(by: criterionID) else { continue }
            
            let note = notes[criterionID] ?? ""
            
            let score = DevelopmentScore(
                student: student,
                criterion: criterion,
                rating: rating,
                notes: note,
                date: saveDate
            )
            
            context.insert(score)
        }
        
        try? context.save()
    }
    
    func findCriterion(by id: UUID) -> RubricCriterion? {
        for template in allTemplates {
            for category in template.categories {
                if let criterion = category.criteria.first(where: { $0.id == id }) {
                    return criterion
                }
            }
        }
        return nil
    }
    var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
