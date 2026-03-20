<img width="150" height="150" alt="PasteKey" src="https://github.com/user-attachments/assets/7b6b4f39-295b-4fad-91ce-6affcb732733" />

# PasteKey

**Custom text paste shortcuts for macOS.**

PasteKey is a lightweight menu bar utility that lets you create keyboard shortcuts that instantly paste any block of text into any app — emails, code snippets, addresses, support replies — with a single key combo.

It lives quietly in the menu bar, requires no cloud account, and works system-wide in every app on your Mac.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black) ![Version](https://img.shields.io/badge/version-1.0-blue) ![License](https://img.shields.io/badge/license-MIT-green)

<img width="792" height="612" alt="Screenshot 2026-03-20 at 21 51 06" src="https://github.com/user-attachments/assets/b30cb32c-861a-4290-bed8-ecca146d9272" />
<img width="735" height="544" alt="Preview2" src="https://github.com/user-attachments/assets/8c0d7cb2-d3b6-4369-b138-dc3cb8b9adba" />

---

## Why PasteKey

macOS has built-in text replacement, but it only works in apps that support `NSTextView`, has no keyboard shortcut support, and can't be paused. PasteKey solves all of this with a proper first-class UI and true system-wide interception.

---

## Features

- **Unlimited shortcuts** — create as many shortcut–text pairs as you need
- **Works everywhere** — Slack, Mail, Chrome, Terminal, Figma, any app
- **Instant paste** — text appears at the cursor with no delay
- **Pause & resume** — suspend all shortcuts with one click when needed
- **Fully private** — no cloud, no analytics, no account, all data stays on your Mac
- **Export & import** — back up or share your shortcuts as a `.pastekey` file
- **Launch at login** — optionally start PasteKey automatically on login
- **Native macOS design** — frosted glass, SF Symbols, Dark Mode, Dynamic Type

---

## Installation

1. Download `PasteKey-1.0.dmg` from the [latest release](https://github.com/earthling-hamzalechham/PasteKey/releases/latest)
2. Open the DMG and drag PasteKey to your Applications folder
3. Launch PasteKey from Applications

> **First launch note:** macOS may show a security warning since PasteKey is not notarised yet. Go to System Settings > Privacy & Security, scroll down to the "Security" section, and click "Open Anyway" next to the blocked PasteKey app message.

---

## Getting Started

1. On first launch, grant **Accessibility access** when prompted — this is required for system-wide key interception
2. Click **+** to create your first shortcut
3. Press your desired key combo (e.g. `⌘⌥E`)
4. Type the text you want it to paste
5. Click **Save** — your shortcut is now active in every app

---

## Recommended Shortcut Combos

To avoid conflicts with normal typing, use at least `⌘` or `⌃` in your combo:

| ✅ Safe | ❌ Avoid |
|--------|---------|
| `⌘ + key` | `⌥ + key` |
| `⌃ + key` | `⇧ + key` |
| `⌘⌥ + key` | `⌥⇧ + key` |
| `⌘⇧ + key` | |
| `⌘⌃ + key` | |

---

## Requirements

- macOS 14 Ventura or later
- Apple Silicon or Intel (universal binary)
- Accessibility permission (guided on first launch)

---

## Privacy

PasteKey requires one permission — **Accessibility** — to intercept keyboard shortcuts system-wide. It uses this exclusively to detect your assigned key combos. It never reads, logs, stores, or transmits your keystrokes or any other data. All shortcut data is stored locally on your Mac and never leaves it.

---

## Export & Import

You can back up or share your shortcuts via **Settings → Export Shortcuts**. This saves a `.pastekey` file (plain JSON) that can be imported on any Mac running PasteKey via **Settings → Import Shortcuts**.

---

## Built With

- Swift & SwiftUI
- AppKit (NSStatusItem, NSPopover, NSWindow)
- CoreGraphics (CGEventTap for system-wide key interception)
- ServiceManagement (Launch at Login)
- Developed with the assistance of [Claude](https://claude.ai) by Anthropic

---

## License

MIT License — see [LICENSE](LICENSE) for details.

© 2026 Hamza Lechham
