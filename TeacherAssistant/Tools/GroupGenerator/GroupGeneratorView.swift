import SwiftUI

struct GroupGeneratorView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    let schoolClass: SchoolClass
    
    @State private var groupSize: Int = 4
    @State private var groups: [[Student]] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Card
                    headerCard
                    
                    // Controls Card
                    controlsCard
                    
                    // Results Section
                    if groups.isEmpty {
                        emptyStateView
                    } else {
                        resultsSection
                    }
                    
                }
                .padding(.vertical, 20)
            }
            #if !os(macOS)
            .navigationTitle("Group Generator")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }
    
    // MARK: - Header Card
    
    var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            
            Text("Random Group Generator".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create random student groups for activities".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Class info
            HStack(spacing: 20) {
                infoItem(icon: "person.2.fill", label: "Students", value: "\(schoolClass.students.count)")
                infoItem(icon: "rectangle.3.group.fill", label: "Groups", value: groups.isEmpty ? "—" : "\(groups.count)")
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func infoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Controls Card
    
    var controlsCard: some View {
        VStack(spacing: 16) {
            Text("Group Settings".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Group size control
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Students per group".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: languageManager.localized("%d students"), groupSize))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        if groupSize > 2 {
                            groupSize -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(groupSize > 2 ? .purple : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupSize <= 2)
                    
                    Button {
                        if groupSize < 10 {
                            groupSize += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(groupSize < 10 ? .purple : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupSize >= 10)
                }
            }
            
            Divider()
            
            // Expected groups info
            if !schoolClass.students.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text(String(
                        format: languageManager.localized("This will create approximately %d groups"),
                        expectedGroupCount
                    ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Generate button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    generateGroups()
                }
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text((groups.isEmpty ? "Generate Groups" : "Regenerate Groups").localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var expectedGroupCount: Int {
        let students = schoolClass.students.count
        return (students + groupSize - 1) / groupSize
    }
    
    // MARK: - Empty State
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shuffle.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No groups yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Click 'Generate Groups' to create random student groups".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Results Section
    
    var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generated Groups".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
            ], spacing: 16) {
                ForEach(groups.indices, id: \.self) { index in
                    ModernGroupCard(
                        index: index,
                        students: groups[index],
                        totalGroups: groups.count
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Logic
    
    func generateGroups() {
        let shuffled = schoolClass.students.shuffled()
        groups = []
        
        var index = 0
        while index < shuffled.count {
            let end = min(index + groupSize, shuffled.count)
            let group = Array(shuffled[index..<end])
            groups.append(group)
            index += groupSize
        }
    }
}
