#if os(macOS)

import SwiftUI
import PDFKit

struct PDFViewerMacView: NSViewRepresentable {

    let pdfData: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: pdfData)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(data: pdfData)
    }
}

#endif
