//
//  MainWindowView.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

// MARK: - MainWindowView

struct MainWindowView: View {

    // MARK: Properties

    @ObservedObject var store: ShortcutStore
    @ObservedObject private var permission = AccessibilityPermission.shared
    @State private var selectedEntry: PasteKeyEntry? = nil
    @State private var isShowingNewShortcut = false
    @State private var entryToEdit: PasteKeyEntry? = nil

    // Snapshot for unsaved changes detection
    @State private var snapshotText: String = ""
    @State private var snapshotKey: String = ""
    @State private var snapshotModifiers: ModifierFlags = []

    // Discard alert
    @State private var isShowingDiscardAlert = false
    @State private var pendingAction: PendingAction? = nil
    
    static let pasteKeyQuitIfSafe = Notification.Name("pasteKeyQuitIfSafe")


    enum PendingAction {
        case selectEntry(PasteKeyEntry)
        case newShortcut
        case quit
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            
            // Custom header
            HStack(spacing: 10) {
                Button {
                    store.togglePause()
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(
                            !permission.isGranted ? Color.secondary :
                            store.isPaused ? Color.green : Color.primary
                        )
                        .frame(width: 28, height: 28)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(!permission.isGranted)
                .help(
                    !permission.isGranted ? "Accessibility permission required" :
                    store.isPaused ? "Resume all shortcuts" : "Pause all shortcuts"
                )

                Text("PasteKey")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("| ")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)

                    if !permission.isGranted {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            Text(" Waiting for permission")
                                .font(.system(size: 11).italic())
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text(store.isPaused ? "Paused" : "Running")
                            .font(.system(size: 11).italic())
                            .foregroundStyle(store.isPaused ? .orange : .green)
                    }
                }

                Spacer()

                Button {
                    NotificationCenter.default.post(name: .pasteKeyOpenSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            

            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VisualEffectView(material: .titlebar, blendingMode: .behindWindow))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color.primary.opacity(0.1)),
                alignment: .bottom
            )
            .onReceive(NotificationCenter.default.publisher(for: .pasteKeyClearSelection)) { _ in
                selectedEntry = nil
                isShowingNewShortcut = false
                entryToEdit = nil
                resetSnapshot()
            }
            // Permission warning banner
            if !permission.isGranted {
                permissionBanner
            }

            HSplitView {
                ShortcutListPanel(
                    store: store,
                    selectedEntry: $selectedEntry,
                    isEditing: isShowingNewShortcut,
                    onNewShortcut: {
                        handleNewShortcut()
                    },
                    onSelectEntry: { entry in
                        handleSelectEntry(entry)
                    }
                )
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)

                rightPanel
                    .frame(minWidth: 340, idealWidth: 400)
            }
            .clipped(antialiased: false)
            .frame(minWidth: 580, minHeight: 420)
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .alert("Unsaved Changes", isPresented: $isShowingDiscardAlert) {
            Button("Discard", role: .destructive) {
                executePendingAction()
            }
            Button("Keep Editing", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }

    // MARK: - Has Actual Changes

    private func hasActualChanges() -> Bool {
        return !snapshotText.isEmpty || !snapshotKey.isEmpty
    }

    // MARK: - Navigation Handlers

    private func handleNewShortcut() {
        if isShowingNewShortcut && hasActualChanges() {
            pendingAction = .newShortcut
            isShowingDiscardAlert = true
        } else {
            showNewShortcut()
        }
    }

    private func handleSelectEntry(_ entry: PasteKeyEntry) {
        if isShowingNewShortcut && hasActualChanges() {
            pendingAction = .selectEntry(entry)
            isShowingDiscardAlert = true
        } else {
            showEntry(entry)
        }
    }

    private func executePendingAction() {
        guard let action = pendingAction else { return }
        resetSnapshot()
        switch action {
        case .newShortcut:
            showNewShortcut()
        case .selectEntry(let entry):
            showEntry(entry)
        case .quit:
            NSApp.terminate(nil)
        }
        pendingAction = nil
    }

    private func showNewShortcut() {
        entryToEdit = nil
        resetSnapshot()
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingNewShortcut = true
            selectedEntry = nil
        }
    }

    private func showEntry(_ entry: PasteKeyEntry) {
        resetSnapshot()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedEntry = entry
            isShowingNewShortcut = false
            entryToEdit = nil
        }
    }

    private func resetSnapshot() {
        snapshotText = ""
        snapshotKey = ""
        snapshotModifiers = []
    }

    func confirmQuitIfNeeded() {
        if isShowingNewShortcut && hasActualChanges() {
            pendingAction = .quit
            isShowingDiscardAlert = true
        } else {
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))

            Text("Accessibility access is required for shortcuts to work.")
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                AccessibilityPermission.shared.openSystemSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Right Panel

    @ViewBuilder
    private var rightPanel: some View {
        if isShowingNewShortcut {
            NewShortcutPanel(
                store: store,
                entryToEdit: entryToEdit,
                onSave: { savedEntry in
                    isShowingNewShortcut = false
                    entryToEdit = nil
                    selectedEntry = savedEntry
                    resetSnapshot()
                },
                onCancel: {
                    isShowingNewShortcut = false
                    entryToEdit = nil
                    resetSnapshot()
                },
                onChanged: { text, key, modifiers in
                    snapshotText = text
                    snapshotKey = key
                    snapshotModifiers = modifiers
                }
            )

            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
        } else if let entry = selectedEntry,
                  let liveEntry = store.entries.first(where: { $0.id == entry.id }) {
            DetailCardView(
                entry: liveEntry,
                onEdit: {
                    entryToEdit = liveEntry
                    isShowingNewShortcut = true
                },
                onDelete: {
                    store.delete(liveEntry)
                    selectedEntry = nil
                }
            )
            .transition(.opacity)
            .id(liveEntry.id)
        } else {
            placeholderPanel
                .transition(.opacity)
        }
    }

    // MARK: - Placeholder

    private var placeholderPanel: some View {
        Group {
            if store.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)

                    Text("No shortcuts yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            handleNewShortcut()
                        } label: {
                            Label("New Shortcut", systemImage: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 110)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button {
                            NotificationCenter.default.post(name: .pasteKeyOpenSettings, object: nil)
                        } label: {
                            Label("Open Settings", systemImage: "gearshape")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 110)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Text("Import shortcuts from a .pastekey file via Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)

                    Text("Select a shortcut to view details")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.clear)
    }
}

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {

    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    MainWindowView(store: .preview)
        .frame(width: 680, height: 460)
}

#Preview("Empty") {
    MainWindowView(store: .empty)
        .frame(width: 680, height: 460)
}
#endif
