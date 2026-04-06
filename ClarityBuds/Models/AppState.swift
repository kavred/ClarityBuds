import Foundation
import CoreAudio

/// Central app state that persists user preferences and coordinates
/// between the audio engine and the UI.
@Observable
final class AppState {

    // MARK: - Persisted Settings

    /// Whether passthrough mode is currently enabled
    var isPassthroughActive: Bool = false {
        didSet {
            UserDefaults.standard.set(isPassthroughActive, forKey: Keys.isActive)
        }
    }

    /// Ambient passthrough volume (0.0 = silent, 1.0 = normal, 1.5 = amplified)
    var ambientVolume: Float = 0.75 {
        didSet {
            UserDefaults.standard.set(ambientVolume, forKey: Keys.volume)
        }
    }

    /// Selected input device ID (microphone)
    var selectedInputDeviceID: AudioDeviceID = 0 {
        didSet {
            UserDefaults.standard.set(Int(selectedInputDeviceID), forKey: Keys.inputDevice)
        }
    }

    /// Selected output device ID (headphones)
    var selectedOutputDeviceID: AudioDeviceID = 0 {
        didSet {
            UserDefaults.standard.set(Int(selectedOutputDeviceID), forKey: Keys.outputDevice)
        }
    }

    /// Whether to launch the app at login
    var launchAtLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    /// Custom keyboard shortcut key code
    var shortcutKeyCode: UInt16 = 17 {  // 17 = 'T' key
        didSet {
            UserDefaults.standard.set(Int(shortcutKeyCode), forKey: Keys.shortcutKeyCode)
        }
    }

    /// Custom keyboard shortcut modifier flags
    var shortcutModifiers: UInt = 0x180000 {  // Option + Shift
        didSet {
            UserDefaults.standard.set(Int(shortcutModifiers), forKey: Keys.shortcutModifiers)
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isActive = "claritybuds_isActive"
        static let volume = "claritybuds_volume"
        static let inputDevice = "claritybuds_inputDevice"
        static let outputDevice = "claritybuds_outputDevice"
        static let launchAtLogin = "claritybuds_launchAtLogin"
        static let shortcutKeyCode = "claritybuds_shortcutKeyCode"
        static let shortcutModifiers = "claritybuds_shortcutModifiers"
    }

    // MARK: - Init

    init() {
        loadPersistedSettings()
    }

    // MARK: - Persistence

    private func loadPersistedSettings() {
        let defaults = UserDefaults.standard

        // Only load if values exist
        if defaults.object(forKey: Keys.volume) != nil {
            ambientVolume = defaults.float(forKey: Keys.volume)
        }

        if defaults.object(forKey: Keys.inputDevice) != nil {
            selectedInputDeviceID = AudioDeviceID(defaults.integer(forKey: Keys.inputDevice))
        }

        if defaults.object(forKey: Keys.outputDevice) != nil {
            selectedOutputDeviceID = AudioDeviceID(defaults.integer(forKey: Keys.outputDevice))
        }

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        if defaults.object(forKey: Keys.shortcutKeyCode) != nil {
            shortcutKeyCode = UInt16(defaults.integer(forKey: Keys.shortcutKeyCode))
        }

        if defaults.object(forKey: Keys.shortcutModifiers) != nil {
            shortcutModifiers = UInt(defaults.integer(forKey: Keys.shortcutModifiers))
        }

        // Note: We don't restore isActive — user should manually enable each session
    }

    /// Reset all settings to defaults.
    func resetToDefaults() {
        isPassthroughActive = false
        ambientVolume = 0.75
        selectedInputDeviceID = 0
        selectedOutputDeviceID = 0
        launchAtLogin = false
        shortcutKeyCode = 17
        shortcutModifiers = 0x180000
    }
}
