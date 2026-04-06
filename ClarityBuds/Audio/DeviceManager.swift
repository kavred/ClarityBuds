import CoreAudio
import Foundation

/// Represents an audio device (input or output) on the system.
struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
    let transportType: AudioDeviceTransportType

    /// Human-readable transport type label
    var transportLabel: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return "Built-in"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "Bluetooth"
        case kAudioDeviceTransportTypeUSB:
            return "USB"
        case kAudioDeviceTransportTypeVirtual:
            return "Virtual"
        case kAudioDeviceTransportTypeAggregate:
            return "Aggregate"
        default:
            return "Other"
        }
    }

    /// Display name including transport type
    var displayName: String {
        "\(name) (\(transportLabel))"
    }
}

/// Manages the enumeration and monitoring of Core Audio devices.
@Observable
final class DeviceManager {

    // MARK: - Public State

    /// All available input devices
    private(set) var inputDevices: [AudioDevice] = []

    /// All available output devices
    private(set) var outputDevices: [AudioDevice] = []

    /// The system's current default input device ID
    private(set) var defaultInputDeviceID: AudioDeviceID = 0

    /// The system's current default output device ID
    private(set) var defaultOutputDeviceID: AudioDeviceID = 0

    // MARK: - Private

    private var listenerRegistered = false

    // MARK: - Init

    init() {
        refreshDevices()
        registerDeviceChangeListener()
    }

    deinit {
        unregisterDeviceChangeListener()
    }

    // MARK: - Public API

    /// Refresh the list of available audio devices.
    func refreshDevices() {
        inputDevices = enumerateDevices(scope: kAudioObjectPropertyScopeInput)
        outputDevices = enumerateDevices(scope: kAudioObjectPropertyScopeOutput)
        defaultInputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        defaultOutputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    /// Check if using the same device for input and output would cause feedback.
    func wouldCauseFeedback(inputID: AudioDeviceID, outputID: AudioDeviceID) -> Bool {
        return inputID == outputID
    }

    /// Get an AudioDevice by its ID.
    func device(for id: AudioDeviceID) -> AudioDevice? {
        return inputDevices.first(where: { $0.id == id }) ?? outputDevices.first(where: { $0.id == id })
    }

    // MARK: - Device Enumeration

    private func enumerateDevices(scope: AudioObjectPropertyScope) -> [AudioDevice] {
        // Get all audio device IDs
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        // Filter devices that support the requested scope (input or output)
        return deviceIDs.compactMap { deviceID in
            // Check if device has streams in the requested scope
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: scope,
                mElement: kAudioObjectPropertyElementMain
            )

            var streamSize: UInt32 = 0
            let streamStatus = AudioObjectGetPropertyDataSize(
                deviceID, &streamAddress, 0, nil, &streamSize
            )
            guard streamStatus == noErr, streamSize > 0 else { return nil }

            let name = getDeviceName(deviceID)
            let transportType = getTransportType(deviceID)
            let isInput = scope == kAudioObjectPropertyScopeInput
            let isOutput = scope == kAudioObjectPropertyScopeOutput

            return AudioDevice(
                id: deviceID,
                name: name,
                isInput: isInput,
                isOutput: isOutput,
                transportType: transportType
            )
        }
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var unmanagedName: Unmanaged<CFString>?

        let status = AudioObjectGetPropertyData(
            deviceID, &propertyAddress, 0, nil, &dataSize, &unmanagedName
        )

        guard status == noErr, let cfName = unmanagedName?.takeUnretainedValue() else {
            return "Unknown Device"
        }
        return cfName as String
    }

    private func getTransportType(_ deviceID: AudioDeviceID) -> AudioDeviceTransportType {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID, &propertyAddress, 0, nil, &dataSize, &transportType
        )

        return status == noErr ? transportType : 0
    }

    private func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : 0
    }

    // MARK: - Device Change Monitoring

    private func registerDeviceChangeListener() {
        guard !listenerRegistered else { return }

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshDevices()
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshDevices()
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshDevices()
        }

        listenerRegistered = true
    }

    private func unregisterDeviceChangeListener() {
        // Listeners will be cleaned up when the object is deallocated
        // since we used weak self in the blocks
        listenerRegistered = false
    }
}

// MARK: - Type Alias for clarity
typealias AudioDeviceTransportType = UInt32
