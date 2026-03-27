//
//  PopoverView.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

// MARK: - PopoverView

struct PopoverView: View {

    // MARK: Properties

    @ObservedObject var store: ShortcutStore
    let openMainWindow: () -> Void
    
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
            headerBar
            
            if !store.entries.isEmpty {
                searchBar
            }
            
            Divider()
            shortcutList
            Divider()
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header & Search

        private var headerBar: some View {
            HStack(spacing: 12) {
                Text("PasteKey")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                // Passive Status Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isPaused ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(
                            color: store.isPaused ? .orange.opacity(0.4) : .green.opacity(0.4),
                            radius: 2
                        )

                    Text(store.isPaused ? "Paused" : "Running")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(store.isPaused ? .orange : .primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(store.isPaused ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(store.isPaused ? Color.orange.opacity(0.2) : Color.primary.opacity(0.1), lineWidth: 0.5)
                )

                Spacer()

                // Existing Play/Pause Toggle
                pauseToggleButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        .padding(.bottom, 12)
    }

    private var pauseToggleButton: some View {
        Button {
            store.togglePause()
        } label: {
            Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(store.isPaused ? .green : .secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(store.isPaused ? "Resume all shortcuts" : "Pause all shortcuts")
    }

    // MARK: - Shortcut List

    private var shortcutList: some View {
        Group {
            if store.entries.isEmpty {
                emptyState
            } else if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Text("No snippets match \"\(searchText)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            PopoverRowView(entry: entry)
                            if entry.id != filteredEntries.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    // ... rest of PopoverView remains unchanged ...

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("No shortcuts yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Open the main window to get started.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            // Open main window
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                    Text("Open Main Window")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Settings
            Button {
                NotificationCenter.default.post(name: .pasteKeyOpenSettings, object: nil)
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Quit
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text("Quit PasteKey")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.primary.opacity(0.03))
    }
}

// MARK: - PopoverRowView

struct PopoverRowView: View {

    let entry: PasteKeyEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Main row
            HStack(spacing: 10) {

                // Shortcut badge
                Text(entry.displayShortcut)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 5))

                // Text preview
                Text(entry.textPreview)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Expand chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded detail
            if isExpanded {
                Text(entry.text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PopoverView(store: .preview, openMainWindow: {})
        .frame(width: 320)
}

#Preview("Empty") {
    PopoverView(store: .empty, openMainWindow: {})
        .frame(width: 320)
}
#endif
