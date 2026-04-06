import SwiftUI
@preconcurrency import UserNotifications

/// The main entry point for ClarityBuds.
/// This is a menu bar-only app (no Dock icon, no main window).
@main
struct ClarityBudsApp: App {

    @State private var appState = AppState()
    @State private var deviceManager = DeviceManager()
    @State private var audioEngine = AudioPassthroughEngine()
    @State private var showSettings = false

    var body: some Scene {
        // Menu Bar Extra — the entire app lives here
        MenuBarExtra {
            VStack(spacing: 0) {
                MenuBarView(
                    appState: appState,
                    deviceManager: deviceManager,
                    audioEngine: audioEngine,
                    onToggle: { /* toggle handled internally */ },
                    onQuit: {
                        audioEngine.stop()
                        GlobalShortcutManager.shared.unregister()
                        NSApplication.shared.terminate(nil)
                    }
                )

                Divider()

                // Settings Button
                Button {
                    showSettings = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Settings...")
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        } label: {
            // Menu bar icon — changes based on active state
            Image(systemName: appState.isPassthroughActive ? "ear.fill" : "ear")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Window("Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    init() {
        // Show startup notification
        showStartupNotification()

        // Register the global keyboard shortcut on launch
        setupGlobalShortcut()
    }

    // MARK: - Startup Notification

    private func showStartupNotification() {
        // Request notification permission and send startup alert
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                // Fall back to terminal message
                print("✅ ClarityBuds is running! Look for the 👂 ear icon in your menu bar.")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "ClarityBuds is Running"
            content.body = "Look for the 👂 ear icon in your menu bar. Press ⌥⇧T to toggle passthrough."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "claritybuds-startup",
                content: content,
                trigger: nil  // Deliver immediately
            )

            center.add(request) { error in
                if let error = error {
                    print("[ClarityBuds] Notification error: \(error.localizedDescription)")
                }
            }
        }

        // Always print to terminal too
        print("""
        ┌─────────────────────────────────────────────┐
        │  ✅ ClarityBuds is running!                 │
        │                                             │
        │  👂 Look for the ear icon in your menu bar  │
        │  ⌨️  Press ⌥⇧T to toggle passthrough       │
        │  🛑 Press Ctrl+C here to quit               │
        └─────────────────────────────────────────────┘
        """)
    }

    // MARK: - Keyboard Shortcut

    private func setupGlobalShortcut() {
        // Use a slight delay to ensure the app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            GlobalShortcutManager.shared.register(from: appState) { [self] in
                togglePassthrough()
            }
        }
    }

    // MARK: - Toggle

    private func togglePassthrough() {
        if appState.isPassthroughActive {
            audioEngine.stop()
            appState.isPassthroughActive = false
        } else {
            guard PermissionManager.isMicrophoneAuthorized else { return }

            // Pass 0 for system default, or the specific device ID
            let inputID = appState.selectedInputDeviceID
            let outputID = appState.selectedOutputDeviceID

            audioEngine.start(
                inputDeviceID: inputID,
                outputDeviceID: outputID,
                volume: appState.ambientVolume
            )
            appState.isPassthroughActive = audioEngine.isRunning
        }
    }
}
