//
//  Untitled.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//
import Foundation
import CoreGraphics

// MARK: - Modifier Flags

struct ModifierFlags: OptionSet, Codable, Hashable {
    let rawValue: UInt64

    static let command  = ModifierFlags(rawValue: UInt64(0x100000))
    static let control  = ModifierFlags(rawValue: UInt64(0x040000))
    static let option   = ModifierFlags(rawValue: UInt64(0x080000))
    static let shift    = ModifierFlags(rawValue: UInt64(0x020000))

    var displaySymbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

// MARK: - PasteKeyEntry

struct PasteKeyEntry: Identifiable, Codable, Equatable, Hashable {

    var id: UUID
    var text: String
    var shortcutKey: String
    var keyCode: Int64
    var modifiers: ModifierFlags
    var createdAt: Date
    var usePlaceholders: Bool

    init(
        id: UUID = UUID(),
        text: String,
        shortcutKey: String,
        keyCode: Int64 = -1,
        modifiers: ModifierFlags,
        createdAt: Date = Date(),
        usePlaceholders: Bool? = nil
    )
    {
        self.id = id
        self.text = text
        self.shortcutKey = shortcutKey.lowercased()
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.createdAt = createdAt
        // Auto-enable if text contains valid placeholders, unless explicitly set
        self.usePlaceholders = usePlaceholders ?? PasteKeyEntry.containsPlaceholders(text)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, shortcutKey, keyCode, modifiers, createdAt, usePlaceholders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        shortcutKey = try container.decode(String.self, forKey: .shortcutKey)
        keyCode = try container.decodeIfPresent(Int64.self, forKey: .keyCode) ?? -1
        modifiers = try container.decode(ModifierFlags.self, forKey: .modifiers)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Decode if present — older saved entries without this field default to auto-detect
        let decoded = try container.decodeIfPresent(Bool.self, forKey: .usePlaceholders)
        let decodedText = try container.decode(String.self, forKey: .text)
        usePlaceholders = decoded ?? PasteKeyEntry.containsPlaceholders(decodedText)
    }

    var displayShortcut: String {
        modifiers.displaySymbols + shortcutKey.uppercased()
    }

    var textPreview: String {
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard clean.count > 60 else { return clean }
        return String(clean.prefix(60)) + "…"
    }

    /// Returns all unique placeholder names found in the text, in order of appearance.
    /// Only matches valid {word} patterns — alphanumeric and underscores only.
    var placeholderNames: [String] {
        PasteKeyEntry.extractPlaceholders(from: text)
    }

    /// True if the text contains at least one valid placeholder pattern.
    static func containsPlaceholders(_ text: String) -> Bool {
        !extractPlaceholders(from: text).isEmpty
    }

    /// Extracts unique placeholder names in order of appearance.
    /// Valid format: {name} where name is alphanumeric/underscore, 1–30 chars.
    static func extractPlaceholders(from text: String) -> [String] {
        let pattern = #"\{([a-zA-Z0-9_]{1,30})\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range]).lowercased()
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    static func == (lhs: PasteKeyEntry, rhs: PasteKeyEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Validation Result

enum ValidationResult: Equatable {
    case valid
    case invalid(reason: String)
    case duplicate(existingName: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var warningMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let reason):
            return reason
        case .duplicate(let name):
            return "Already used by \"\(name)\". Saving will replace it."
        }
    }
}

// MARK: - Sample Data

#if DEBUG
extension PasteKeyEntry {
    static let sampleEntries: [PasteKeyEntry] = [
        PasteKeyEntry(
            text: "Best regards,\nHamza",
            shortcutKey: "e",
            keyCode: 14,
            modifiers: [.command, .option]
        ),
        PasteKeyEntry(
            text: "Thank you for reaching out! I'll look into this and get back to you within 24 hours.",
            shortcutKey: "s",
            keyCode: 1,
            modifiers: [.command, .option]
        ),
        PasteKeyEntry(
            text: "123 Main Street, Casablanca, Morocco",
            shortcutKey: "a",
            keyCode: 0,
            modifiers: [.command, .shift]
        )
    ]

    static let empty = PasteKeyEntry(
        text: "",
        shortcutKey: "",
        keyCode: -1,
        modifiers: []
    )
    
    
}
#endif
