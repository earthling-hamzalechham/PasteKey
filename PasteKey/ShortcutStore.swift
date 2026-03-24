//
//  ShortcutStore.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import Foundation
import Combine
import SwiftUI

// MARK: - ShortcutStore

final class ShortcutStore: ObservableObject {

    // MARK: Published state

    @Published var entries: [PasteKeyEntry] = []
    @Published var isPaused: Bool = false

    // MARK: Private — persistence keys

    private let entriesKey = "pastekey.entries"
    private let isPausedKey = "pastekey.isPaused"

    // MARK: Init

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ entry: PasteKeyEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll {
                $0.keyCode == entry.keyCode &&
                $0.modifiers == entry.modifiers &&
                $0.id != entry.id
            }
            self.entries.insert(entry, at: 0)
            self.save()
        }
    }

    func update(_ entry: PasteKeyEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll {
                $0.keyCode == entry.keyCode &&
                $0.modifiers == entry.modifiers &&
                $0.id != entry.id
            }
            if let index = self.entries.firstIndex(where: { $0.id == entry.id }) {
                self.entries[index] = entry
            }
            self.save()
        }
    }

    func delete(_ entry: PasteKeyEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.id == entry.id }
            self.save()
        }
    }

    func delete(at offsets: IndexSet) {
        DispatchQueue.main.async {
            self.entries.remove(atOffsets: offsets)
            self.save()
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        DispatchQueue.main.async {
            self.entries.move(fromOffsets: source, toOffset: destination)
            self.save()
        }
    }

    // MARK: - Pause / Resume

    func togglePause() {
        DispatchQueue.main.async {
            self.isPaused.toggle()
            UserDefaults.standard.set(self.isPaused, forKey: self.isPausedKey)
        }
    }

    func setPaused(_ paused: Bool) {
        DispatchQueue.main.async {
            self.isPaused = paused
            UserDefaults.standard.set(paused, forKey: self.isPausedKey)
        }
    }

    // MARK: - Validation Helpers

    func existingEntry(for keyCode: Int64, modifiers: ModifierFlags, excluding id: UUID? = nil) -> PasteKeyEntry? {
        entries.first {
            $0.keyCode == keyCode &&
            $0.modifiers == modifiers &&
            $0.id != id
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            print("[ShortcutStore] Failed to save entries: \(error)")
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: entriesKey) {
            do {
                entries = try JSONDecoder().decode([PasteKeyEntry].self, from: data)
            } catch {
                print("[ShortcutStore] Failed to decode entries: \(error)")
                entries = []
            }
        }
        isPaused = UserDefaults.standard.bool(forKey: isPausedKey)
    }

    // MARK: - Export / Import

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    func importJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([PasteKeyEntry].self, from: data)

        var merged = entries

        for incoming in imported {
            // Remove any existing entry with the same keyCode + modifiers combo
            merged.removeAll {
                $0.keyCode == incoming.keyCode &&
                $0.modifiers == incoming.modifiers
            }
            // Also remove if same id
            merged.removeAll {
                $0.id == incoming.id
            }
            // Add the incoming entry
            merged.append(incoming)
        }

        entries = merged
        save()
    }
}

// MARK: - Preview support

#if DEBUG
extension ShortcutStore {
    static var preview: ShortcutStore {
        let store = ShortcutStore()
        store.entries = PasteKeyEntry.sampleEntries
        return store
    }

    static var empty: ShortcutStore {
        ShortcutStore()
    }
}
#endif
