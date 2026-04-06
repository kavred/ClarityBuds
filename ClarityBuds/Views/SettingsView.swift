import SwiftUI

/// Settings/preferences view accessible from the menu bar popover.
struct SettingsView: View {

    @Bindable var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Settings Content
            Form {
                // Launch at Login
                Section {
                    Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                        .onChange(of: appState.launchAtLogin) { _, newValue in
                            LaunchAtLoginManager.setEnabled(newValue)
                        }
                } header: {
                    Label("General", systemImage: "gearshape")
                }

                // Keyboard Shortcut
                Section {
                    HStack {
                        Text("Toggle Shortcut")
                        Spacer()
                        Text(currentShortcutString)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .font(.caption.monospaced())
                    }

                    Text("Default: ⌥⇧T (Option + Shift + T)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Keyboard Shortcut", systemImage: "keyboard")
                }

                // About
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Author", value: "ClarityBuds")

                    Link("View on GitHub", destination: URL(string: "https://github.com")!)
                        .font(.caption)
                } header: {
                    Label("About", systemImage: "info.circle")
                }

                // Reset
                Section {
                    Button("Reset All Settings", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 420)
        .alert("Reset Settings?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                appState.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }

    private var currentShortcutString: String {
        GlobalShortcutManager.shortcutDisplayString(
            keyCode: appState.shortcutKeyCode,
            modifiers: appState.shortcutModifiers
        )
    }
}
