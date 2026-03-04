import SwiftUI

#if os(iOS)
import UIKit

struct SelectAllCommitTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textAlignment: NSTextAlignment = .natural
    var autoFocus: Bool = false
    var onCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.borderStyle = .none
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        textField.inputAccessoryView = context.coordinator.makeAccessoryToolbar()
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.textAlignment = textAlignment

        if uiView.text != text {
            uiView.text = text
        }

        if autoFocus && !context.coordinator.didAutoFocus && uiView.window != nil {
            context.coordinator.didAutoFocus = true
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllCommitTextField
        weak var activeTextField: UITextField?
        var didAutoFocus = false

        init(parent: SelectAllCommitTextField) {
            self.parent = parent
        }

        func makeAccessoryToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.items = [
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(
                    title: "Confirm".localized,
                    style: .plain,
                    target: self,
                    action: #selector(confirmFromAccessory)
                ),
            ]
            return toolbar
        }

        @objc
        func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        @objc
        func confirmFromAccessory() {
            commit(activeTextField)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            activeTextField = textField
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            commit(textField)
            return false
        }

        private func commit(_ textField: UITextField?) {
            if let textField {
                parent.text = textField.text ?? ""
                textField.resignFirstResponder()
            }
            parent.onCommit?()
        }
    }
}
#elseif os(macOS)
import AppKit

struct SelectAllCommitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var textAlignment: NSTextAlignment = .natural
    var autoFocus: Bool = false
    var onCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        nsView.placeholderString = placeholder
        nsView.alignment = textAlignment

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if autoFocus && !context.coordinator.didAutoFocus && nsView.window != nil {
            context.coordinator.didAutoFocus = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectAll(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SelectAllCommitTextField
        weak var activeTextField: NSTextField?
        var didAutoFocus = false

        init(parent: SelectAllCommitTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            activeTextField = textField
            DispatchQueue.main.async {
                textField.currentEditor()?.selectAll(nil)
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            parent.text = (control as? NSTextField)?.stringValue ?? parent.text
            control.window?.makeFirstResponder(nil)
            parent.onCommit?()
            return true
        }
    }
}
#endif
