import Foundation
import PDFKit

enum LibraryPDFThumbnailCache {
    private static let cache = NSCache<NSString, PlatformImage>()
    private static let renderingQueue = DispatchQueue(
        label: "com.teacherassistant.library.pdf-thumbnail-cache",
        qos: .userInitiated,
        attributes: .concurrent
    )

    static func cachedThumbnail(fileID: UUID, pdfData: Data, size: CGSize) -> PlatformImage? {
        let key = cacheKey(fileID: fileID, pdfData: pdfData, size: size)
        return cache.object(forKey: key as NSString)
    }

    static func requestThumbnail(
        fileID: UUID,
        pdfData: Data,
        size: CGSize,
        completion: @escaping (PlatformImage?) -> Void
    ) {
        let key = cacheKey(fileID: fileID, pdfData: pdfData, size: size)
        if let cached = cache.object(forKey: key as NSString) {
            completion(cached)
            return
        }

        renderingQueue.async {
            let rendered = renderThumbnail(from: pdfData, size: size)
            if let rendered {
                cache.setObject(rendered, forKey: key as NSString)
            }
            DispatchQueue.main.async {
                completion(rendered)
            }
        }
    }

    private static func cacheKey(fileID: UUID, pdfData: Data, size: CGSize) -> String {
        let prefixSignature = pdfData.prefix(16).map { String(format: "%02x", $0) }.joined()
        return "\(fileID.uuidString)-\(pdfData.count)-\(Int(size.width))x\(Int(size.height))-\(prefixSignature)"
    }

    private static func renderThumbnail(from pdfData: Data, size: CGSize) -> PlatformImage? {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return nil }
        return pdfDocument.generateThumbnail(size: size)
    }
}
