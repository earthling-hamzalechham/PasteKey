//
//  OnboardingView.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

// MARK: - OnboardingView

struct OnboardingView: View {

    // MARK: Properties

    @ObservedObject var store: ShortcutStore
    let onComplete: () -> Void

    @ObservedObject private var permission = AccessibilityPermission.shared
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: CGFloat = 0
    @State private var hasAnimatedCompletion = false

    // MARK: - Body

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if permission.isGranted {
                    grantedView
                } else {
                    requestView
                }
            }
            .padding(40)
        }
        .frame(width: 520, height: 420)
        .onChange(of: permission.isGranted) { oldValue, newValue in
            if newValue && !hasAnimatedCompletion {
                animateCompletion()
            }
        }
    }

    // MARK: - Request View

    private var requestView: some View {
        VStack(spacing: 0) {

            // App icon area
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.bottom, 24)

            // Title
            Text("Welcome to PasteKey")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            // Subtitle
            Text("PasteKey needs one permission to work.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Permission explanation card
            permissionCard
                .padding(.bottom, 32)

            // Action buttons
            VStack(spacing: 12) {

                // Primary action
                Button {
                    permission.openSystemSettings()
                } label: {
                    Text("Open System Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Force restart engine after granting
                Button {
                    NotificationCenter.default.post(
                        name: .pasteKeyForceRestartEngine,
                        object: nil
                    )
                    print("[OnboardingView] Force restart engine tapped")
                    print("[OnboardingView] AXIsProcessTrusted = \(AXIsProcessTrusted())")
                } label: {
                    Text("I've granted access — Start Engine")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Waiting indicator
            if !permission.isGranted {
                waitingIndicator
            }
        }
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("Accessibility Access")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Required to intercept keyboard shortcuts system-wide. PasteKey uses this only to detect your assigned key combos — it never reads, logs, or transmits your keystrokes.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Waiting Indicator

    private var waitingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(.circular)

            Text("Waiting for permission in System Settings…")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Granted View

    private var grantedView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }
            .padding(.bottom, 28)

            Text("You're all set!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .opacity(checkmarkOpacity)
                .padding(.bottom, 8)

            Text("PasteKey is ready. Create your first shortcut\nfrom the menu bar icon.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(checkmarkOpacity)
                .padding(.bottom, 40)

            Button {
                onComplete()
                NSApp.keyWindow?.close()
            } label: {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .opacity(checkmarkOpacity)

            Spacer()
        }
    }

    // MARK: - Completion Animation

    private func animateCompletion() {
        hasAnimatedCompletion = true

        withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
            checkmarkScale = 1.0
        }

        withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
            checkmarkOpacity = 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Requesting") {
    OnboardingView(store: .preview, onComplete: {})
}
#endif
