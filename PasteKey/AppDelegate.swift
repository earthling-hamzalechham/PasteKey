//
//  AppDelegate.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import AppKit
import SwiftUI
import Combine

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Properties

    private var statusBarController: StatusBarController?
    private var mainWindowController: MainWindowController?
    private var hotkeyEngine: HotkeyEngine?
    private var settingsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var store: ShortcutStore?

    // MARK: - Child Window Tracking

    private var dimOverlay: DimOverlayView?
    private var activeChildWindows: Set<NSWindow> = []
    private var aboutWindowController: NSWindowController?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let store = store else {
            fatalError("[AppDelegate] ShortcutStore was not injected before launch.")
        }

        // Boot status bar
        statusBarController = StatusBarController(store: store, openMainWindow: openMainWindow)

        // Boot hotkey engine
        hotkeyEngine = HotkeyEngine(store: store)

        // Boot clipboard monitor for placeholder history
        ClipboardMonitor.shared.startMonitoring()

        // Observe accessibility permission — restart engine when granted
        AccessibilityPermission.shared.$isGranted
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] isGranted in
                guard let self = self, let store = self.store else { return }
                if isGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.hotkeyEngine = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.hotkeyEngine = HotkeyEngine(store: store)
                        }
                    }
                } else {
                    self.hotkeyEngine = nil
                }
            }
            .store(in: &cancellables)

        // Listen for main window close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowDidClose),
            name: .pasteKeyMainWindowDidClose,
            object: nil
        )

        // Listen for force restart engine
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forceRestartEngine),
            name: .pasteKeyForceRestartEngine,
            object: nil
        )

        // Listen for open settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .pasteKeyOpenSettings,
            object: nil
        )

        // About Window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openAbout),
            name: .pasteKeyOpenAbout,
            object: nil
        )

        // Placeholder Explainer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPlaceholderExplainer),
            name: NewShortcutPanel.openPlaceholderExplainer,
            object: nil
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.openMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.save()
        ClipboardMonitor.shared.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Store Injection

    func configure(store: ShortcutStore) {
        guard self.store == nil else {
            assertionFailure("[AppDelegate] Store has already been configured.")
            return
        }
        self.store = store
    }

    // MARK: - Child Window Presentation

    private func presentOverMainWindow(_ childWindow: NSWindow) {
        openMainWindow()

        guard let mainWindow = mainWindowController?.window else {
            childWindow.center()
            childWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // If already presented, just focus it
        if activeChildWindows.contains(childWindow) {
            childWindow.makeKeyAndOrderFront(nil)
            return
        }

        // Add dim overlay
        addDimOverlay(to: mainWindow)

        // Center child over main window
        let mainFrame = mainWindow.frame
        let childSize = childWindow.frame.size
        let originX = mainFrame.origin.x + (mainFrame.width  - childSize.width)  / 2
        let originY = mainFrame.origin.y + (mainFrame.height - childSize.height) / 2
        childWindow.setFrameOrigin(NSPoint(x: originX, y: originY))

        // Attach as child so it stays above main window
        mainWindow.addChildWindow(childWindow, ordered: .above)
        activeChildWindows.insert(childWindow)

        childWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Clean up when child closes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(childWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: childWindow
        )
    }

    @objc private func childWindowWillClose(_ note: Notification) {
        guard let closedWindow = note.object as? NSWindow else { return }

        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: closedWindow
        )

        if let mainWindow = mainWindowController?.window {
            mainWindow.removeChildWindow(closedWindow)
        }

        activeChildWindows.remove(closedWindow)

        if settingsWindowController?.window === closedWindow {
            settingsWindowController = nil
        }
        if aboutWindowController?.window === closedWindow {
            aboutWindowController = nil
        }

        if activeChildWindows.isEmpty {
            removeDimOverlay()
        }
    }

    // MARK: - Dim Overlay

    private func addDimOverlay(to window: NSWindow) {
        guard dimOverlay == nil else { return }

        // Use the window's frame view (superview of contentView) so the overlay
        // sits above the visual effect views that render behind the window
        guard let frameView = window.contentView?.superview else { return }

        let overlay = DimOverlayView(frame: frameView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        overlay.onTap = { [weak self] in
            self?.dismissAllChildWindows()
        }

        frameView.addSubview(overlay)
        dimOverlay = overlay

        overlay.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            overlay.animator().alphaValue = 1
        }
    }

    private func removeDimOverlay() {
        guard let overlay = dimOverlay else { return }
        dimOverlay = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            overlay.animator().alphaValue = 0
        }, completionHandler: {
            overlay.removeFromSuperview()
        })
    }

    private func dismissAllChildWindows() {
        let windowsToClose = activeChildWindows
        for window in windowsToClose {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet, returnCode: .cancel)
            }
            window.close()
        }
    }

    // MARK: - About Window

    @objc func openAbout() {
        if let existing = aboutWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About PasteKey"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
        window.isMovable = false

        aboutWindowController = NSWindowController(window: window)
        presentOverMainWindow(window)
    }

    // MARK: - Window Management

    func openMainWindow() {
        if let existing = mainWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let store = store else { return }

        let controller = MainWindowController(store: store)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController = controller
    }

    @objc private func mainWindowDidClose() {
        removeDimOverlay()
        activeChildWindows.removeAll()
        settingsWindowController = nil
        aboutWindowController = nil
        placeholderExplainerController = nil
        mainWindowController = nil
    }

    // MARK: - Settings

    @objc func openSettings() {
        if let existing = settingsWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        guard let store = store else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.isReleasedWhenClosed = false
        window.isMovable = false

        settingsWindowController = NSWindowController(window: window)
        presentOverMainWindow(window)
    }
    
    // MARK: - Placeholder Explainer

    private var placeholderExplainerController: NSWindowController?

    @objc func openPlaceholderExplainer() {
        if let existing = placeholderExplainerController {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dynamic Placeholders"
        window.contentView = NSHostingView(rootView: PlaceholderExplainerView())
        window.isReleasedWhenClosed = false
        window.isMovable = false

        placeholderExplainerController = NSWindowController(window: window)
        presentOverMainWindow(window)
        
    }    // MARK: - Force Restart Engine

    @objc private func forceRestartEngine() {
        guard let store = store else { return }
        hotkeyEngine = nil
        hotkeyEngine = HotkeyEngine(store: store)
    }
}

// MARK: - DimOverlayView

private final class DimOverlayView: NSView {

    var onTap: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0 else { return nil }
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }
}
