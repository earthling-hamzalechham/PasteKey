//
//  PasteKeyApp.swift
//  PasteKey
//
//  Created by hamza lechham on 14/3/2026.
//

import SwiftUI
import AppKit

@main
struct PasteKeyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ShortcutStore()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

    init() {
        // Inject store immediately at init time, before applicationDidFinishLaunching fires
        let store = ShortcutStore()
        _store = StateObject(wrappedValue: store)
        appDelegate.configure(store: store)    }
}
