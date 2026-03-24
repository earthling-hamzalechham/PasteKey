//
//  DetailCardView.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

// MARK: - DetailCardView

struct DetailCardView: View {

    // MARK: Properties

    let entry: PasteKeyEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isShowingDeleteConfirmation = false
    @State private var isCopied = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    Divider()
                        .padding(.vertical, 16)
                    textSection
                    // Bottom padding so content doesn't hide behind sticky buttons
                    Spacer()
                        .frame(height: 80)
                }
                .padding(24)
            }

            // Sticky bottom bar
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(NSColor.windowBackgroundColor).opacity(0.7),
                        Color(NSColor.windowBackgroundColor)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)

                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.2, green: 0.2, blue: 0.2))     .controlSize(.large)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(height: 120)
        }
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .confirmationDialog(
            "Delete this shortcut?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This shortcut will be permanently removed. This action cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {

            // Large shortcut badge
            Text(entry.displayShortcut)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.textPreview)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Created \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Paste content")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                Spacer()

                // Copy to clipboard button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCopied = false
                        }
                    }
                } label: {
                    Label(
                        isCopied ? "Copied!" : "Copy",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isCopied)
            }

            // Full text display
            ScrollView {
                Text(entry.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )

            // Character count
            HStack {
                Spacer()
                Text("\(entry.text.count) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DetailCardView(
        entry: PasteKeyEntry.sampleEntries[0],
        onEdit: {},
        onDelete: {}
    )
    .frame(width: 400, height: 460)
}

#Preview("Long text") {
    DetailCardView(
        entry: PasteKeyEntry(
            text: "This message and any attachments are confidential and intended solely for the use of the individual or entity to whom they are addressed.",
            shortcutKey: "l",
            modifiers: [.command, .option]
        ),
        onEdit: {},
        onDelete: {}
    )
    .frame(width: 400, height: 460)
}
#endif
