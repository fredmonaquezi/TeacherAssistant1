import SwiftUI
import SwiftData

struct UnitPDFsView: View {
    let unit: Unit
    
    @Query private var allFiles: [LibraryFile]

    var totalMaterialCount: Int {
        linkedPDFs.count + subjectPDFs.count
    }
    
    var linkedPDFs: [LibraryFile] {
        allFiles.filter { $0.linkedUnit?.id == unit.id }
    }
    
    var subjectPDFs: [LibraryFile] {
        guard let subjectID = unit.subject?.id else { return [] }
        return allFiles.filter {
            $0.linkedSubject?.id == subjectID && $0.linkedUnit == nil
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                
                // Unit-specific PDFs
                if !linkedPDFs.isEmpty {
                    pdfSection(
                        title: "Unit Materials".localized,
                        subtitle: "PDFs linked to this unit".localized,
                        files: linkedPDFs,
                        color: .blue
                    )
                }
                
                // Subject-wide PDFs
                if !subjectPDFs.isEmpty {
                    pdfSection(
                        title: "Subject Materials",
                        subtitle: "PDFs for \(unit.subject?.name ?? "subject")".localized,
                        files: subjectPDFs,
                        color: .purple
                    )
                }
                
                // Empty state
                if linkedPDFs.isEmpty && subjectPDFs.isEmpty {
                    emptyStateView
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Materials: \(unit.name)".localized)
        .macNavigationDepth()
    }

    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resource Library".localized)
                        .font(.title3.weight(.semibold))
                    Text("Keep lesson PDFs linked to this unit and subject so they stay connected to planning and class use.".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink {
                    LibraryRootView()
                } label: {
                    Label("Open Library".localized, systemImage: "books.vertical")
                }
                .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                materialStat(
                    title: "Unit Files".localized,
                    value: "\(linkedPDFs.count)",
                    color: .blue
                )
                materialStat(
                    title: "Subject Files".localized,
                    value: "\(subjectPDFs.count)",
                    color: .purple
                )
                materialStat(
                    title: "Total Files".localized,
                    value: "\(totalMaterialCount)",
                    color: totalMaterialCount > 0 ? .green : .orange
                )
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.purple.opacity(0.12),
            tint: .purple
        )
        .padding(.horizontal)
    }
    
    func pdfSection(title: String, subtitle: String, files: [LibraryFile], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
            ], spacing: 24) {
                ForEach(files, id: \.id) { file in
                    PDFCardView(
                        file: file,
                        isRenaming: false,
                        onRename: {},
                        onEndRename: {}
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    func materialStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle(
            cornerRadius: 12,
            borderColor: color.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 4,
            shadowY: 2,
            tint: color
        )
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No PDFs linked yet".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Go to Library and tag PDFs with this unit to see them here".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink {
                LibraryRootView()
            } label: {
                Label("Open Library".localized, systemImage: "books.vertical")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
