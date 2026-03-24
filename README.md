<img width="150" height="150" alt="PasteKey" src="https://github.com/user-attachments/assets/7b6b4f39-295b-4fad-91ce-6affcb732733" />

# PasteKey
**Custom text paste shortcuts for macOS.**

PasteKey is a lightweight menu bar utility that lets you create keyboard shortcuts that instantly paste any block of text into any app — emails, code snippets, addresses, support replies — with a single key combo.

It lives quietly in the menu bar, requires no cloud account, and works system-wide in every app on your Mac.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black) ![Version](https://img.shields.io/badge/version-1.0-blue) ![License](https://img.shields.io/badge/license-MIT-green)

<img width="735" height="522" alt="Preview1" src="https://github.com/user-attachments/assets/63d9e929-939d-469a-b2ce-33af29c987a4" />
<img width="735" height="431" alt="Preview2" src="https://github.com/user-attachments/assets/5572b47e-ccbf-4c60-a4e2-79a7e23e861d" />

---

## Why PasteKey

macOS has built-in text replacement, but it only works in apps that support `NSTextView`, has no keyboard shortcut support, and can't be paused. PasteKey solves all of this with a proper first-class UI and true system-wide interception.

---

## Features

- **Unlimited shortcuts** — create as many shortcut–text pairs as you need
- **Works everywhere** — Slack, Mail, Chrome, Terminal, Figma, any app
- **Instant paste** — text appears at the cursor with no delay
- **Clipboard safe** — your clipboard contents are preserved after every paste
- **Pause & resume** — suspend all shortcuts with one click when needed
- **Fully private** — no cloud, no analytics, no account, all data stays on your Mac
- **Export & import** — back up or share your shortcuts as a `.pastekey` file
- **Launch at login** — optionally start PasteKey automatically on login
- **Native macOS design** — frosted glass, SF Symbols, Dark Mode, Dynamic Type

---

## Installation

### Option A — Download (recommended for most users)
1. To download `PasteKey-1.0.dmg` [Click here](https://github.com/earthling-hamzalechham/PasteKey/releases/download/1.0-stable/PasteKey-1.0.dmg)
2. Open the DMG and drag PasteKey to your Applications folder
3. Launch PasteKey from Applications

> **First launch note:** macOS may show a security warning since PasteKey is not notarised yet. Go to System Settings > Privacy & Security, scroll down to the "Security" section, and click "Open Anyway" next to the blocked PasteKey app message.
> 
### Option B — Build from source
1. Clone the repository
2. Open `PasteKey.xcodeproj` in Xcode 15 or later
3. Select your development team in **Signing & Capabilities**
4. Build and run (`⌘R`)

No external dependencies — the project uses Apple frameworks only.

---

## Getting Started

1. On first launch, grant **Accessibility access** when prompted — this is required for system-wide key interception
2. Click the keyboard icon in your menu bar → **Open Main Window**
3. Click **+** to create your first shortcut
4. Press your desired key combo (e.g. `⌘⌥E`)
5. Type the text you want it to paste
6. Click **Save** — your shortcut is now active in every app

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

- macOS 14 Sonoma or later
- Apple Silicon or Intel
- Accessibility permission (guided on first launch)

---

## Privacy

PasteKey requires one permission — **Accessibility** — to intercept keyboard shortcuts system-wide. It uses this exclusively to detect your assigned key combos. It never reads, logs, stores, or transmits your keystrokes or any other data. All shortcut data is stored locally in `UserDefaults` and never leaves your Mac.

Your clipboard is also fully protected — PasteKey saves and restores whatever you had copied before triggering a shortcut, so nothing is lost.

> **Note:** Do not store sensitive information such as passwords, personal identification numbers, confidential client data, or any credentials as shortcut text. PasteKey is designed for repetitive non-sensitive text — templates, signatures, standard replies, and similar content.

---

## Export & Import

Back up or share your shortcuts via **Settings → Export Shortcuts**. This saves a `.pastekey` file (plain JSON) that can be imported on any Mac running PasteKey via **Settings → Import Shortcuts**.

---

## Security & Technical Notes

> PasteKey was developed with the assistance of [Claude](https://claude.ai) by Anthropic and has been iteratively reviewed and hardened. Full source code is available for inspection.

**How it works:**
- Registers a `CGEventTap` at `.cgSessionEventTap` to intercept `keyDown` events system-wide
- On a matching shortcut: writes predefined text to `NSPasteboard`, simulates `Cmd+V` via `CGEvent`, then restores the previous clipboard contents
- Listens for Accessibility permission changes via `DistributedNotificationCenter` (`com.apple.accessibility.api`) to start and stop the tap cleanly without freezing
- All shortcuts persisted locally via `UserDefaults` — no file system writes outside the app container, no network calls

**What it does not do:**
- ❌ No network requests — zero outbound connections
- ❌ No keylogging — only reacts to shortcuts you explicitly define
- ❌ No telemetry or analytics of any kind
- ❌ No data stored outside `UserDefaults` on the local machine
- ❌ No background daemons or launch agents beyond the menu bar process

**Permission used:**

| Permission | Why |
|---|---|
| Accessibility | Required by macOS to intercept keyboard events system-wide via `CGEventTap` |

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
