import SwiftUI
import SwiftData

struct SymbolGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    var symbols: [(symbol: String, name: String, description: String, example: String, counts: String, isError: Bool)] {
        [
            (
                "✓",
                languageManager.localized("Correct Word"),
                languageManager.localized("Student reads the word correctly"),
                languageManager.localized("The cat sat"),
                languageManager.localized("No error"),
                false
            ),
            (
                "sit\n___\nsat",
                languageManager.localized("Substitution"),
                languageManager.localized("Student says a different word"),
                languageManager.localized("Student says 'sit' instead of 'sat'"),
                languageManager.localized("1 error"),
                true
            ),
            (
                "—",
                languageManager.localized("Omission"),
                languageManager.localized("Student skips a word"),
                languageManager.localized("Reads 'The cat sat mat' (skips 'on')"),
                languageManager.localized("1 error"),
                true
            ),
            (
                "^ down",
                languageManager.localized("Insertion"),
                languageManager.localized("Student adds a word"),
                languageManager.localized("Reads 'The cat sat down on mat'"),
                languageManager.localized("1 error"),
                true
            ),
            (
                "R",
                languageManager.localized("Repetition"),
                languageManager.localized("Student repeats a word/phrase"),
                languageManager.localized("Reads 'The cat cat sat'"),
                languageManager.localized("Usually no error"),
                false
            ),
            (
                "SC",
                languageManager.localized("Self-Correction"),
                languageManager.localized("Student fixes their own error"),
                languageManager.localized("Says 'sit' then corrects to 'sat'"),
                languageManager.localized("NOT an error"),
                false
            ),
            (
                "T / A",
                languageManager.localized("Told/Appeal"),
                languageManager.localized("Teacher tells the word or student asks"),
                languageManager.localized("Student: 'What's this word?'"),
                languageManager.localized("1 error"),
                true
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text(languageManager.localized("Running Record Symbols"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(languageManager.localized("Quick reference guide for assessment"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Symbols List
                    VStack(spacing: 16) {
                        ForEach(symbols.indices, id: \.self) { index in
                            symbolCard(symbols[index])
                        }
                    }
                    .padding(.horizontal)
                    
                    // Analysis Systems
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(languageManager.localized("Error Analysis: The 3 Cueing Systems"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            cueingSystemCard(
                                letter: "M",
                                title: languageManager.localized("Meaning"),
                                description: languageManager.localized("Does it make sense in the story?"),
                                color: .blue
                            )
                            
                            cueingSystemCard(
                                letter: "S",
                                title: languageManager.localized("Structure"),
                                description: languageManager.localized("Does it sound grammatically right?"),
                                color: .purple
                            )
                            
                            cueingSystemCard(
                                letter: "V",
                                title: languageManager.localized("Visual"),
                                description: languageManager.localized("Does it look like the word?"),
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Accuracy Guide
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(languageManager.localized("Reading Levels"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            levelCard(
                                level: languageManager.localized("Independent"),
                                range: "95-100%",
                                description: languageManager.localized("Student can read with ease"),
                                color: .green,
                                icon: "checkmark.circle.fill"
                            )
                            
                            levelCard(
                                level: languageManager.localized("Instructional"),
                                range: "90-94%",
                                description: languageManager.localized("Appropriate for teaching"),
                                color: .orange,
                                icon: "book.fill"
                            )
                            
                            levelCard(
                                level: languageManager.localized("Frustration"),
                                range: "<90%",
                                description: languageManager.localized("Too difficult for student"),
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(languageManager.localized("Symbol Guide"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 700)
        #endif
    }
    
    func symbolCard(_ symbol: (symbol: String, name: String, description: String, example: String, counts: String, isError: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Symbol
                Text(symbol.symbol)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .frame(width: 60, alignment: .center)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                // Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(symbol.name)
                        .font(.headline)
                    
                    Text(symbol.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: languageManager.localized("Example: %@"), symbol.example))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Text(symbol.counts)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(symbol.isError ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(symbol.isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func cueingSystemCard(letter: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    func levelCard(level: String, range: String, description: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(level)
                        .font(.headline)
                    Text(range)
                        .font(.subheadline)
                        .foregroundColor(color)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Running Record Detail View

struct RunningRecordDetailView: View {
    @Bindable var record: RunningRecord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        if let student = record.student {
                            Text(student.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text(record.textTitle)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(record.date.appDateString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Stats Cards
                    VStack(spacing: 16) {
                        // Accuracy
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(languageManager.localized("Accuracy"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.1f%%", record.accuracy))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(levelColor(record.readingLevel))
                            }
                            
                            Spacer()
                            
                            Image(systemName: record.readingLevel.systemImage)
                                .font(.system(size: 50))
                                .foregroundColor(levelColor(record.readingLevel))
                        }
                        .padding()
                        .background(levelColor(record.readingLevel).opacity(0.1))
                        .cornerRadius(12)
                        
                        // Reading Level
                        HStack {
                            Text(languageManager.localized("Reading Level"))
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(levelName(record.readingLevel))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(levelColor(record.readingLevel))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(levelColor(record.readingLevel).opacity(0.15))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Detailed Stats
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            detailStatBox(title: languageManager.localized("Total Words"), value: "\(record.totalWords)", icon: "text.alignleft", color: .purple)
                            detailStatBox(title: languageManager.localized("Errors"), value: "\(record.errors)", icon: "xmark.circle.fill", color: .red)
                            detailStatBox(title: languageManager.localized("Self-Corrections"), value: "\(record.selfCorrections)", icon: "arrow.uturn.left.circle.fill", color: .blue)
                            detailStatBox(title: languageManager.localized("SC Ratio"), value: record.selfCorrectionRatio, icon: "chart.bar.fill", color: .green)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes
                    if !record.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(languageManager.localized("Notes"), systemImage: "note.text")
                                .font(.headline)
                            
                            Text(record.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(languageManager.localized("Running Record"))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Done")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(languageManager.localized("Delete"), systemImage: "trash")
                    }
                }
            }
            .alert(languageManager.localized("Delete Running Record?"), isPresented: $showingDeleteAlert) {
                Button(languageManager.localized("Cancel"), role: .cancel) {}
                
                Button(languageManager.localized("Delete"), role: .destructive) {
                    context.delete(record)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text(languageManager.localized("Are you sure you want to delete this running record? This action cannot be undone."))
            }
        }
    }
    
    func detailStatBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    func levelName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return languageManager.localized("Independent")
        case .instructional: return languageManager.localized("Instructional")
        case .frustration: return languageManager.localized("Frustration")
        }
    }
    
    func levelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }
}
