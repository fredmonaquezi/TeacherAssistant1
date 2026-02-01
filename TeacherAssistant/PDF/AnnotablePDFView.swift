import SwiftUI
import PDFKit

#if os(iOS)
import PencilKit
import UIKit
#endif

struct AnnotatablePDFView: View {

    let pdfData: Data
    @Binding var drawingData: Data?
    let isDrawingEnabled: Bool

    var body: some View {
        #if os(iOS)
        AnnotatablePDFView_iOS(
            pdfData: pdfData,
            drawingData: $drawingData,
            isDrawingEnabled: isDrawingEnabled
        )
        #else
        PDFViewerMacView(pdfData: pdfData)
        #endif
    }
}
