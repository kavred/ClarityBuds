# ClarityBuds
![macOS](https://img.shields.io/badge/OS-macOS_14.0%2B-black?style=flat-square&logo=apple)

**Give any headphones AirPods-style Transparency Mode on macOS.**

ClarityBuds is a lightweight, native **macOS-only** menu bar utility that captures audio from your Mac's microphone and routes it through your headphones in real-time — letting you hear the world around you while still enjoying your music, podcasts, or calls.

---

## How It Works

```
🎤 Microphone ──→ [AVAudioEngine] ──→ 🎧 Headphones
                                         ↑
🎵 System Audio ─────────────────────────┘
```

> [!WARNING]
> **Bluetooth Hardware Limitations:**
> This software routes audio through your Mac. Standard Bluetooth headphones inherently buffer their audio, creating a physical, inescapable delay of ~150-250ms that software cannot bypass. **Do not expect real-time zero-latency AirPods Pro quality from standard Bluetooth headphones.** For instantaneous real-time transparency, you MUST use wired headphones or a 2.4GHz wireless dongle.

Your system audio (music, videos, calls) plays normally through your headphones. ClarityBuds **adds** your microphone's ambient sound on top, so you can hear conversations, announcements, traffic, and the world around you — without removing your headphones.

## Features

- **One-Click Toggle** — Enable/disable with a single click or keyboard shortcut
- **Menu Bar App** — Lives unobtrusively in your macOS status bar (no Dock icon)
- **Ambient Volume Control** — Adjust passthrough volume from 0% to 150%
- **Device Selection** — Choose any input mic and output device
- **Global Keyboard Shortcut** — Toggle with `⌥⇧T` (Option + Shift + T) from anywhere
- **Device Detection** — Automatically discovers Bluetooth, USB, and built-in audio devices
- **Feedback Prevention** — Warns you if input and output are the same device
- **Launch at Login** — Start automatically when your Mac boots
- **Low Latency** — Typically 5–20ms delay using Apple's AVAudioEngine

## Requirements

- **macOS 14.0** (Sonoma) or later
- A working microphone (built-in or external)
- Headphones (Bluetooth, USB, or wired)

## Installation

### Option 1: Build from Source (Recommended)

**Prerequisites:** Xcode 15+ or Swift 5.9+ command line tools

```bash
# Clone the repo
git clone https://github.com/kavred/ClarityBuds.git
cd ClarityBuds

# Run the automated build & install script
./build_app.sh
```

The script will automatically compile the app, bundle it properly, and install it directly to your `/Applications` folder!

**Or open in Xcode:**

```bash
# Generate Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate
open ClarityBuds.xcodeproj
```

Then press `⌘R` to build and run.

### Option 2: Download Pre-built Binary

Check the [Releases](https://github.com/kavred/ClarityBuds/releases/latest) page for pre-built binaries. Note: since this app is not signed with a paid Apple Developer certificate, macOS Gatekeeper protects you by stopping it from launching immediately.

**To install from GitHub:**
1. Download `ClarityBudsRelease.zip` from the Releases page.
2. Double-click the `.zip` file in your Downloads folder to extract it.
3. Drag `ClarityBuds.app` directly into your **Applications** folder.
4. **Bypass Apple Gatekeeper:** Because this app is open-source and not signed with a paid Apple Developer certificate, macOS will quarantine the downloaded file. When you try to open it, macOS will falsely claim the app is *"damaged and should be moved to the Trash"*. This is normal for unsigned apps. To fix it, open Apple's **Terminal** app and paste this exact command to remove the quarantine:
   ```bash
   xattr -cr /Applications/ClarityBuds.app
   ```
5. You can now double-click and launch ClarityBuds normally from your Applications folder!

## Usage

1. **Click** the 👂 ear icon in your menu bar
2. **Select** your input device (microphone) and output device (headphones)
3. **Click** "Passthrough Off" to turn it on
4. **Adjust** the ambient volume slider to your preference
5. **Use** `⌥⇧T` to quickly toggle from anywhere

### Tips

- **Use with Bluetooth headphones** for the best experience — your Mac's built-in mic captures ambient sound while audio plays through your wireless headphones
- **Lower the volume** if the ambient sound is too loud or causes discomfort
- **Select "System Default"** for devices to automatically follow your macOS audio settings

## Project Structure

```
ClarityBuds/
├── Package.swift                          # Swift Package Manager config
├── project.yml                            # XcodeGen project specification
├── ClarityBuds/
│   ├── ClarityBudsApp.swift               # @main app entry (MenuBarExtra)
│   ├── Info.plist                         # App metadata & permissions
│   ├── ClarityBuds.entitlements           # Audio input entitlement
│   ├── Audio/
│   │   ├── AudioEngine.swift              # Core AVAudioEngine passthrough
│   │   └── DeviceManager.swift            # Audio device enumeration & monitoring
│   ├── Views/
│   │   ├── MenuBarView.swift              # Main popover UI
│   │   └── SettingsView.swift             # Preferences window
│   ├── Models/
│   │   └── AppState.swift                 # Observable app state & persistence
│   └── Utilities/
│       ├── Permissions.swift              # Microphone permission handling
│       ├── KeyboardShortcut.swift          # Global hotkey (Carbon Events)
│       └── LaunchAtLogin.swift            # SMAppService login item
└── README.md
```

## Technical Details

### Audio Pipeline

The app uses Apple's `AVAudioEngine` to create a minimal-latency audio graph:

```
InputNode (Mic) ──→ MainMixerNode ──→ OutputNode (Headphones)
                        ↑
                  Volume Control
```

- **No audio taps** — Direct node connection for minimum latency
- **No audio processing** — Raw passthrough for clarity
- **Core Audio device management** — Direct `AudioObject` API for device enumeration and change monitoring
- **Matched sample rates** — Input/output formats are negotiated by AVAudioEngine

### Latency

Typical processing latency is **~1.5ms** due to our aggressive 64-frame Core Audio hardware buffer optimization. However, your *total* latency depends entirely on your audio devices:
- Built-in mic + wired headphones: **~3–5ms** (Flawless real-time transparency)
- Built-in mic + USB audio interface: **~3–10ms**
- Built-in mic + Bluetooth headphones: **~150–250ms** (due to physical A2DP Bluetooth encoding/decoding)

### Troubleshooting Bluetooth Latency

If you are experiencing severe vocal delay or echoes while using Bluetooth, it is likely macOS software adding hidden processing. Try these two critical fixes:

1. **Disable "Voice Isolation" Mic Mode** 
   macOS 12+ has a "Voice Isolation" feature that uses machine learning to filter background noise, adding massive software latency. While ClarityBuds is on, click the orange microphone icon in your Mac's top right menu bar (Control Center) and ensure the mode is set to **Standard**.
2. **Match Sample Rates in Audio MIDI Setup** 
   If your microphone records at 48kHz but your headphones output at 44.1kHz, macOS buffers the audio to do hidden sample-rate math. Open the built-in macOS **Audio MIDI Setup** app and ensure your Mic and your Headphones are set to the exact same frequency rate (e.g. `48,000 Hz`).

## Known Limitations

- **Not zero-latency** — Software passthrough has inherent delay (unlike AirPods Pro hardware transparency)
- **Requires separate I/O devices** — Input and output must be different devices to prevent feedback
- **Not signed with Apple Developer ID** — macOS Gatekeeper will require right-click → Open on first launch
- **macOS only** — No iOS/iPadOS support (they lack the necessary audio routing APIs)

## Distribution Note

This app is distributed **unsigned** (no paid Apple Developer account). This means:
- ✅ Fully functional — no features are restricted
- ✅ Can be built from source by anyone
- ⚠️ Gatekeeper will show a warning on first launch (right-click → Open to bypass)
- ❌ Cannot be distributed via the Mac App Store

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

## Acknowledgments

- Inspired by Apple's AirPods Pro Transparency Mode
- Built with [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) and [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Project structure generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
