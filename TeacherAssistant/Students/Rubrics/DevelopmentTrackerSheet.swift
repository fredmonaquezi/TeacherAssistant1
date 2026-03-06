import SwiftUI
import SwiftData

struct DevelopmentTrackerSheet: View {
    let student: Student
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    @Query private var allTemplates: [RubricTemplate]
    @Query private var allScores: [DevelopmentScore]
    
    @State private var selectedTemplate: RubricTemplate?
    @State private var ratings: [UUID: Int] = [:] // criterion ID -> rating
    @State private var notes: [UUID: String] = [:] // criterion ID -> notes
    @State private var selectedYearFilter = DevelopmentTrackerSheet.allYearsFilterToken
    @State private var selectedCriteriaFilter = DevelopmentTrackerSheet.allCriteriaFilterToken

    private static let allYearsFilterToken = "__all_years__"
    private static let allCriteriaFilterToken = "__all_criteria__"
    
    var availableTemplates: [RubricTemplate] {
        // Filter templates by student's grade level if available
        // For now, show all templates
        allTemplates.sorted { $0.name < $1.name }
    }

    var filteredTemplates: [RubricTemplate] {
        availableTemplates.filter { template in
            let matchesYear =
                selectedYearFilter == Self.allYearsFilterToken ||
                normalized(template.gradeLevel) == normalized(selectedYearFilter)
            let matchesCriteria =
                selectedCriteriaFilter == Self.allCriteriaFilterToken ||
                normalized(template.subject) == normalized(selectedCriteriaFilter)

            return matchesYear && matchesCriteria
        }
    }

    var yearFilterOptions: [String] {
        let predefined = ["Years 1-3", "Years 4-6", "Years 7-9", "Years 10-12"]
        let availableLevels = availableTemplates
            .map { $0.gradeLevel }
            .map(normalized)
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var ordered: [String] = []

        for level in predefined {
            let normalizedLevel = normalized(level)
            if seen.insert(normalizedLevel).inserted {
                ordered.append(level)
            }
        }

        for level in availableLevels {
            if seen.insert(level).inserted {
                ordered.append(level)
            }
        }

        return ordered
    }

    var criteriaFilterOptions: [String] {
        var normalizedToOriginal: [String: String] = [:]

        for template in availableTemplates {
            let normalizedSubject = normalized(template.subject)
            guard !normalizedSubject.isEmpty else { continue }

            if normalizedToOriginal[normalizedSubject] == nil {
                normalizedToOriginal[normalizedSubject] = template.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return normalizedToOriginal.values.sorted {
            displayText($0).localizedCaseInsensitiveCompare(displayText($1)) == .orderedAscending
        }
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
                        filterSelector

                        if filteredTemplates.isEmpty {
                            noMatchingTemplatesView
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
                }
                .padding()
            }
            .appSheetBackground(tint: .purple)
            .navigationTitle("Development Tracking".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
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
            syncSelectedTemplateWithFilters()
        }
        .onChange(of: selectedYearFilter) { _, _ in
            syncSelectedTemplateWithFilters()
        }
        .onChange(of: selectedCriteriaFilter) { _, _ in
            syncSelectedTemplateWithFilters()
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
        .appCardStyle(
            borderColor: Color.purple.opacity(0.14),
            tint: .purple
        )
    }
    
    var filterSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Year".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Picker("Year".localized, selection: $selectedYearFilter) {
                        Text("All Years".localized).tag(Self.allYearsFilterToken)
                        ForEach(yearFilterOptions, id: \.self) { year in
                            Text(displayText(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Criteria".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Picker("Criteria".localized, selection: $selectedCriteriaFilter) {
                        Text("All Criteria".localized).tag(Self.allCriteriaFilterToken)
                        ForEach(criteriaFilterOptions, id: \.self) { criteria in
                            Text(displayText(criteria)).tag(criteria)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.purple.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .purple
        )
    }

    // MARK: - Template Selector
    
    var templateSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rubric Template".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Picker("Template".localized, selection: $selectedTemplate) {
                ForEach(filteredTemplates, id: \.id) { template in
                    Text(displayText(template.name)).tag(template as RubricTemplate?)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.purple.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .purple
        )
    }

    var noMatchingTemplatesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 34))
                .foregroundColor(.secondary)

            Text("No templates match the selected filters".localized)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Text("Try a different year or criteria filter".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .appCardStyle(
            cornerRadius: 14,
            borderColor: Color.gray.opacity(0.18),
            shadowOpacity: 0.03,
            shadowRadius: 4,
            shadowY: 2,
            tint: .purple
        )
    }
    
    func categorySection(_ category: RubricCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.purple)
                
                Text(displayText(category.name))
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
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.purple.opacity(0.12),
            tint: .purple
        )
    }
    
    // MARK: - Criterion Card

    func criterionCard(_ criterion: RubricCriterion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Criterion name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(displayText(criterion.name))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)  // ← Better contrast
                
                if !criterion.details.isEmpty {
                    Text(displayText(criterion.details))
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
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.purple.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .purple
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
        case 1: return languageManager.localized("Needs Significant Support")
        case 2: return languageManager.localized("Beginning to Develop")
        case 3: return languageManager.localized("Developing")
        case 4: return languageManager.localized("Proficient")
        case 5: return languageManager.localized("Mastering / Exceeding")
        default: return languageManager.localized("Not Rated")
        }
    }

    func displayText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = languageManager.localized(trimmed)
        if localized != trimmed { return localized }
        return RubricLocalization.localized(value, languageCode: languageManager.currentLanguage.rawValue)
    }

    func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func syncSelectedTemplateWithFilters() {
        guard !filteredTemplates.isEmpty else {
            selectedTemplate = nil
            return
        }

        if let selectedTemplate,
           filteredTemplates.contains(where: { $0.id == selectedTemplate.id }) {
            return
        }

        self.selectedTemplate = filteredTemplates.first
    }
    
    func loadExistingRatings() {
        let studentScores = allScores.filter { $0.matchesStudent(student) }
        var didRepairStableReferences = false
        
        // Get most recent rating for each criterion
        var latestRatings: [UUID: DevelopmentScore] = [:]
        
        for score in studentScores {
            guard let criterion = score.criterion else { continue }
            let criterionID = criterion.id
            didRepairStableReferences = score.cacheStableReferences(student: student, criterion: criterion) || didRepairStableReferences
            
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

        if didRepairStableReferences {
            Task {
                _ = await SaveCoordinator.perform(context: context, reason: "Repair development score references")
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
        
        Task {
            _ = await SaveCoordinator.perform(context: context, reason: "Save development ratings")
        }
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
}
