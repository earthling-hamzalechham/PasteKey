//
//  ClipboardMonitor.swift
//  PasteKey
//
//  Created by hamza lechham on 24/3/2026.
//

import AppKit
import Combine

// MARK: - ClipboardMonitor

final class ClipboardMonitor: ObservableObject {

    // MARK: - Shared Instance

    static let shared = ClipboardMonitor()

    // MARK: - Constants

    private let maxHistoryCount = 5
    private let pollInterval: TimeInterval = 1.0

    // MARK: - Sensitive pasteboard types
    // These are set by password managers (1Password, Bitwarden, Safari, etc.)
    // to signal that the content should never be cached or displayed.

    private let sensitiveTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("de.petermaurer.TransientPasteboardType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        NSPasteboard.PasteboardType("ro.strictly.sensitive"),
        NSPasteboard.PasteboardType("com.pastekey.internal-injection")

    ]

    // MARK: - State

    /// Last 5 non-sensitive text items copied by the user.
    /// Most recent item is at index 0.
    /// Never persisted — clears when the app quits.
    private(set) var history: [String] = []

    // MARK: - Private

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    func startMonitoring() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Change Detection

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // changeCount didn't increment — nothing was copied, return immediately
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Check for sensitive types before reading any content
        guard !isSensitiveContent(pasteboard) else { return }

        // Only handle plain text
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        addToHistory(text)
    }

    // MARK: - Sensitive Content Check

    private func isSensitiveContent(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains(where: { sensitiveTypes.contains($0) })
    }

    // MARK: - History Management

    private func addToHistory(_ text: String) {
        // Remove if already exists to avoid duplicates, then insert at front
        history.removeAll { $0 == text }
        history.insert(text, at: 0)

        // Keep only the last N items
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
    }

    // MARK: - Public Helpers

    /// Snapshot of the current clipboard text at a specific moment.
    /// Used by HotkeyEngine to capture what was on the clipboard
    /// before a shortcut overwrites it.
    func currentClipboardText() -> String? {
        guard !isSensitiveContent(NSPasteboard.general) else { return nil }
        return NSPasteboard.general.string(forType: .string)
    }

    /// Truncated display version of a history item for showing in the dropdown.
    func displayText(for item: String) -> String {
        let clean = item
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard clean.count > 60 else { return clean }
        return String(clean.prefix(60)) + "…"
    }
}
