//
//  KeyValidator.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import Foundation
import AppKit

// MARK: - KeyValidator

enum KeyValidator {

    // MARK: - Primary Validation

    static func validate(
        key: String,
        keyCode: Int64,
        modifiers: ModifierFlags,
        existingEntries: [PasteKeyEntry],
        excludingID: UUID? = nil
    ) -> ValidationResult {

        // 1. Must have at least one modifier
        guard !modifiers.isEmpty else {
            return .invalid(reason: "Add at least ⌘, ⌃, or ⌥ to your shortcut.")
        }

        // 2. Must have a valid key
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty, keyCode != -1 else {
            return .invalid(reason: "Please press a key to complete the shortcut.")
        }

        // 3. Must have safe modifiers
        guard hasSafeModifiers(modifiers) else {
            return .invalid(reason: "Use ⌘ or ⌃ with your key to avoid interfering with normal typing. See the recommended combinations above.")
        }

        // 4. Check against system-reserved combos
        if isSystemReserved(key: key, modifiers: modifiers) {
            return .invalid(reason: "This shortcut is reserved by macOS and cannot be used.")
        }

        // 5. Check against existing entries using keyCode
        if let existing = existingEntries.first(where: {
            $0.keyCode == keyCode &&
            $0.modifiers == modifiers &&
            $0.id != excludingID
        }) {
            return .duplicate(existingName: existing.textPreview)
        }

        return .valid
    }

    // MARK: - System Reserved Combos

    static func isSystemReserved(key: String, modifiers: ModifierFlags) -> Bool {
        let k = key.lowercased()

        if modifiers == [.command] {
            let commandReserved: Set<String> = [
                " ", "\t", "q", "w", "h", "m", "n", "o", "s",
                "p", "z", "x", "c", "v", "a", "f", "`", ","
            ]
            if commandReserved.contains(k) { return true }
        }

        if modifiers == [.command, .shift] {
            let commandShiftReserved: Set<String> = [
                "3", "4", "5", "z"
            ]
            if commandShiftReserved.contains(k) { return true }
        }

        if modifiers == [.command, .option] {
            let commandOptionReserved: Set<String> = [
                "d", "\u{001B}"
            ]
            if commandOptionReserved.contains(k) { return true }
        }

        if modifiers == [.control, .command] {
            let controlCommandReserved: Set<String> = [
                "q", "f"
            ]
            if controlCommandReserved.contains(k) { return true }
        }

        return false
    }

    // MARK: - Safe Modifiers Check

    static func hasSafeModifiers(_ modifiers: ModifierFlags) -> Bool {
        return modifiers.contains(.command) || modifiers.contains(.control)
    }

    // MARK: - Key Display Helper

    static func displayKey(for key: String) -> String {
        switch key.lowercased() {
        case " ":        return "Space"
        case "\t":       return "Tab"
        case "\r":       return "Return"
        case "\u{7f}":   return "⌫"
        case "\u{f700}": return "↑"
        case "\u{f701}": return "↓"
        case "\u{f702}": return "←"
        case "\u{f703}": return "→"
        default:         return key.uppercased()
        }
    }
}
