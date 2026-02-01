import SwiftUI
import PDFKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PDFViewerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let file: LibraryFile
    
    @State private var isPresentationMode = false
    @State private var currentPage = 0
    @State private var showControls = true
    @State private var zoomScale: CGFloat = 1.0
    
    var pdfDocument: PDFDocument? {
        PDFDocument(data: file.pdfData)
    }
    
    var totalPages: Int {
        pdfDocument?.pageCount ?? 0
    }
    
    var body: some View {
        ZStack {
            if isPresentationMode {
                // Full-screen presentation mode
                presentationView
            } else {
                // Normal viewing mode
                normalView
            }
        }
        .navigationTitle(file.name)
        .toolbar {
            if !isPresentationMode {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        enterPresentationMode()
                    } label: {
                        Label("Present", systemImage: "rectangle.on.rectangle")
                    }
                }
            }
        }
    }
    
    // MARK: - Normal View
    
    var normalView: some View {
        PDFKitView(pdfData: file.pdfData)
    }
    
    // MARK: - Presentation View
    
    var presentationView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // PDF Page with zoom
                if let document = pdfDocument,
                   currentPage < document.pageCount,
                   let page = document.page(at: currentPage) {
                    
                    ZoomablePDFPageView(page: page, zoomScale: $zoomScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Loading...")
                        .foregroundColor(.white)
                }
                
                // Controls overlay
                if showControls {
                    presentationControls
                        .background(.ultraThinMaterial)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .onAppear {
            zoomScale = 1.0 // Reset zoom when entering presentation
            
            // Hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showControls = false
                }
            }
        }
        // Keyboard shortcuts
        .onKeyPress(.leftArrow) {
            previousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            nextPage()
            return .handled
        }
        .onKeyPress(.escape) {
            exitPresentationMode()
            return .handled
        }
    }
    
    var presentationControls: some View {
        HStack(spacing: 24) {
            // Exit button
            Button {
                exitPresentationMode()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Previous page
            Button {
                previousPage()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundColor(currentPage > 0 ? .white : .gray)
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 0)
            
            // Page counter
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.headline)
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Next page
            Button {
                nextPage()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
                    .foregroundColor(currentPage < totalPages - 1 ? .white : .gray)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
            
            Spacer()
            
            // Zoom indicator
            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding()
    }
    
    // MARK: - Navigation Functions
    
    func previousPage() {
        if currentPage > 0 {
            withAnimation {
                currentPage -= 1
                zoomScale = 1.0 // Reset zoom on page change
            }
        }
    }
    
    func nextPage() {
        if currentPage < totalPages - 1 {
            withAnimation {
                currentPage += 1
                zoomScale = 1.0 // Reset zoom on page change
            }
        }
    }
    
    func enterPresentationMode() {
        isPresentationMode = true
        currentPage = 0
        showControls = true
        zoomScale = 1.0
    }
    
    func exitPresentationMode() {
        isPresentationMode = false
        zoomScale = 1.0
    }
}

// MARK: - PDFKit Integration

#if os(macOS)
struct PDFKitView: NSViewRepresentable {
    let pdfData: Data
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#else
struct PDFKitView: UIViewRepresentable {
    let pdfData: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#endif

// MARK: - Zoomable PDF Page View

#if os(macOS)
struct ZoomablePDFPageView: NSViewRepresentable {
    let page: PDFPage
    @Binding var zoomScale: CGFloat
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .black
        pdfView.displayMode = .singlePage
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = 1.0
        
        let document = PDFDocument()
        document.insert(page, at: 0)
        pdfView.document = document
        
        // Set up zoom observation
        context.coordinator.pdfView = pdfView
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Update PDF page
        let document = PDFDocument()
        document.insert(page, at: 0)
        nsView.document = document
        
        // Update zoom if changed externally
        if abs(nsView.scaleFactor - zoomScale) > 0.01 {
            nsView.scaleFactor = zoomScale
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
    }
    
    class Coordinator: NSObject {
        @Binding var zoomScale: CGFloat
        weak var pdfView: PDFView?
        private var observer: NSObjectProtocol?
        
        init(zoomScale: Binding<CGFloat>) {
            self._zoomScale = zoomScale
            super.init()
        }
        
        deinit {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
#else
struct ZoomablePDFPageView: UIViewRepresentable {
    let page: PDFPage
    @Binding var zoomScale: CGFloat
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .black
        pdfView.displayMode = .singlePage
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = 1.0
        
        let document = PDFDocument()
        document.insert(page, at: 0)
        pdfView.document = document
        
        // Set up zoom observation
        context.coordinator.pdfView = pdfView
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update PDF page
        let document = PDFDocument()
        document.insert(page, at: 0)
        uiView.document = document
        
        // Update zoom if changed externally
        if abs(uiView.scaleFactor - zoomScale) > 0.01 {
            uiView.scaleFactor = zoomScale
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
    }
    
    class Coordinator: NSObject {
        @Binding var zoomScale: CGFloat
        weak var pdfView: PDFView?
        private var observer: NSObjectProtocol?
        
        init(zoomScale: Binding<CGFloat>) {
            self._zoomScale = zoomScale
            super.init()
        }
        
        deinit {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
#endif
