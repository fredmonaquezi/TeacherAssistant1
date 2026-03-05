import SwiftUI

#if os(iOS)

import UIKit
import PencilKit
import PDFKit

final class PDFAnnotationContainerView: UIView {

    let pdfView = PDFView()
    let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()

    override init(frame: CGRect) {
        super.init(frame: frame)

        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        addSubview(pdfView)
        addSubview(canvasView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),

            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#else

// ✅ macOS stub version (no UIKit, no PencilKit)

import PDFKit

final class PDFAnnotationContainerView: NSView {

    let pdfView = PDFView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(pdfView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif

#if os(iOS)
import PDFKit
import PencilKit
import UIKit

extension PDFAnnotationContainerView {

    // Called by SwiftUI wrapper
    func loadPDF(data: Data) {
        let document = PDFDocument(data: data)
        pdfView.document = document
    }

    func applyDrawingData(_ data: Data?) {
        if let data, let drawing = try? PKDrawing(data: data) {
            canvasView.drawing = drawing
        }
    }

    func setDrawingEnabled(_ enabled: Bool) {
        canvasView.isUserInteractionEnabled = enabled
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.isHidden = !enabled

        if enabled {
            showToolPicker()
        } else {
            forceHideToolPicker()
        }
    }

    func forceHideToolPicker() {
        if window != nil {
            toolPicker.setVisible(false, forFirstResponder: canvasView)
            toolPicker.removeObserver(canvasView)
        }
    }

    func showToolPicker() {
        if window != nil {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
    }

    // Hook for SwiftUI
    var onDrawingChanged: ((PKDrawing) -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.drawingChangedKey) as? ((PKDrawing) -> Void) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.drawingChangedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private struct AssociatedKeys {
        static var drawingChangedKey: UInt8 = 0
    }
}
#endif
