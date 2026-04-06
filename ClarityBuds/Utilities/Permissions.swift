import AVFoundation
import AppKit

/// Handles microphone permission requests and status checks.
enum PermissionManager {

    /// Current microphone authorization status.
    static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Whether microphone access is currently authorized.
    static var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }

    /// Whether we need to request microphone permission (not yet determined).
    static var needsToRequestPermission: Bool {
        microphoneStatus == .notDetermined
    }

    /// Whether the user has denied microphone access.
    static var isMicrophoneDenied: Bool {
        microphoneStatus == .denied || microphoneStatus == .restricted
    }

    /// Request microphone permission from the user.
    /// - Parameter completion: Called on the main thread with the result.
    static func requestMicrophonePermission(completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Open System Settings to the microphone privacy pane.
    @MainActor
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
