import SwiftUI
import SwiftData

struct AddRunningRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allStudents: [Student]
    
    @State private var selectedStudent: Student?
    @State private var date = Date()
    @State private var textTitle = ""
    @State private var totalWords = ""
    @State private var errors = ""
    @State private var selfCorrections = ""
    @State private var notes = ""
    @State private var showingSymbolGuide = false
    
    var totalWordsInt: Int {
        Int(totalWords) ?? 0
    }
    
    var errorsInt: Int {
        Int(errors) ?? 0
    }
    
    var selfCorrectionsInt: Int {
        Int(selfCorrections) ?? 0
    }
    
    var accuracy: Double {
        guard totalWordsInt > 0 else { return 0 }
        return Double(totalWordsInt - errorsInt) / Double(totalWordsInt) * 100
    }
    
    var readingLevel: ReadingLevel {
        if accuracy >= 95 {
            return .independent
        } else if accuracy >= 90 {
            return .instructional
        } else {
            return .frustration
        }
    }
    
    var isValid: Bool {
        selectedStudent != nil &&
        !textTitle.isEmpty &&
        totalWordsInt > 0 &&
        errorsInt >= 0 &&
        selfCorrectionsInt >= 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("New Running Record")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Record reading assessment data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Student Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Student", systemImage: "person.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Menu {
                            ForEach(allStudents.sorted(by: { $0.name < $1.name }), id: \.id) { student in
                                Button(student.name) {
                                    selectedStudent = student
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedStudent?.name ?? "Select a student")
                                    .foregroundColor(selectedStudent == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Date", systemImage: "calendar")
                            .font(.headline)
                        
                        DatePicker("", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    
                    // Text Title
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Text Title", systemImage: "book.closed.fill")
                            .font(.headline)
                        
                        TextField("e.g., The Cat in the Hat", text: $textTitle)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Assessment Data
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Assessment Data", systemImage: "chart.bar.fill")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button {
                                showingSymbolGuide = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Symbol Guide")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Total Words
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total Words")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("0", text: $totalWords)
                                #if !os(macOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Errors
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Errors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("0", text: $errors)
                                #if !os(macOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Self-Corrections
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Self-Corrections (SC)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("0", text: $selfCorrections)
                                #if !os(macOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Live Results
                    if totalWordsInt > 0 {
                        VStack(spacing: 16) {
                            Text("Results")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                // Accuracy
                                HStack {
                                    Text("Accuracy:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f%%", accuracy))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(levelColor(readingLevel))
                                }
                                .padding()
                                .background(levelColor(readingLevel).opacity(0.1))
                                .cornerRadius(10)
                                
                                // Reading Level
                                HStack {
                                    Image(systemName: readingLevel.systemImage)
                                    Text(levelName(readingLevel))
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .font(.subheadline)
                                .foregroundColor(levelColor(readingLevel))
                                .padding()
                                .background(levelColor(readingLevel).opacity(0.15))
                                .cornerRadius(10)
                                
                                // SC Ratio
                                if selfCorrectionsInt > 0 {
                                    HStack {
                                        Text("Self-Correction Ratio:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        let ratio = Double(errorsInt + selfCorrectionsInt) / Double(selfCorrectionsInt)
                                        Text(String(format: "1:%.1f", ratio))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes (Optional)", systemImage: "note.text")
                            .font(.headline)
                        
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("New Running Record")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecord()
                    }
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingSymbolGuide) {
                SymbolGuideView()
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 700)
        #endif
    }
    
    func saveRecord() {
        guard let student = selectedStudent else { return }
        
        let record = RunningRecord(
            date: date,
            textTitle: textTitle,
            totalWords: totalWordsInt,
            errors: errorsInt,
            selfCorrections: selfCorrectionsInt,
            notes: notes
        )
        
        record.student = student
        student.runningRecords.append(record)
        
        context.insert(record)
        try? context.save()
        
        dismiss()
    }
    
    func levelName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent Level (95-100%)"
        case .instructional: return "Instructional Level (90-94%)"
        case .frustration: return "Frustration Level (<90%)"
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
