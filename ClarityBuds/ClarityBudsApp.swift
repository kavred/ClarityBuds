import SwiftUI

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
        // Register the global keyboard shortcut on launch
        setupGlobalShortcut()
    }

    private func setupGlobalShortcut() {
        // Use a slight delay to ensure the app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            GlobalShortcutManager.shared.register(from: appState) { [self] in
                togglePassthrough()
            }
        }
    }

    private func togglePassthrough() {
        if appState.isPassthroughActive {
            audioEngine.stop()
            appState.isPassthroughActive = false
        } else {
            guard PermissionManager.isMicrophoneAuthorized else { return }

            let inputID = appState.selectedInputDeviceID == 0
                ? deviceManager.defaultInputDeviceID
                : appState.selectedInputDeviceID

            let outputID = appState.selectedOutputDeviceID == 0
                ? deviceManager.defaultOutputDeviceID
                : appState.selectedOutputDeviceID

            audioEngine.start(
                inputDeviceID: inputID,
                outputDeviceID: outputID,
                volume: appState.ambientVolume
            )
            appState.isPassthroughActive = audioEngine.isRunning
        }
    }
}
