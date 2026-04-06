import SwiftUI
import CoreAudio

/// The main menu bar popover view — the primary interface for ClarityBuds.
struct MenuBarView: View {

    @Bindable var appState: AppState
    let deviceManager: DeviceManager
    let audioEngine: AudioPassthroughEngine
    let onToggle: () -> Void
    let onQuit: () -> Void

    @State private var showPermissionAlert = false
    @State private var showFeedbackWarning = false
    @State private var showTroubleshooting = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, 16)

            // Main Controls
            VStack(spacing: 16) {
                toggleSection
                volumeSection
                deviceSection
            }
            .padding(16)

            // Status Bar
            if let error = audioEngine.errorMessage {
                errorBanner(error)
            } else if audioEngine.isRunning {
                statusBanner
            }

            if let warning = audioEngine.warningMessage {
                warningBanner(warning)
            }

            Divider()
                .padding(.horizontal, 16)

            // Footer
            footerSection
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                PermissionManager.openMicrophoneSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("ClarityBuds needs microphone access to pass ambient sound through your headphones. Please enable it in System Settings.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "ear")
                .font(.title2)
                .foregroundStyle(appState.isPassthroughActive ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClarityBuds")
                    .font(.headline)
                Text("Ambient Sound Passthrough")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showTroubleshooting.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTroubleshooting, arrowEdge: .bottom) {
                troubleshootingView
            }
            .padding(.trailing, 4)

            Text(shortcutLabel)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(16)
    }

    private var shortcutLabel: String {
        GlobalShortcutManager.shortcutDisplayString(
            keyCode: appState.shortcutKeyCode,
            modifiers: appState.shortcutModifiers
        )
    }

    private var troubleshootingView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fixing Bluetooth Audio Delay")
                .font(.headline)

            Text("Bluetooth audio inherently has 150-250ms of delay. However, you can prevent macOS from adding even more massive latency by checking two things:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Label("Disable Voice Isolation", systemImage: "mic.slash")
                    .font(.subheadline.bold())
                Text("Click the orange microphone icon in your Mac's top right menu bar (Control Center) and set Mic Mode to **Standard**.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Label("Match Sample Rates", systemImage: "waveform.path.ecg")
                    .font(.subheadline.bold())
                Text("Open the **Audio MIDI Setup** app. Ensure your Microphone and Headphones are set to the exact same frequency (e.g. 48,000 Hz).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Spacer()
                Button("Got it") {
                    showTroubleshooting = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Toggle

    private var toggleSection: some View {
        Button(action: {
            handleToggle()
        }) {
            HStack {
                Image(systemName: appState.isPassthroughActive ? "waveform.circle.fill" : "waveform.circle")
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: appState.isPassthroughActive)

                Text(appState.isPassthroughActive ? "Passthrough On" : "Passthrough Off")
                    .font(.body.weight(.semibold))

                Spacer()

                Circle()
                    .fill(appState.isPassthroughActive ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(appState.isPassthroughActive
                          ? Color.green.opacity(0.15)
                          : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Ambient Volume", systemImage: "speaker.wave.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(appState.ambientVolume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(value: $appState.ambientVolume, in: 0...1.5, step: 0.05)
                    .onChange(of: appState.ambientVolume) { _, newValue in
                        audioEngine.setVolume(newValue)
                    }

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Device Selection

    private var deviceSection: some View {
        VStack(spacing: 10) {
            // Input Device
            VStack(alignment: .leading, spacing: 4) {
                Label("Input (Microphone)", systemImage: "mic")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $appState.selectedInputDeviceID) {
                    Text("System Default")
                        .tag(AudioDeviceID(0))

                    ForEach(deviceManager.inputDevices) { device in
                        Text(device.displayName)
                            .tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            // Output Device
            VStack(alignment: .leading, spacing: 4) {
                Label("Output (Headphones)", systemImage: "headphones")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $appState.selectedOutputDeviceID) {
                    Text("System Default")
                        .tag(AudioDeviceID(0))

                    ForEach(deviceManager.outputDevices) { device in
                        Text(device.displayName)
                            .tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Status

    private var statusBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text("Active")
                .font(.caption)
                .foregroundStyle(.green)

            Spacer()

            Text("~\(String(format: "%.0f", audioEngine.estimatedLatencyMs))ms latency")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func warningBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("Quit") {
                onQuit()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Text("v1.0.0")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func handleToggle() {
        if appState.isPassthroughActive {
            // Turn off
            audioEngine.stop()
            appState.isPassthroughActive = false
        } else {
            // Check permissions first
            if PermissionManager.isMicrophoneDenied {
                showPermissionAlert = true
                return
            }

            if PermissionManager.needsToRequestPermission {
                PermissionManager.requestMicrophonePermission { [self] granted in
                    MainActor.assumeIsolated {
                        if granted {
                            startPassthrough()
                        }
                    }
                }
                return
            }

            startPassthrough()
        }
        onToggle()
    }

    private func startPassthrough() {
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
