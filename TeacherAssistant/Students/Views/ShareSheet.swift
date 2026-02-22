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

struct ShareSheet: NSViewControllerRepresentable {
    let activityItems: [Any]

    func makeNSViewController(context: Context) -> MacShareViewController {
        let viewController = MacShareViewController()
        viewController.activityItems = activityItems
        return viewController
    }

    func updateNSViewController(_ viewController: MacShareViewController, context: Context) {
        viewController.activityItems = activityItems
        viewController.presentSharingPickerIfPossible()
    }
}

final class MacShareViewController: NSViewController {
    var activityItems: [Any] = []
    private var hasPresentedPicker = false

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 90))
        let label = NSTextField(labelWithString: "Sharing options")
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 20, y: 34, width: 320, height: 22)
        container.addSubview(label)
        view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        presentSharingPickerIfPossible()
    }

    func presentSharingPickerIfPossible() {
        guard !hasPresentedPicker else { return }
        guard !activityItems.isEmpty else { return }
        guard view.window != nil else { return }

        hasPresentedPicker = true
        let picker = NSSharingServicePicker(items: activityItems)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }
}

#endif
