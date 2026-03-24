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

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let relevantMask: UInt64 = 0x100000 | 0x040000 | 0x080000 | 0x020000
        let modifiers = ModifierFlags(rawValue: UInt64(event.flags.rawValue) & relevantMask)

        let entries = store.entries

        // Match on keyCode — reliable regardless of modifier or keyboard layout
        guard let match = entries.first(where: {
            // Match on keyCode if available, otherwise skip
            $0.keyCode != -1 &&
            $0.keyCode == keyCode &&
            modifiersMatch(recorded: $0.modifiers, event: modifiers)
        }) else {
            return Unmanaged.passRetained(event)
        }

        // Consume the event
        event.type = .null

        let textToPaste = match.text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.paste(text: textToPaste)
        }

        return nil
    }

    // MARK: - Paste

    private func paste(text: String) {
        let pasteboard = NSPasteboard.general

        // Snapshot all current pasteboard items before overwriting
        let previousItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        // Write the shortcut text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString(text, forType: .init("public.utf8-plain-text"))

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

        // Restore previous clipboard after a short delay
        // Long enough for the paste to complete, short enough to feel instant
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let items = previousItems, !items.isEmpty {
                pasteboard.writeObjects(items)
            }
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
