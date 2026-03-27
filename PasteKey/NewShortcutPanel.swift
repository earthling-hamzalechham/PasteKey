//
//  NewShortcutPanel.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

// MARK: - NewShortcutPanel

struct NewShortcutPanel: View {

    // MARK: Properties

    @ObservedObject var store: ShortcutStore
    let entryToEdit: PasteKeyEntry?
    let onSave: (PasteKeyEntry) -> Void
    let onCancel: () -> Void
    let onChanged: (String, String, ModifierFlags) -> Void

    // MARK: Constants

    private let maxTextLength = 5_000
    static let openPlaceholderExplainer = Notification.Name("pasteKeyOpenPlaceholderExplainer")
    
    // MARK: Form State
    @State private var text: String = ""
    @State private var shortcutKey: String = ""
    @State private var keyCode: Int64 = -1
    @State private var modifiers: ModifierFlags = []
    @State private var validationResult: ValidationResult = .valid
    @State private var isReady = false
    @State private var shortcutWasRecorded = false
    @State private var usePlaceholders: Bool = true


    // MARK: - Computed

    private var isEditing: Bool { entryToEdit != nil }

    private var isSaveEnabled: Bool {
        !text.isEmpty &&
        text.count <= maxTextLength &&
        !shortcutKey.isEmpty &&
        keyCode != -1 &&
        !modifiers.isEmpty && {
            if case .invalid = validationResult { return false }
            if case .duplicate = validationResult { return false }
            return true
        }()
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    panelHeader
                    Divider()
                        .padding(.vertical, 20)
                    shortcutRecorderSection
                    Divider()
                        .padding(.vertical, 20)
                    textSection
                    Spacer()
                        .frame(height: 80)
                }
                .padding(24)
            }

            // Sticky bottom bar — exact same pattern as DetailCardView
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(NSColor.windowBackgroundColor).opacity(0.7),
                        Color(NSColor.windowBackgroundColor)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)

                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.2, green: 0.2, blue: 0.2))     .controlSize(.large)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        saveEntry()
                    } label: {
                        Text(isEditing ? "Update" : "Save")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isSaveEnabled)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(height: 120)
        }
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .onAppear {
            prefillIfEditing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isReady = true
            }
        }
        .onChange(of: entryToEdit) { _, newValue in
            if newValue == nil {
                text = ""
                shortcutKey = ""
                keyCode = -1
                modifiers = []
                validationResult = .valid
                shortcutWasRecorded = false
                usePlaceholders = true
            } else {
                prefillIfEditing()
                shortcutWasRecorded = false
            }
            isReady = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isReady = true
            }
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Edit Shortcut" : "New Shortcut")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(isEditing ? "Update the shortcut details below." : "Assign a key combo and the text it will paste.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Shortcut Recorder Section

    private var shortcutRecorderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Keyboard Shortcut")

            ShortcutRecorderView(
                shortcutKey: $shortcutKey,
                keyCode: $keyCode,
                modifiers: $modifiers
            )
            .onChange(of: shortcutKey) { _, newValue in
                validateShortcut()
                if isReady && !newValue.isEmpty {
                    shortcutWasRecorded = true
                    onChanged(text, newValue, modifiers)
                }
            }
            .onChange(of: modifiers) { _, _ in
                validateShortcut()
            }

            combinationsGuide

            keyLegendRow

            if !shortcutKey.isEmpty && shortcutWasRecorded {
                switch validationResult {
                case .invalid(let reason):
                    validationBanner(message: reason, isError: true)
                case .duplicate(let name):
                    validationBanner(
                        message: "Already assigned to \"\(name)\". Please record a different shortcut.",
                        isError: true
                    )
                case .valid:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("Shortcut is available.")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.08))
                    )
                    .transition(.opacity)
                }
            } else if !shortcutKey.isEmpty && !shortcutWasRecorded {
                // Show errors only (duplicate/invalid) even without recording
                switch validationResult {
                case .invalid(let reason):
                    validationBanner(message: reason, isError: true)
                case .duplicate(let name):
                    validationBanner(
                        message: "Already assigned to \"\(name)\". Please record a different shortcut.",
                        isError: true
                    )
                case .valid:
                    EmptyView()
                }
            }

            Text("Recorded shortcuts will override other apps using the same combo while PasteKey is active.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Combinations Guide

    private var combinationsGuide: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 12))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("⌘ + key  ·  ⌃ + key  ·  ⌘⌥ + key  ·  ⌘⇧ + key  ·  ⌘⌃ + key")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avoid — may interfere with typing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("⌥ + key  ·  ⇧ + key  ·  ⌥⇧ + key")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        } label: {
            Text("Shortcut combinations guide")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .tint(.secondary)
    }

    // MARK: - Key Legend Row

    private var keyLegendRow: some View {
        HStack(spacing: 8) {
            ForEach([
                ("⌘", "Command"),
                ("⌃", "Control"),
                ("⌥", "Option"),
                ("⇧", "Shift")
            ], id: \.0) { symbol, label in
                HStack(spacing: 4) {
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(label)
                        .font(.system(size: 11))
                }
                .foregroundStyle(modifierIsActive(symbol) ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(modifierIsActive(symbol)
                              ? Color.accentColor.opacity(0.1)
                              : Color.primary.opacity(0.05))
                )
            }
            Spacer()
        }
    }

    private func modifierIsActive(_ symbol: String) -> Bool {
        switch symbol {
        case "⌘": return modifiers.contains(.command)
        case "⌃": return modifiers.contains(.control)
        case "⌥": return modifiers.contains(.option)
        case "⇧": return modifiers.contains(.shift)
        default:   return false
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Paste Content")

            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(minHeight: 120, maxHeight: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .scrollContentBackground(.hidden)
                .onChange(of: text) { _, newValue in
                    if isReady && !newValue.isEmpty {
                        onChanged(newValue, shortcutKey, modifiers)
                    }
                }

            HStack {
                Text("Supports multiple lines and emoji.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(text.count) / \(maxTextLength) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(text.count > maxTextLength ? Color.red : Color(nsColor: .quaternaryLabelColor))
            }

            if text.count > maxTextLength {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text("Text exceeds the \(maxTextLength) character limit.")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.08))
                )
                .transition(.opacity)
            }

            placeholderIndicatorRow
        }
    }

    // MARK: - Placeholder Indicator Row

    private var placeholderIndicatorRow: some View {
        let hasPlaceholders = PasteKeyEntry.containsPlaceholders(text)

        return HStack(spacing: 8) {
            // Checkmark toggle — only interactive when placeholders exist
            Image(systemName: hasPlaceholders && usePlaceholders
                  ? "checkmark.circle.fill"
                  : "circle")
                .font(.system(size: 13))
                .foregroundStyle(hasPlaceholders ? Color.accentColor : Color.secondary)
                .onTapGesture {
                    guard hasPlaceholders else { return }
                    togglePlaceholders()
                }

            Text("Dynamic placeholders")
                .font(.system(size: 12))
                .foregroundStyle(hasPlaceholders ? Color.primary : Color.secondary)

            Spacer()

            // Info button — opens explainer
            Button {
                NotificationCenter.default.post(
                    name: NewShortcutPanel.openPlaceholderExplainer,
                    object: nil
                )
            } label: {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Learn how dynamic placeholders work")
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.15), value: hasPlaceholders)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.escape, modifiers: [])

            Button {
                saveEntry()
            } label: {
                Text(isEditing ? "Update" : "Save")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isSaveEnabled)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    private func validationBanner(message: String, isError: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(isError ? .red : .orange)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(isError ? .red : .orange)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isError
                      ? Color.red.opacity(0.08)
                      : Color.orange.opacity(0.08))
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(duration: 0.25), value: validationResult)
    }

    // MARK: - Logic

    private func prefillIfEditing() {
        guard let entry = entryToEdit else { return }
        text = entry.text
        shortcutKey = entry.shortcutKey
        keyCode = entry.keyCode
        modifiers = entry.modifiers
        usePlaceholders = entry.usePlaceholders
    }

    private func togglePlaceholders() {
        usePlaceholders.toggle()
    }

    private func validateShortcut() {
        guard !shortcutKey.isEmpty else {
            validationResult = .valid
            return
        }

        validationResult = KeyValidator.validate(
            key: shortcutKey,
            keyCode: keyCode,
            modifiers: modifiers,
            existingEntries: store.entries,
            excludingID: entryToEdit?.id
        )
    }

    private func saveEntry() {
        guard isSaveEnabled else { return }

        let result = KeyValidator.validate(
            key: shortcutKey,
            keyCode: keyCode,
            modifiers: modifiers,
            existingEntries: store.entries,
            excludingID: entryToEdit?.id
        )

        if case .invalid = result {
            validationResult = result
            return
        }

        if case .duplicate = result {
            validationResult = result
            return
        }

        let entry = PasteKeyEntry(
            id: entryToEdit?.id ?? UUID(),
            text: text,
            shortcutKey: shortcutKey,
            keyCode: keyCode,
            modifiers: modifiers,
            createdAt: entryToEdit?.createdAt ?? Date(),
            usePlaceholders: PasteKeyEntry.containsPlaceholders(text) ? usePlaceholders : false
        )

        if isEditing {
            store.update(entry)
        } else {
            store.add(entry)
        }

        onSave(entry)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("New") {
    NewShortcutPanel(
        store: .preview,
        entryToEdit: nil,
        onSave: { _ in },
        onCancel: {},
        onChanged: { _, _, _ in }
    )
    .frame(width: 400, height: 560)
}

#Preview("Edit") {
    NewShortcutPanel(
        store: .preview,
        entryToEdit: PasteKeyEntry.sampleEntries[0],
        onSave: { _ in },
        onCancel: {},
        onChanged: { _, _, _ in }
    )
    .frame(width: 400, height: 560)
}
#endif
