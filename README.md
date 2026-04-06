# ClarityBuds

**Give any headphones AirPods-style Transparency Mode on macOS.**

ClarityBuds is a lightweight, native macOS menu bar utility that captures audio from your Mac's microphone and routes it through your headphones in real-time — letting you hear the world around you while still enjoying your music, podcasts, or calls.

---

## How It Works

```
🎤 Microphone ──→ [AVAudioEngine] ──→ 🎧 Headphones
                                         ↑
🎵 System Audio ─────────────────────────┘
```

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
git clone https://github.com/YOUR_USERNAME/Transparency-App.git
cd Transparency-App

# Build with Swift Package Manager
swift build -c release

# The binary is at:
# .build/release/ClarityBuds
```

**Or open in Xcode:**

```bash
# Generate Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate
open ClarityBuds.xcodeproj
```

Then press `⌘R` to build and run.

### Option 2: Download Pre-built Binary

Check the [Releases](../../releases/latest) page for pre-built binaries. Note: since this app is not signed with a paid Apple Developer certificate, macOS Gatekeeper will block it by default.

**To run an unsigned app:**
1. Download `ClarityBuds.zip` from Releases
2. Unzip and move to your Applications folder
3. Right-click (or Control-click) the app and select **Open**
4. Click **Open** in the dialog that appears
5. The app will now run and be remembered for future launches

> **Note:** You only need to do the right-click → Open step once. After that, the app launches normally.

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
Transparency-App/
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

Typical latency is **5–20ms** depending on your hardware:
- Built-in mic + Bluetooth headphones: ~15–25ms
- Built-in mic + wired headphones: ~5–15ms
- USB audio interface: ~3–10ms

This is generally imperceptible for ambient awareness.

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
