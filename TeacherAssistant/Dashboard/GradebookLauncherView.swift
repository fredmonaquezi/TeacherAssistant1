import SwiftUI
import SwiftData

struct GradebookLauncherView: View {
    
    @Query private var allClasses: [SchoolClass]
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var selectedClass: SchoolClass?
    @State private var selectedSubject: Subject?
    @State private var selectedUnit: Unit?
    
    @State private var showingSubjectPicker = false
    @State private var showingUnitPicker = false
    
    var body: some View {
        List {
            // Step 1 - Pick Class
            Section("Step 1 - Choose Class".localized) {
                if allClasses.isEmpty {
                    Text("No classes found.".localized)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allClasses, id: \.id) { schoolClass in
                        Button {
                            selectedClass = schoolClass
                            selectedSubject = nil
                            selectedUnit = nil
                            showingSubjectPicker = true
                        } label: {
                            HStack {
                                Text(schoolClass.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Step 2 - Pick Subject
            if let selectedClass {
                Section("Step 2 - Choose Subject".localized) {
                    if selectedClass.subjects.isEmpty {
                        Text("This class has no subjects.".localized)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(selectedClass.subjects, id: \.id) { subject in
                            Button {
                                selectedSubject = subject
                                selectedUnit = nil
                                showingUnitPicker = true
                            } label: {
                                HStack {
                                    Text(subject.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            // Step 3 - Pick Unit
            if let selectedSubject {
                Section("Step 3 - Choose Unit".localized) {
                    if selectedSubject.units.isEmpty {
                        Text("This subject has no units.".localized)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(selectedSubject.units, id: \.id) { unit in
                            NavigationLink {
                                UnitGradebookView(unit: unit)
                            } label: {
                                Text(unit.name)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Open Gradebook".localized)
    }
}
