//
//  PlaceholderPanelWindow.swift
//  PasteKey
//
//  Created by hamza lechham on 24/3/2026.
//

import SwiftUI
import AppKit

// MARK: - PlaceholderPanelWindow

final class PlaceholderPanelWindow: NSPanel {

    private var eventMonitor: Any?
    private var localEventMonitor: Any?

    init(
        placeholders: [String],
        onCommit: @escaping ([String: String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // NSPanel specific settings
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false

        let view = PlaceholderPanelView(
            placeholders: placeholders,
            onCommit: { [weak self] values in
                self?.dismiss()
                onCommit(values)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )

        contentView = NSHostingView(rootView: view)
        contentView?.layer?.cornerRadius = 16
        contentView?.layer?.masksToBounds = true

        center()
    }

    // MARK: - NSPanel overrides
    // These are critical for the panel to receive keyboard events
    // without activating the full app

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Present

    func presentWithoutActivatingApp() {
        // Make the panel key directly without activating NSApp
        makeKeyAndOrderFront(nil)

        // Force first responder so keyboard events work immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.makeKey()
        }

        // Global monitor — outside clicks
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.dismiss()
            }
        }

        // Local monitor — Esc key
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // Escape
                self.dismiss()
                return nil
            }
            return event
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        close()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - PlaceholderPanelView

struct PlaceholderPanelView: View {

    // MARK: Properties

    let placeholders: [String]
    let onCommit: ([String: String]) -> Void
    let onCancel: () -> Void

    // MARK: State

    @State private var values: [String: String] = [:]
    @State private var focusedField: String? = nil
    @State private var shakeFields: Set<String> = []
    @FocusState private var focusState: String?

    private var clipboardHistory: [String] {
        ClipboardMonitor.shared.history
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(placeholders, id: \.self) { name in
                        fieldRow(for: name)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 320)

            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 16)

            footerRow
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 8)
        .onAppear {
            if let first = placeholders.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusState = first
                    focusedField = first
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "curlybraces")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text("Fill in placeholders")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Cancel (Esc)")
        }
    }

    // MARK: - Field Row

    private func fieldRow(for name: String) -> some View {
        let currentValue = values[name] ?? ""
        let isFocused = focusedField == name
        let showHistory = isFocused && currentValue.isEmpty && !clipboardHistory.isEmpty

        return VStack(alignment: .leading, spacing: 6) {
            Text(name.prefix(1).uppercased() + name.dropFirst())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                HStack {
                    TextField("Enter \(name)…", text: binding(for: name))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focusState, equals: name)
                        .onSubmit {
                            advanceFocus(from: name)
                        }
                        .onChange(of: focusState) { _, newValue in
                            focusedField = newValue
                        }
                        .modifier(ShakeModifier(shake: shakeFields.contains(name)))

                    if !currentValue.isEmpty {
                        Button {
                            values[name] = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: showHistory ? 0 : 8,
                        bottomTrailingRadius: showHistory ? 0 : 8,
                        topTrailingRadius: 8
                    )
                )
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: showHistory ? 0 : 8,
                        bottomTrailingRadius: showHistory ? 0 : 8,
                        topTrailingRadius: 8
                    )
                    .fill(Color.primary.opacity(0.05))
                )

                if showHistory {
                    VStack(spacing: 0) {
                        Divider()
                        ForEach(Array(clipboardHistory.enumerated()), id: \.offset) { index, item in
                            Button {
                                values[name] = item
                                advanceFocus(from: name)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                    Text(ClipboardMonitor.shared.displayText(for: item))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.primary.opacity(0.03))

                            if index < clipboardHistory.count - 1 {
                                Divider()
                                    .padding(.leading, 10)
                            }
                        }
                    }
                    .background(Color.primary.opacity(0.04))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 8,
                            bottomTrailingRadius: 8,
                            topTrailingRadius: 0
                        )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        shakeFields.contains(name)
                            ? Color.red.opacity(0.6)
                            : isFocused
                                ? Color.accentColor.opacity(0.6)
                                : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: showHistory)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Text("Press Esc to cancel")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)

            Spacer()

            Button {
                attemptCommit()
            } label: {
                HStack(spacing: 6) {
                    Text("Paste")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "return")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    // MARK: - Logic

    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { values[name] ?? "" },
            set: { values[name] = $0 }
        )
    }

    private func advanceFocus(from name: String) {
        guard let index = placeholders.firstIndex(of: name) else { return }
        let nextIndex = index + 1
        if nextIndex < placeholders.count {
            focusState = placeholders[nextIndex]
        } else {
            attemptCommit()
        }
    }

    private func attemptCommit() {
        let emptyFields = placeholders.filter {
            (values[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }

        guard emptyFields.isEmpty else {
            withAnimation(.default) {
                shakeFields = Set(emptyFields)
            }
            focusState = emptyFields.first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeFields = []
            }
            return
        }

        let trimmed = values.mapValues {
            $0.trimmingCharacters(in: .whitespaces)
        }
        onCommit(trimmed)
    }
}

// MARK: - ShakeModifier

struct ShakeModifier: ViewModifier {
    let shake: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: shake ? 6 : 0)
            .animation(
                shake
                    ? .interpolatingSpring(stiffness: 600, damping: 10)
                        .repeatCount(3, autoreverses: true)
                    : .default,
                value: shake
            )
    }
}
