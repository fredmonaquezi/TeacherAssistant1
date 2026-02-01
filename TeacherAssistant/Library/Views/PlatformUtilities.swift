import SwiftUI
import PDFKit

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - Cross-Platform Image Extension

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

// MARK: - Cross-Platform PDF Thumbnail Generator

extension PDFDocument {
    func generateThumbnail(size: CGSize) -> PlatformImage? {
        guard let firstPage = self.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        
        // Calculate scale to fill the thumbnail area
        let scale = max(
            size.width / pageRect.width,
            size.height / pageRect.height
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
