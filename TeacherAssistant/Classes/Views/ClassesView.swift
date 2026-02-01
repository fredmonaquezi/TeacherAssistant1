import SwiftUI
import SwiftData

struct ClassesView: View {
    
    @Environment(\.modelContext) private var context
    @EnvironmentObject var languageManager: LanguageManager
    
    // ✅ Now sorted by our custom order field
    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    
    @State private var showingAdd = false
    
    // ✅ Delete confirmation state
    @State private var classToDelete: SchoolClass?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
#if os(macOS)
// 🖥️ Mac: Card Grid Layout
ScrollView {
    LazyVGrid(columns: [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 24)
    ], spacing: 24) {
        ForEach(classes.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { schoolClass in
            NavigationLink {
                ClassDetailView(schoolClass: schoolClass)
            } label: {
                ClassCardView(schoolClass: schoolClass, onDelete: {
                    classToDelete = schoolClass
                    showingDeleteAlert = true
                })
            }
            .buttonStyle(.plain)
        }
    }
    .padding(24)
}
            #else
                // 📱 iOS / iPadOS: Card Grid Layout (matches Mac)
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 20)
                    ], spacing: 20) {
                        ForEach(classes.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { schoolClass in
                            NavigationLink {
                                ClassDetailView(schoolClass: schoolClass)
                            } label: {
                                ClassCardView(schoolClass: schoolClass, onDelete: {
                                    classToDelete = schoolClass
                                    showingDeleteAlert = true
                                })
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    classToDelete = schoolClass
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete".localized, systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                #endif
            }
            .navigationTitle("Classes".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Add Class".localized, systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddClassView()
            }
            .alert("Delete Class?".localized, isPresented: $showingDeleteAlert) {
                Button("Cancel".localized, role: .cancel) {
                    classToDelete = nil
                }
                
                Button("Delete".localized, role: .destructive) {
                    if let classToDelete {
                        context.delete(classToDelete)
                    }
                    classToDelete = nil
                }
            } message: {
                if let classToDelete {
                    Text(String(format: "Are you sure you want to delete \"%@\"? This will remove all its subjects, units, students, attendance and grades.".localized, classToDelete.name))
                }
            }
        }
    }
    
    
    // MARK: - Reorder
    
    func moveClasses(from source: IndexSet, to destination: Int) {
        var sorted = classes.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)

        for (index, schoolClass) in sorted.enumerated() {
            schoolClass.sortOrder = index
        }
    }

    
    // MARK: - Delete Flow
    
    func askToDeleteClasses(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        classToDelete = classes[index]
        showingDeleteAlert = true
    }
}
