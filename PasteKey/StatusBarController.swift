//
//  StatusBarController.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import AppKit
import SwiftUI
import Combine

// MARK: - StatusBarController

final class StatusBarController {

    // MARK: Properties

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var store: ShortcutStore
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: EventMonitor?
    private let openMainWindow: () -> Void

    // MARK: - Init

    init(store: ShortcutStore, openMainWindow: @escaping () -> Void) {
        self.store = store
        self.openMainWindow = openMainWindow

        // Build the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Build the popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        // Attach SwiftUI popover content
        let popoverView = PopoverView(store: store, openMainWindow: openMainWindow)
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 320, height: 420)

        // Configure the status bar button
        configureButton()

        // React to store changes (pause state affects icon appearance)
        observeStore()
        
        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.popover.isShown {
                    self.popover.contentViewController?.view.needsLayout = true
                    self.popover.contentViewController?.view.layoutSubtreeIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Close popover when user clicks outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    // MARK: - Button Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        updateIcon()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About PasteKey",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: nil)
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit PasteKey",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .pasteKeyOpenSettings, object: nil)
    }

    @objc private func openAbout() {
        NotificationCenter.default.post(name: .pasteKeyOpenAbout, object: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon State

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName = store.isPaused ? "keyboard.badge.ellipsis" : "keyboard"
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: store.isPaused ? "PasteKey (paused)" : "PasteKey"
        )
        image?.isTemplate = true // adapts to light / dark menu bar automatically
        button.image = image

        // Dim the button when paused
        button.appearsDisabled = store.isPaused
    }

    // MARK: - Combine Observer

    private func observeStore() {
        store.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        // Recreate content every time popover opens to ensure fresh data
        let popoverView = PopoverView(store: store, openMainWindow: openMainWindow)
        popover.contentViewController = NSHostingController(rootView: popoverView)
        popover.contentSize = NSSize(width: 320, height: 420)
        eventMonitor?.start()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }
}

// MARK: - EventMonitor
// Listens for clicks outside the popover so it can be dismissed

final class EventMonitor {

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
