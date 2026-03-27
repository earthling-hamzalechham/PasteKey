//
//  PlaceholderExplainerWindow.swift
//  PasteKey
//
//  Created by hamza lechham on 24/3/2026.
//

import SwiftUI
import AppKit

// MARK: - PlaceholderExplainerView

struct PlaceholderExplainerView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "curlybraces")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Dynamic Placeholders")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Fill in values at paste time")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.bottom, 20)

            // How to write them
            sectionHeader("Syntax")
            exampleCard("Hi {firstName}, your ticket #{ticketId} is resolved.")
                .padding(.bottom, 6)
            Text("Wrap any word in { } to make it a placeholder. Each unique name gets its own input field when you trigger the shortcut.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            Divider()
                .padding(.bottom, 20)

            // Rules
            sectionHeader("Rules")
            VStack(alignment: .leading, spacing: 7) {
                ruleRow(icon: "checkmark.circle.fill", color: .green,
                        text: "Letters, numbers, underscores only — {first_name}")
                ruleRow(icon: "checkmark.circle.fill", color: .green,
                        text: "Same placeholder used twice is asked once")
                ruleRow(icon: "checkmark.circle.fill", color: .green,
                        text: "{Name} and {name} are treated as the same field")
                ruleRow(icon: "xmark.circle.fill", color: .red,
                        text: "Spaces inside braces are not supported")
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.bottom, 20)

            // Tip
            sectionHeader("Pro tip")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .padding(.top, 1)
                Text("Copy relevant information before triggering the shortcut. Your last 5 copied texts appear as suggestions in each field so you can fill them in with one click.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 460, height: 500)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.bottom, 8)
    }

    private func exampleCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5)
            )
    }

    private func ruleRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PlaceholderExplainerView()
}
#endif
