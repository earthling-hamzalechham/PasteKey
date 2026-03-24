//
//  MainWindowController.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import AppKit
import SwiftUI

// MARK: - MainWindowController

final class MainWindowController: NSWindowController, NSWindowDelegate {

    // MARK: Init

    init(store: ShortcutStore) {
        // Build the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView  // allows content to flow under the title bar
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // Window appearance
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true

        // Minimum size so the split view never collapses
        window.minSize = NSSize(width: 580, height: 420)

        // Centre on first open
        window.center()

        // Keep window alive when closed (so we can re-show it)
        window.isReleasedWhenClosed = false

        // Attach SwiftUI content
        let contentView = MainWindowView(store: store)
        window.contentView = NSHostingView(rootView: contentView)

        // Self as delegate to handle close behaviour
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init(store:)")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Notify AppDelegate so it can nil out its reference
        // This allows the window to be fully recreated on next open
        NotificationCenter.default.post(
            name: .pasteKeyMainWindowDidClose,
            object: nil
        )
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure the app is active when the window comes to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pasteKeyMainWindowDidClose = Notification.Name("pasteKeyMainWindowDidClose")
    static let pasteKeyForceRestartEngine = Notification.Name("pasteKeyForceRestartEngine")
    static let pasteKeyPauseEngine = Notification.Name("pasteKeyPauseEngine")
    static let pasteKeyResumeEngine = Notification.Name("pasteKeyResumeEngine")
    static let pasteKeyOpenSettings = Notification.Name("pasteKeyOpenSettings")
    static let pasteKeyOpenAbout = Notification.Name("pasteKeyOpenAbout")
    static let pasteKeyClearSelection = Notification.Name("pasteKeyClearSelection")
}
