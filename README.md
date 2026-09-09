# XcodeRunBar

> Run and stop your Xcode project from menu bar

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

> **⚠️ Gatekeeper Warning**  
> XcodeRunBar is not notarized by Apple (requires a paid Apple Developer account).  
> After installing, you must remove the quarantine flag manually — see [Installation](#installation).

---

## Overview

XcodeRunBar is a lightweight macOS menu bar app that lets you run and stop your Xcode project without switching windows.

Designed for developers who work primarily in the terminal or with AI coding agents (Claude Code, Cursor, etc.) and want to trigger Xcode builds without breaking their flow.

```
Write code in terminal
       ↓
Click ▶ in menu bar
       ↓
Xcode runs — no window switching needed
```

| Xcode open | No Xcode |
|:---:|:---:|
| ![active](assets/active.png) | ![inactive](assets/inactive.png) |

---

## Features

- **Two-click control** — dedicated ▶ and ■ icons in your menu bar
- **Auto-detection** — finds your running Xcode and open projects automatically
- **Multi-project support** — dropdown to select which project to run/stop when multiple are open
- **Zero configuration** — just launch and it works
- **Update checker** — checks for new releases from the menu

---

## Requirements

- macOS 13.0 or later
- Xcode installed and open with a project

---

## Installation

### Manual

1. Download the latest `XcodeRunBar.dmg` from [Releases](https://github.com/w-dev-ayne/XcodeRunBar/releases)
2. Open the DMG and drag **XcodeRunBar.app** to your Applications folder
3. Remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/XcodeRunBar.app
```

4. Launch **XcodeRunBar** from Applications

---

## Usage

Once running, three icons appear in your menu bar:

| Icon | Action |
|---|---|
| 🔨 | App info — Contact, Check for Updates, Quit |
| ■ | Stop the current Xcode project |
| ▶ | Run the current Xcode project |

**Single project open** — clicking ▶ or ■ acts immediately  
**Multiple projects open** — clicking shows a dropdown to pick which one

### First Launch

On first use, macOS will ask for permission to control Xcode. Click **Allow** — this is required for the app to work.

---

## How It Works

XcodeRunBar uses **AppleScript** to communicate with Xcode directly:

```applescript
tell application "Xcode"
    run workspace document 1
end tell
```

This means it respects your current Xcode state — active scheme, selected simulator, connected device — exactly as if you clicked the Run button yourself.

---

## Permissions

- **Accessibility** — not required
- **Apple Events (Automation)** — required to control Xcode

No network access, no file system access beyond what macOS grants by default.

---

## Contact

Questions or feedback → [w.dev.ayne@gmail.com](mailto:w.dev.ayne@gmail.com)

---

## License

MIT
