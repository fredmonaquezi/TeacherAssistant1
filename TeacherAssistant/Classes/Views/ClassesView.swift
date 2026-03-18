import SwiftUI
import SwiftData

struct ClassesView: View {
    @ObservedObject var timerManager: ClassroomTimerManager
    
    @Environment(\.modelContext) private var context
    @Environment(\.appMotionContext) private var motion
    @EnvironmentObject var languageManager: LanguageManager
    
    // ✅ Now sorted by our custom order field
    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    
    @State private var showingAdd = false
    @State private var classToEdit: SchoolClass?
    
    // ✅ Delete confirmation state
    @State private var classToDelete: SchoolClass?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        #if os(macOS)
        classesContent
        #else
        SectionNavigationContainer {
            classesContent
        }
        #endif
    }
    
    var classesContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                #if os(macOS)
                // 🖥️ Mac: Card Grid Layout
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 24)
                    ], spacing: 24) {
                        ForEach(Array(classes.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated()), id: \.element.id) { index, schoolClass in
                            NavigationLink {
                                ClassDetailView(
                                    schoolClass: schoolClass,
                                    timerManager: timerManager
                                )
                            } label: {
                                ClassCardView(schoolClass: schoolClass, onDelete: {
                                    classToDelete = schoolClass
                                    showingDeleteAlert = true
                                })
                            }
                            .buttonStyle(AppPressableButtonStyle())
                            .appMotionReveal(index: index)
                            .contextMenu {
                                Button {
                                    classToEdit = schoolClass
                                } label: {
                                    Label("Edit".localized, systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    classToDelete = schoolClass
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete".localized, systemImage: "trash")
                                }
                            }
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
                        ForEach(Array(classes.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated()), id: \.element.id) { index, schoolClass in
                            NavigationLink {
                                ClassDetailView(
                                    schoolClass: schoolClass,
                                    timerManager: timerManager
                                )
                            } label: {
                                ClassCardView(schoolClass: schoolClass, onDelete: {
                                    classToDelete = schoolClass
                                    showingDeleteAlert = true
                                })
                            }
                            .buttonStyle(AppPressableButtonStyle())
                            .appMotionReveal(index: index)
                            .contextMenu {
                                Button {
                                    classToEdit = schoolClass
                                } label: {
                                    Label("Edit".localized, systemImage: "pencil")
                                }

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
            
            // Floating Add Button (macOS only)
            #if os(macOS)
            Button {
                withAnimation(motion.animation(.standard)) {
                    showingAdd = true
                }
            } label: {
                Label("Add Class".localized, systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(AppPressableButtonStyle())
            .padding(24)
            .appMotionReveal(index: 1, axis: .horizontal)
            #endif
        }
        #if !os(macOS)
        .navigationTitle("Classes".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        withAnimation(motion.animation(.standard)) {
                            showingAdd = true
                        }
                    } label: {
                        Label("Add Class".localized, systemImage: "plus")
                    }
                }
            }
        }
        #endif
        .sheet(isPresented: $showingAdd) {
            AddClassView()
                .appSheetMotion()
        }
        .sheet(item: $classToEdit) { schoolClass in
            AddClassView(editingClass: schoolClass)
                .appSheetMotion()
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
