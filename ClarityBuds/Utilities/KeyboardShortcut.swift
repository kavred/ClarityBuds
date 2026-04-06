import Carbon
import AppKit

/// Manages a global keyboard shortcut that works even when the app is not focused.
@MainActor
final class GlobalShortcutManager {

    // MARK: - Singleton

    static let shared = GlobalShortcutManager()

    // MARK: - Properties

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private let hotKeyID = EventHotKeyID(
        signature: OSType(0x54524E53),  // 'TRNS'
        id: 1
    )

    // MARK: - Public API

    /// Register a global hotkey.
    /// - Parameters:
    ///   - keyCode: The virtual key code (e.g., 17 for 'T').
    ///   - modifiers: Carbon modifier flags (e.g., optionKey + shiftKey).
    ///   - action: The closure to execute when the hotkey is pressed.
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregister()
        self.callback = action

        // Install the event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.callback?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        self.hotKeyRef = hotKeyRef
    }

    /// Register the default shortcut (⌥⇧T).
    func registerDefault(action: @escaping () -> Void) {
        // keyCode 17 = 'T', optionKey = 0x0800, shiftKey = 0x0200
        register(keyCode: 17, modifiers: UInt32(optionKey | shiftKey), action: action)
    }

    /// Register with custom key code and modifiers from AppState.
    func register(from state: AppState, action: @escaping () -> Void) {
        let carbonModifiers = nsModifiersToCarbonModifiers(UInt(state.shortcutModifiers))
        register(keyCode: UInt32(state.shortcutKeyCode), modifiers: carbonModifiers, action: action)
    }

    /// Unregister the current hotkey.
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        callback = nil
    }

    // MARK: - Helpers

    /// Convert NS modifier flags to Carbon modifier flags.
    private func nsModifiersToCarbonModifiers(_ nsModifiers: UInt) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if nsModifiers & NSEvent.ModifierFlags.command.rawValue != 0 { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers & NSEvent.ModifierFlags.option.rawValue != 0 { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { carbonModifiers |= UInt32(shiftKey) }
        if nsModifiers & NSEvent.ModifierFlags.control.rawValue != 0 { carbonModifiers |= UInt32(controlKey) }
        return carbonModifiers
    }

    /// Get a human-readable description of the current shortcut.
    static func shortcutDisplayString(keyCode: UInt16, modifiers: UInt) -> String {
        var parts: [String] = []

        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { parts.append("⌃") }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { parts.append("⌥") }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { parts.append("⇧") }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { parts.append("⌘") }

        // Map common key codes to characters
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1",
            19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
            25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 31: "O",
            32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
            45: "N", 46: "M"
        ]

        parts.append(keyMap[keyCode] ?? "?")
        return parts.joined()
    }

    deinit {
        // Cleanup is handled by the OS when the process exits.
        // We can't call @MainActor-isolated methods from deinit in Swift 6.
    }
}
