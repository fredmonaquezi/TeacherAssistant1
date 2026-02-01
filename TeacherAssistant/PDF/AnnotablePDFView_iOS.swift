#if os(iOS)

import SwiftUI
import PDFKit
import PencilKit
import UIKit

struct AnnotatablePDFView_iOS: UIViewRepresentable {

    let pdfData: Data
    @Binding var drawingData: Data?
    let isDrawingEnabled: Bool

    func makeUIView(context: Context) -> PDFAnnotationContainerView {
        let container = PDFAnnotationContainerView()

        container.loadPDF(data: pdfData)

        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            container.canvasView.drawing = drawing
        }

        container.onDrawingChanged = { drawing in
            self.drawingData = drawing.dataRepresentation()
        }

        DispatchQueue.main.async {
            container.forceHideToolPicker()
            container.setDrawingEnabled(false)
        }

        return container
    }

    func updateUIView(_ uiView: PDFAnnotationContainerView, context: Context) {
        uiView.applyDrawingData(drawingData)
        uiView.setDrawingEnabled(isDrawingEnabled)
    }
}

#endif
