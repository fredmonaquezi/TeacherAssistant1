import SwiftUI
import SwiftData

struct SymbolGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    let symbols: [(symbol: String, name: String, description: String, example: String, counts: String)] = [
        ("✓", "Correct Word", "Student reads the word correctly", "The cat sat", "No error"),
        ("sit\n___\nsat", "Substitution", "Student says a different word", "Student says 'sit' instead of 'sat'", "1 error"),
        ("—", "Omission", "Student skips a word", "Reads 'The cat sat mat' (skips 'on')", "1 error"),
        ("^ down", "Insertion", "Student adds a word", "Reads 'The cat sat down on mat'", "1 error"),
        ("R", "Repetition", "Student repeats a word/phrase", "Reads 'The cat cat sat'", "Usually no error"),
        ("SC", "Self-Correction", "Student fixes their own error", "Says 'sit' then corrects to 'sat'", "NOT an error"),
        ("T / A", "Told/Appeal", "Teacher tells the word or student asks", "Student: 'What's this word?'", "1 error")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Running Record Symbols")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Quick reference guide for assessment")
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
                        Text("Error Analysis: The 3 Cueing Systems")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            cueingSystemCard(
                                letter: "M",
                                title: "Meaning",
                                description: "Does it make sense in the story?",
                                color: .blue
                            )
                            
                            cueingSystemCard(
                                letter: "S",
                                title: "Structure",
                                description: "Does it sound grammatically right?",
                                color: .purple
                            )
                            
                            cueingSystemCard(
                                letter: "V",
                                title: "Visual",
                                description: "Does it look like the word?",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Accuracy Guide
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reading Levels")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            levelCard(
                                level: "Independent",
                                range: "95-100%",
                                description: "Student can read with ease",
                                color: .green,
                                icon: "checkmark.circle.fill"
                            )
                            
                            levelCard(
                                level: "Instructional",
                                range: "90-94%",
                                description: "Appropriate for teaching",
                                color: .orange,
                                icon: "book.fill"
                            )
                            
                            levelCard(
                                level: "Frustration",
                                range: "<90%",
                                description: "Too difficult for student",
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Symbol Guide")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 700)
        #endif
    }
    
    func symbolCard(_ symbol: (symbol: String, name: String, description: String, example: String, counts: String)) -> some View {
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
                    
                    Text("Example: \(symbol.example)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Text(symbol.counts)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(symbol.counts.contains("NOT") ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(symbol.counts.contains("NOT") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
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
                        
                        Text(record.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Stats Cards
                    VStack(spacing: 16) {
                        // Accuracy
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accuracy")
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
                            Text("Reading Level")
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
                            detailStatBox(title: "Total Words", value: "\(record.totalWords)", icon: "text.alignleft", color: .purple)
                            detailStatBox(title: "Errors", value: "\(record.errors)", icon: "xmark.circle.fill", color: .red)
                            detailStatBox(title: "Self-Corrections", value: "\(record.selfCorrections)", icon: "arrow.uturn.left.circle.fill", color: .blue)
                            detailStatBox(title: "SC Ratio", value: record.selfCorrectionRatio, icon: "chart.bar.fill", color: .green)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes
                    if !record.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "note.text")
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
            .navigationTitle("Running Record")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .alert("Delete Running Record?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                
                Button("Delete", role: .destructive) {
                    context.delete(record)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this running record? This action cannot be undone.")
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
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
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
