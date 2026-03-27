//
//  ShortcutListPanel.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//
import SwiftUI

// MARK: - ShortcutListPanel

struct ShortcutListPanel: View {

    // MARK: Properties

    @ObservedObject var store: ShortcutStore
    @Binding var selectedEntry: PasteKeyEntry?
    let isEditing: Bool
    let onNewShortcut: () -> Void
    let onSelectEntry: (PasteKeyEntry) -> Void

    // MARK: Search State
    
    @State private var searchText: String = ""

    private var filteredEntries: [PasteKeyEntry] {
        if searchText.isEmpty {
            return store.entries
        } else {
            return store.entries.filter {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            
            if !store.entries.isEmpty {
                searchBar
            }
            
            Divider()
            listContent
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }

    // MARK: - Header & Search

    private var listHeader: some View {
        HStack {
            Text("Shortcuts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                onNewShortcut()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("New shortcut")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            TextField("Search snippets...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if store.entries.isEmpty {
            EmptyStateView(onNewShortcut: onNewShortcut)
        } else if filteredEntries.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("No snippets match \"\(searchText)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        ShortcutRowView(
                            entry: entry,
                            isSelected: selectedEntry?.id == entry.id && !isEditing
                        )
                        .id(entry.id) // Optimized ID for performance
                        .onTapGesture {
                            onSelectEntry(entry)
                        }

                        if entry.id != filteredEntries.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ShortcutRowView

struct ShortcutRowView: View {

    let entry: PasteKeyEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.displayShortcut)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    isSelected
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 5)
                )

            Text(entry.textPreview)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {

    let onNewShortcut: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("Your recorded shortcuts\nwill be visible here.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ShortcutListPanel(
        store: .preview,
        selectedEntry: .constant(PasteKeyEntry.sampleEntries.first),
        isEditing: false,
        onNewShortcut: {},
        onSelectEntry: { _ in }
    )
    .frame(width: 260, height: 460)
}

#Preview("Empty") {
    ShortcutListPanel(
        store: .empty,
        selectedEntry: .constant(nil),
        isEditing: false,
        onNewShortcut: {},
        onSelectEntry: { _ in }
    )
    .frame(width: 260, height: 460)
}
#endif
