//
//  ShortcutRecorderView.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit
import Carbon

// MARK: - ShortcutRecorderView

struct ShortcutRecorderView: NSViewRepresentable {

    @Binding var shortcutKey: String
    @Binding var keyCode: Int64
    @Binding var modifiers: ModifierFlags

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = { key, code, mods in
            shortcutKey = key
            keyCode = code
            modifiers = mods
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.currentKey = shortcutKey
        nsView.currentModifiers = modifiers
        nsView.updateDisplay()
    }
}

// MARK: - ShortcutRecorderNSView

final class ShortcutRecorderNSView: NSView {

    // MARK: Properties

    var onRecord: ((String, Int64, ModifierFlags) -> Void)?
    var currentKey: String = ""
    var currentModifiers: ModifierFlags = []

    private var isRecording = false
    private var localEventMonitor: Any?
    private var isClearingInternally = false

    // MARK: - Subviews

    private lazy var containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.borderWidth = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var displayLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var placeholderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Click to record shortcut")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var clearButtonView: ClearButtonView = {
        let view = ClearButtonView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onClear = { [weak self] in
            self?.clearShortcut()
        }
        return view
    }()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        addSubview(containerView)
        containerView.addSubview(placeholderLabel)
        containerView.addSubview(displayLabel)
        containerView.addSubview(clearButtonView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 44),

            placeholderLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            displayLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            displayLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            clearButtonView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            clearButtonView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            clearButtonView.widthAnchor.constraint(equalToConstant: 20),
            clearButtonView.heightAnchor.constraint(equalToConstant: 20),
        ])

        updateDisplay()
    }

    // MARK: - Display

    func updateDisplay() {
        let hasShortcut = !currentKey.isEmpty && !currentModifiers.isEmpty

        if isRecording {
            let liveText = currentModifiers.displaySymbols + (currentKey.isEmpty ? "..." : currentKey.uppercased())
            displayLabel.stringValue = liveText
            displayLabel.textColor = .controlAccentColor
            displayLabel.isHidden = false
            placeholderLabel.isHidden = true
            clearButtonView.isHidden = true
            containerView.layer?.borderColor = NSColor.controlAccentColor.cgColor
            containerView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        } else if hasShortcut {
            displayLabel.stringValue = currentModifiers.displaySymbols + currentKey.uppercased()
            displayLabel.textColor = .labelColor
            displayLabel.isHidden = false
            placeholderLabel.isHidden = true
            clearButtonView.isHidden = false
            containerView.layer?.borderColor = NSColor.separatorColor.cgColor
            containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        } else {
            displayLabel.isHidden = true
            placeholderLabel.isHidden = false
            clearButtonView.isHidden = true
            containerView.layer?.borderColor = NSColor.separatorColor.cgColor
            containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    // MARK: - Focus

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        startRecording()
        return true
    }

    override func resignFirstResponder() -> Bool {
        if !isClearingInternally {
            stopRecording()
        }
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            return
        } else {
            window?.makeFirstResponder(self)
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        currentModifiers = []
        currentKey = ""
        updateDisplay()

        NotificationCenter.default.post(name: .pasteKeyPauseEngine, object: nil)

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self = self else { return event }
            guard self.window?.firstResponder === self else { return event }
            return self.handleEvent(event)
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        NotificationCenter.default.post(name: .pasteKeyResumeEngine, object: nil)

        updateDisplay()
    }

    private func refocusAfterInternalAction() {
        isClearingInternally = true
        window?.makeFirstResponder(nil)
        isClearingInternally = false
        isRecording = false
        currentKey = ""
        currentModifiers = []
        updateDisplay()
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {

        case .flagsChanged:
            currentModifiers = ModifierFlags(
                rawValue: UInt64(event.modifierFlags.rawValue) &
                (0x100000 | 0x040000 | 0x080000 | 0x020000)
            )
            currentKey = ""
            updateDisplay()
            return nil

        case .keyDown:
            let keyCode = Int64(event.keyCode)

            // Delete alone — clear and refocus
            if (event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete)
                && currentModifiers.isEmpty {
                onRecord?("", -1, [])
                refocusAfterInternalAction()
                return nil
            }

            guard !currentModifiers.isEmpty else { return nil }

            // Special keys
            let specialKeys: [Int: (String, Int64)] = [
                kVK_Delete:           ("⌫", Int64(kVK_Delete)),
                kVK_ForwardDelete:    ("⌦", Int64(kVK_ForwardDelete)),
                kVK_Return:           ("↩", Int64(kVK_Return)),
                kVK_ANSI_KeypadEnter: ("⌤", Int64(kVK_ANSI_KeypadEnter)),
                kVK_Tab:              ("⇥", Int64(kVK_Tab)),
                kVK_Space:            ("Space", Int64(kVK_Space)),
                kVK_F1:  ("F1",  Int64(kVK_F1)),
                kVK_F2:  ("F2",  Int64(kVK_F2)),
                kVK_F3:  ("F3",  Int64(kVK_F3)),
                kVK_F4:  ("F4",  Int64(kVK_F4)),
                kVK_F5:  ("F5",  Int64(kVK_F5)),
                kVK_F6:  ("F6",  Int64(kVK_F6)),
                kVK_F7:  ("F7",  Int64(kVK_F7)),
                kVK_F8:  ("F8",  Int64(kVK_F8)),
                kVK_F9:  ("F9",  Int64(kVK_F9)),
                kVK_F10: ("F10", Int64(kVK_F10)),
                kVK_F11: ("F11", Int64(kVK_F11)),
                kVK_F12: ("F12", Int64(kVK_F12)),
                kVK_UpArrow:    ("↑", Int64(kVK_UpArrow)),
                kVK_DownArrow:  ("↓", Int64(kVK_DownArrow)),
                kVK_LeftArrow:  ("←", Int64(kVK_LeftArrow)),
                kVK_RightArrow: ("→", Int64(kVK_RightArrow)),
            ]

            if let (display, code) = specialKeys[Int(event.keyCode)] {
                currentKey = display
                onRecord?(display, code, currentModifiers)
                stopRecording()
                return nil
            }

            // All other keys — use charactersIgnoringModifiers for display
            guard let chars = event.charactersIgnoringModifiers,
                  !chars.isEmpty else {
                return nil
            }

            let displayKey = chars.lowercased()
            currentKey = displayKey
            onRecord?(displayKey, keyCode, currentModifiers)
            stopRecording()
            return nil

        default:
            return event
        }
    }

    // MARK: - Clear

    private func clearShortcut() {
        onRecord?("", -1, [])
        refocusAfterInternalAction()
    }

    // MARK: - Helpers

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 44)
    }
}

// MARK: - ClearButtonView

final class ClearButtonView: NSView {

    var onClear: (() -> Void)?
    private var isHovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHovered {
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
        }

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symbolConfig) {
            let imageRect = NSRect(
                x: (bounds.width - 16) / 2,
                y: (bounds.height - 16) / 2,
                width: 16,
                height: 16
            )
            image.draw(in: imageRect)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onClear?()
    }

    override var acceptsFirstResponder: Bool { false }
}

// MARK: - Preview

#if DEBUG
struct ShortcutRecorderPreview: View {
    @State private var key: String = ""
    @State private var keyCode: Int64 = -1
    @State private var mods: ModifierFlags = []

    var body: some View {
        VStack(spacing: 16) {
            ShortcutRecorderView(shortcutKey: $key, keyCode: $keyCode, modifiers: $mods)
                .frame(height: 44)

            Text(key.isEmpty ? "No shortcut recorded" : mods.displaySymbols + key.uppercased())
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 340)
    }
}

#Preview {
    ShortcutRecorderPreview()
}
#endif
