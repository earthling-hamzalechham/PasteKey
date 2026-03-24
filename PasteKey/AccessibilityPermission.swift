//
//  AccessibilityPermission.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import Foundation
import AppKit
import Combine

// MARK: - AccessibilityPermission

final class AccessibilityPermission: ObservableObject {

    // MARK: - Shared Instance

    static let shared = AccessibilityPermission()

    // MARK: - Published State

    @Published var isGranted: Bool = false

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var onboardingTimer: Timer?
    private let onboardingPollInterval: TimeInterval = 2.0
    private let onboardingPollDuration: TimeInterval = 60.0
    private var onboardingPollStart: Date?

    // MARK: - Init

    private init() {
        registerSilently()
        isGranted = AXIsProcessTrusted()
        observeAppActivation()
    }

    // MARK: - Silent Registration

    private func registerSilently() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - App Activation Observer

    private func observeAppActivation() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkPermission()
            }
            .store(in: &cancellables)
    }

    // MARK: - Permission Check

    func checkPermission() {
        let granted = AXIsProcessTrusted()
        if granted != isGranted {
            isGranted = granted
        }
        if granted {
            stopOnboardingPoll()
        }
    }

    // MARK: - Open System Settings
    // Called when user taps "Open Settings" from the permission banner.
    // Starts a short-lived poll so the banner clears automatically
    // once permission is granted, without needing to refocus the app.

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startOnboardingPoll()
    }

    // MARK: - Called by HotkeyEngine when tap creation fails

    func handleTapFailure() {
        checkPermission()
    }

    // MARK: - Onboarding Poll

    private func startOnboardingPoll() {
        guard onboardingTimer == nil else { return }
        onboardingPollStart = Date()

        onboardingTimer = Timer.scheduledTimer(
            withTimeInterval: onboardingPollInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }

            // Stop after max duration to avoid running forever
            if let start = self.onboardingPollStart,
               Date().timeIntervalSince(start) > self.onboardingPollDuration {
                self.stopOnboardingPoll()
                return
            }

            self.checkPermission()
        }
        RunLoop.main.add(onboardingTimer!, forMode: .common)
    }

    private func stopOnboardingPoll() {
        onboardingTimer?.invalidate()
        onboardingTimer = nil
        onboardingPollStart = nil
    }
}
