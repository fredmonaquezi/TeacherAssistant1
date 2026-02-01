import SwiftUI

#if os(iOS)

import UIKit

// =======================
// ✅ iOS IMPLEMENTATION
// =======================

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)

import AppKit

// =======================
// ✅ macOS IMPLEMENTATION
// =======================

struct ShareSheet: View {

    let activityItems: [Any]

    var body: some View {
        Button("Share") {
            share()
        }
    }

    func share() {
        guard let item = activityItems.first else { return }

        let picker = NSSharingServicePicker(items: [item])

        if let window = NSApplication.shared.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
}

#endif
