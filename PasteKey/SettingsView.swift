//
//  SettingsView.swift
//  PasteKey
//
//  Created by hamza lechham on 17/3/2026.
//

import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - PasteKey File Type

extension UTType {
    static let pastekeyFile = UTType(exportedAs: "com.earthling.pastekey.shortcuts")
}

// MARK: - SettingsView

struct SettingsView: View {

    @ObservedObject var store: ShortcutStore
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var errorMessage: String? = nil
    @State private var isShowingImportConfirmation = false
    @State private var pendingImportURL: URL? = nil
    @State private var isShowingClearConfirmation = false


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            generalSection
            Divider()
            dataSection
            Spacer()
        }
        .frame(width: 420, height: 380)
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .fileExporter(
            isPresented: $isExporting,
            document: PasteKeyDocument(store: store),
            contentType: .pastekeyFile,
            defaultFilename: "PasteKey Shortcuts"
        ) { result in
            switch result {
            case .success:
                showExportSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showExportSuccess = false
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pastekeyFile, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Import Shortcuts?",
            isPresented: $isShowingImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Import and Merge", role: .destructive) {
                isImporting = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(store.entries.count) existing shortcut\(store.entries.count == 1 ? "" : "s"). Imported shortcuts with the same key combo will replace them. Your other shortcuts will be kept.")
        }
        .alert("Import Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        
        // Reset Confirmation Dialog
        .confirmationDialog(
            "Delete All Shortcuts?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                store.entries.removeAll()
                store.save()
                // Close settings sheet and reset main window selection
                if let sheet = NSApp.keyWindow {
                    NSApp.mainWindow?.endSheet(sheet)
                }
                NotificationCenter.default.post(name: .pasteKeyClearSelection, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. All \(store.entries.count) saved shortcut\(store.entries.count == 1 ? "" : "s") will be permanently deleted.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(24)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("General")

            settingsRow(
                icon: "power",
                title: "Launch at Login",
                description: "Automatically start PasteKey when you log in",
                toggle: $launchAtLogin
            ) { enabled in
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Shortcuts Data")

            // Export row
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Shortcuts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Save all shortcuts to a .pastekey file")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if showExportSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text("Exported")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                } else {
                    Button("Export") {
                        isExporting = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.entries.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color.primary.opacity(0.06)),
                alignment: .bottom
            )

            // Import row
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Shortcuts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Load shortcuts from a .pastekey file")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if showImportSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text("\(importedCount) imported")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                } else {
                    Button("Import") {
                        if store.entries.isEmpty {
                            isImporting = true
                        } else {
                            isShowingImportConfirmation = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))
            
            // Reset
            Divider()

            HStack(spacing: 14) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear All Shortcuts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Permanently delete all saved shortcuts")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Clear All") {
                    isShowingClearConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))
            
        }
    }

    // MARK: - Reusable Components

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    private func settingsRow(
        icon: String,
        title: String,
        description: String,
        toggle: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: toggle)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: toggle.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.primary.opacity(0.06)),
            alignment: .bottom
        )
    }

    // MARK: - Import Logic

    private func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            // Count how many entries are in the file being imported
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let incoming = try decoder.decode([PasteKeyEntry].self, from: data)
            try store.importJSON(data)
            importedCount = incoming.count
            showImportSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showImportSuccess = false
            }
        } catch {
            errorMessage = "Could not read the file. Make sure it's a valid .pastekey file."
        }
    }
}

// MARK: - PasteKeyDocument (for fileExporter)

struct PasteKeyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pastekeyFile, .json] }

    var store: ShortcutStore

    init(store: ShortcutStore) {
        self.store = store
    }

    init(configuration: ReadConfiguration) throws {
        store = ShortcutStore()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try store.exportJSON()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView(store: .preview)
}
#endif
