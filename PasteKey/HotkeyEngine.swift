//
//  HotkeyEngine.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import Foundation
import CoreGraphics
import AppKit
import Combine
import Carbon

// MARK: - HotkeyEngine

final class HotkeyEngine {

    // MARK: Properties

    private var store: ShortcutStore
    private var cancellables = Set<AnyCancellable>()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Init

    init(store: ShortcutStore) {
        self.store = store
        observeStore()
        observeRecorderNotifications()
        observeAccessibilityRevocation()
    }

    // MARK: - Accessibility Revocation Observer

    private func observeAccessibilityRevocation() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let granted = AXIsProcessTrusted()
                if !granted {
                    self.stopTap()
                }
                AccessibilityPermission.shared.checkPermission()
            }
        }
    }
    
    deinit {
        stopTap()
    }

    func restart() {
        stopTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startTap()
        }
    }

    // MARK: - Store Observer

    private func observeStore() {
        Publishers.CombineLatest(
            store.$entries,
            store.$isPaused
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] entries, isPaused in
            guard let self = self else { return }
            if isPaused || entries.isEmpty {
                self.stopTap()
            } else {
                self.startTap()
            }
        }
        .store(in: &cancellables)

        AccessibilityPermission.shared.$isGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isGranted in
                guard let self = self else { return }
                if isGranted && !self.store.isPaused && !self.store.entries.isEmpty {
                    self.stopTap()
                    self.startTap()
                } else if !isGranted {
                    self.stopTap()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Recorder Notifications

    private func observeRecorderNotifications() {
        NotificationCenter.default.addObserver(
            forName: .pasteKeyPauseEngine,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopTap()
        }

        NotificationCenter.default.addObserver(
            forName: .pasteKeyResumeEngine,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.store.isPaused && !self.store.entries.isEmpty {
                self.startTap()
            }
        }
    }

    // MARK: - CGEventTap Lifecycle

    private func startTap() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            print("[HotkeyEngine] Accessibility permission not granted — tap not started.")
            AccessibilityPermission.shared.handleTapFailure()
            return
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            print("[HotkeyEngine] Failed to create CGEventTap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        print("[HotkeyEngine] Event tap started — \(store.entries.count) shortcuts registered.")
    }

    private func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        print("[HotkeyEngine] Event tap stopped.")
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let relevantMask: UInt64 = 0x100000 | 0x040000 | 0x080000 | 0x020000
        let modifiers = ModifierFlags(rawValue: UInt64(event.flags.rawValue) & relevantMask)

        let entries = store.entries

        guard let match = entries.first(where: {
            $0.keyCode != -1 &&
            $0.keyCode == keyCode &&
            modifiersMatch(recorded: $0.modifiers, event: modifiers)
        }) else {
            return Unmanaged.passRetained(event)
        }

        // Consume the event
        event.type = .null

        let textToPaste = match.text
        let usePlaceholders = match.usePlaceholders
        let placeholderNames = match.placeholderNames

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if usePlaceholders && !placeholderNames.isEmpty {
                self.showPlaceholderPanel(
                    text: textToPaste,
                    placeholders: placeholderNames
                )
            } else {
                self.paste(text: textToPaste)
            }
        }

        return nil
    }

    
    // MARK: - Placeholder Panel

    private var placeholderPanel: PlaceholderPanelWindow?

    private func showPlaceholderPanel(text: String, placeholders: [String]) {
        // Snapshot clipboard before showing panel
        let previousItems = snapshotClipboard()

        let panel = PlaceholderPanelWindow(
            placeholders: placeholders,
            onCommit: { [weak self] values in
                guard let self = self else { return }
                // Replace all placeholder occurrences with filled values
                var resolved = text
                for (name, value) in values {
                    // Escape the name so special regex characters don't break the pattern
                    let safeName = NSRegularExpression.escapedPattern(for: name)
                    let pattern = #"\{"# + safeName + #"\}"#

                    if let regex = try? NSRegularExpression(
                        pattern: pattern,
                        options: .caseInsensitive
                    ) {
                        let range = NSRange(resolved.startIndex..., in: resolved)
                        // Escape the replacement value so $ signs are treated as literals
                        // e.g. user typing "$100" won't be misread as a regex back-reference
                        let safeValue = value.replacingOccurrences(of: "\\", with: "\\\\")
                                             .replacingOccurrences(of: "$", with: "\\$")
                        resolved = regex.stringByReplacingMatches(
                            in: resolved,
                            range: range,
                            withTemplate: safeValue
                        )
                    }
                }
                self.pasteAfterPanel(text: resolved, previousItems: previousItems)
                self.placeholderPanel = nil
            },
            onCancel: { [weak self] in
                // Restore clipboard silently on cancel
                self?.restoreClipboard(previousItems)
                self?.placeholderPanel = nil
            }
        )

        placeholderPanel = panel
        panel.presentWithoutActivatingApp()
    }

    private func pasteAfterPanel(text: String, previousItems: [NSPasteboardItem]?) {
        // Step 1 — write text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString(text, forType: .init("public.utf8-plain-text"))
        pasteboard.setString("ignore", forType: .init("com.pastekey.internal-injection"))


        let source = CGEventSource(stateID: .combinedSessionState)

        // Step 2 — hide PasteKey so focus returns to the previous app
        NSApp.hide(nil)

        // Step 3 — wait for focus to transfer, then post Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
                cmdVDown.flags = .maskCommand
                cmdVDown.post(tap: .cgAnnotatedSessionEventTap)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                if let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                    cmdVUp.flags = .maskCommand
                    cmdVUp.post(tap: .cgAnnotatedSessionEventTap)
                }

                // Step 4 — restore clipboard after paste completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.restoreClipboard(previousItems)
                }
            }
        }
    }
    
    
    // MARK: - Paste

    private func paste(text: String) {
        let previousItems = snapshotClipboard()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString(text, forType: .init("public.utf8-plain-text"))
        pasteboard.setString("ignore", forType: .init("com.pastekey.internal-injection"))


        let source = CGEventSource(stateID: .combinedSessionState)

        if let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            cmdVDown.flags = .maskCommand
            cmdVDown.post(tap: .cgAnnotatedSessionEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            if let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                cmdVUp.flags = .maskCommand
                cmdVUp.post(tap: .cgAnnotatedSessionEventTap)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restoreClipboard(previousItems)
        }
    }

    // MARK: - Clipboard Helpers

    private func snapshotClipboard() -> [NSPasteboardItem]? {
        return NSPasteboard.general.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private func restoreClipboard(_ items: [NSPasteboardItem]?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let items = items, !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    // MARK: - Modifier Matching

    private func modifiersMatch(recorded: ModifierFlags, event: ModifierFlags) -> Bool {
        let relevantMask: UInt64 = 0x100000 | 0x040000 | 0x080000 | 0x020000
        let maskedRecorded = recorded.rawValue & relevantMask
        let maskedEvent    = event.rawValue    & relevantMask
        return maskedRecorded == maskedEvent
    }
}

// MARK: - C Callback (must be outside class)

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    let engine = Unmanaged<HotkeyEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handleEvent(proxy: proxy, type: type, event: event)
}
