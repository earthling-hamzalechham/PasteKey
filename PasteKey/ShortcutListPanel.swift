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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            listContent
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }

    // MARK: - Header

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

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if store.entries.isEmpty {
            EmptyStateView(onNewShortcut: onNewShortcut)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.entries) { entry in
                        ShortcutRowView(
                            entry: entry,
                            isSelected: selectedEntry?.id == entry.id && !isEditing
                        )
                        .id(entry.id.uuidString + entry.shortcutKey + entry.modifiers.rawValue.description + entry.text)
                        .onTapGesture {
                            onSelectEntry(entry)
                        }

                        if entry.id != store.entries.last?.id {
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
