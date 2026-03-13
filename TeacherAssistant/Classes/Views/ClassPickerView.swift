import SwiftUI
import SwiftData

struct ClassPickerView: View {
    
    @EnvironmentObject var languageManager: LanguageManager
    @Query(sort: \SchoolClass.sortOrder) private var classes: [SchoolClass]
    
    let tool: DashboardTool
    
    var body: some View {
        #if os(macOS)
        // macOS: No NavigationStack needed, header navigation handles it
        classPickerContent
        #else
        // iOS: Keep NavigationStack for proper navigation
        NavigationStack {
            classPickerContent
        }
        #endif
    }
    
    var classPickerContent: some View {
        ScrollView {
            VStack(spacing: PlatformSpacing.sectionSpacing) {
                
                // Tool info card
                toolInfoCard
                
                // Classes section
                classesSection
                
            }
            .padding(.vertical, 20)
        }
        #if !os(macOS)
        .navigationTitle("Choose Class".localized)
        #endif
    }
    
    // MARK: - Tool Info Card
    
    var toolInfoCard: some View {
        HStack(spacing: 16) {
            Image(systemName: toolIcon)
                .font(.system(size: 40))
                .foregroundColor(toolColor)
                .offset(y: toolIconVerticalOffset)
                .frame(width: 60, height: 60)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: toolColor.opacity(0.16),
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2,
                    tint: toolColor
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(toolTitle)
                    .font(.title3.weight(.semibold))
                    .fontWeight(.semibold)
                
                Text(toolDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 14,
            borderColor: toolColor.opacity(0.12),
            tint: toolColor
        )
        .padding(.horizontal)
    }
    
    // MARK: - Classes Section
    
    var classesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a Class".localized)
                .font(AppTypography.sectionTitle)
                .padding(.horizontal)
            
            if classes.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
                ], spacing: 16) {
                    ForEach(classes.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { schoolClass in
                        NavigationLink {
                            destinationView(for: schoolClass)
                        } label: {
                            ClassPickerCard(schoolClass: schoolClass, toolColor: toolColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No classes yet".localized)
                .font(AppTypography.cardTitle)
                .foregroundColor(.secondary)
            
            Text(String(format: "Create a class first to use %@".localized, toolTitle))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .appCardStyle(
            cornerRadius: 12,
            borderColor: toolColor.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: toolColor
        )
        .padding(.horizontal)
    }
    
    // MARK: - Tool Properties
    
    var toolTitle: String {
        switch tool {
        case .attendance: return "Attendance".localized
        case .liveCheckIn: return "Live Check-In".localized
        case .gradebook: return "Gradebook".localized
        case .groups: return "Group Generator".localized
        case .randomPicker: return "Random Picker".localized
        }
    }
    
    var toolDescription: String {
        switch tool {
        case .attendance: return "Take attendance for your class".localized
        case .liveCheckIn: return "Capture a live snapshot of student understanding and support needs".localized
        case .gradebook: return "View and manage grades".localized
        case .groups: return "Create student groups".localized
        case .randomPicker: return "Pick a random student".localized
        }
    }
    
    var toolIcon: String {
        switch tool {
        case .attendance: return "calendar.badge.checkmark"
        case .liveCheckIn: return "waveform.path.ecg.rectangle"
        case .gradebook: return "tablecells"
        case .groups: return "person.3.fill"
        case .randomPicker: return "shuffle"
        }
    }
    
    var toolColor: Color {
        switch tool {
        case .attendance: return .blue
        case .liveCheckIn: return .indigo
        case .gradebook: return .green
        case .groups: return .purple
        case .randomPicker: return .orange
        }
    }

    var toolIconVerticalOffset: CGFloat {
        switch tool {
        case .groups:
            // Optical correction: person.3.fill sits slightly low in this badge.
            return -2
        default:
            return 0
        }
    }
    
    // MARK: - Destination
    
    @ViewBuilder
    func destinationView(for schoolClass: SchoolClass) -> some View {
        switch tool {
        case .attendance:
            AttendanceListView(schoolClass: schoolClass)
        case .liveCheckIn:
            LiveCheckInView(schoolClass: schoolClass, source: .standaloneTool)
        case .gradebook:
            ClassOverviewView(schoolClass: schoolClass)
        case .groups:
            AdvancedGroupGeneratorView(schoolClass: schoolClass)
        case .randomPicker:
            RandomPickerLauncherView(schoolClass: schoolClass)
        }
    }
}
