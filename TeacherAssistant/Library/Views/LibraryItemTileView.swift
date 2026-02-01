import SwiftUI
import PDFKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct LibraryItemTileView: View {
    let title: String
    let systemImage: String?
    let pdfData: Data?
    
    // Convenience initializers
    init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.pdfData = nil
    }
    
    init(title: String, pdfData: Data) {
        self.title = title
        self.systemImage = nil
        self.pdfData = pdfData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail container
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 140, height: 180)
                
                // Thumbnail or icon
                if let pdfData = pdfData, let thumbnail = generateThumbnail(from: pdfData) {
                    Image(platformImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 180)
                        .clipped()
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 140, height: 180)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)

            // Title
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(width: 140, height: 44)
        }
        .frame(width: 140, height: 232)
    }
    
    // MARK: - Thumbnail Generation
    
    func generateThumbnail(from pdfData: Data) -> PlatformImage? {
        guard let pdfDocument = PDFDocument(data: pdfData),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 140, height: 180)
        
        // Calculate scale to fill the thumbnail area
        let scale = max(
            thumbnailSize.width / pageRect.width,
            thumbnailSize.height / pageRect.height
        )
        
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        #if os(macOS)
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.interpolationQuality = .high
            firstPage.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        return image
        
        #else
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.interpolationQuality = .high
            
            firstPage.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
        #endif
    }
}
