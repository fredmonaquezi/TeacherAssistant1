import SwiftUI
import SwiftData

struct UnitPDFsView: View {
    let unit: Unit
    
    @Query private var allFiles: [LibraryFile]
    
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
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
