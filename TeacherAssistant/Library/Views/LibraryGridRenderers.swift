import Foundation
import PDFKit

enum LibraryPDFThumbnailCache {
    private static let cache = NSCache<NSString, PlatformImage>()
    private static let renderingQueue = DispatchQueue(
        label: "com.teacherassistant.library.pdf-thumbnail-cache",
        qos: .utility,
        attributes: .concurrent
    )
    private static let coordinationQueue = DispatchQueue(label: "com.teacherassistant.library.pdf-thumbnail-cache.coordination")
    private static var workItems: [UUID: DispatchWorkItem] = [:]

    static func cachedThumbnail(fileID: UUID, pdfData: Data, size: CGSize) -> PlatformImage? {
        let key = cacheKey(fileID: fileID, pdfData: pdfData, size: size)
        return cache.object(forKey: key as NSString)
    }

    @discardableResult
    static func requestThumbnail(
        fileID: UUID,
        pdfData: Data,
        size: CGSize,
        completion: @escaping (PlatformImage?) -> Void
    ) -> UUID? {
        let key = cacheKey(fileID: fileID, pdfData: pdfData, size: size)
        if let cached = cache.object(forKey: key as NSString) {
            completion(cached)
            return nil
        }

        let requestID = UUID()
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem {
            if workItem.isCancelled {
                return
            }
            Task {
                let token = await PerformanceMonitor.shared.beginInterval(.libraryThumbnailRender, metadata: fileID.uuidString)
                let rendered = renderThumbnail(from: pdfData, size: size)
                await PerformanceMonitor.shared.endInterval(token, success: rendered != nil)

                if let rendered {
                    cache.setObject(rendered, forKey: key as NSString)
                }

                DispatchQueue.main.async {
                    guard !workItem.isCancelled else { return }
                    completion(rendered)
                }
                coordinationQueue.async {
                    workItems.removeValue(forKey: requestID)
                }
            }
        }

        coordinationQueue.async {
            workItems[requestID] = workItem
        }

        renderingQueue.asyncAfter(deadline: .now() + 0.05, execute: workItem)
        return requestID
    }

    static func cancelRequest(_ requestID: UUID?) {
        guard let requestID else { return }
        coordinationQueue.async {
            guard let workItem = workItems.removeValue(forKey: requestID) else { return }
            workItem.cancel()
        }
    }

    private static func renderThumbnail(from pdfData: Data, size: CGSize) -> PlatformImage? {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return nil }
        return pdfDocument.generateThumbnail(size: size)
    }

    private static func cacheKey(fileID: UUID, pdfData: Data, size: CGSize) -> String {
        let prefixSignature = pdfData.prefix(16).map { String(format: "%02x", $0) }.joined()
        return "\(fileID.uuidString)-\(pdfData.count)-\(Int(size.width))x\(Int(size.height))-\(prefixSignature)"
    }
}
