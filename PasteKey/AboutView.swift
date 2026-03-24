//
//  AboutView.swift
//  PasteKey
//
//  Created by hamza lechham on 18/3/2026.
//

import SwiftUI
import AppKit

// MARK: - AboutView

struct AboutView: View {

    var body: some View {
        VStack(spacing: 0) {
            // App icon
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 16)
            }

            // App name + version
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PasteKey")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text("1.0")
                    .font(.system(size: 13).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 20)

            // Info rows
            VStack(spacing: 12) {
                infoRow(label: "Created by", value: "Hamza Lechham")

                infoRow(label: "Contact", value: "hamzalechham@gmail.com", isEmail: true)

                infoRow(label: "Year", value: "2026")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 32)
        .frame(width: 340, height: 300)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String, isEmail: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)

            if isEmail {
                Button {
                    if let url = URL(string: "mailto:\(value)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AboutView()
}
#endif
