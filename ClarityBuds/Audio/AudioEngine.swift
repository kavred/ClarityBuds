import AVFoundation
import CoreAudio
import Combine

/// The core audio engine that captures microphone input and routes it
/// to the headphone output in real-time, creating ClarityBuds' passthrough effect.
@Observable
final class AudioPassthroughEngine {

    // MARK: - Public State

    /// Whether passthrough mode is currently active
    private(set) var isRunning = false

    /// Current latency estimate in milliseconds
    private(set) var estimatedLatencyMs: Double = 0

    /// Error message if the engine fails to start
    private(set) var errorMessage: String?

    /// Warning message (non-fatal)
    private(set) var warningMessage: String?

    // MARK: - Private

    private var audioEngine: AVAudioEngine?
    private var inputDeviceID: AudioDeviceID?
    private var outputDeviceID: AudioDeviceID?

    // MARK: - Public API

    /// Start the audio passthrough from the given input device to the given output device.
    /// - Parameters:
    ///   - inputDeviceID: The Core Audio device ID for the microphone input.
    ///   - outputDeviceID: The Core Audio device ID for the headphone output.
    ///   - volume: The passthrough volume (0.0 to 1.5).
    func start(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID, volume: Float) {
        stop()
        errorMessage = nil
        warningMessage = nil

        // Guard against feedback: same device for input and output
        if inputDeviceID == outputDeviceID {
            errorMessage = "Input and output devices must be different to prevent audio feedback."
            return
        }

        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID

        let engine = AVAudioEngine()
        self.audioEngine = engine

        do {
            // Step 1: Access nodes first — this forces AVAudioEngine to
            // create the underlying audio units internally.
            let inputNode = engine.inputNode
            let mainMixer = engine.mainMixerNode
            let outputNode = engine.outputNode

            // Step 2: Now set devices — the audio units exist after node access.
            // Input device is critical — if this fails, we can't proceed.
            try setInputDevice(inputDeviceID, on: inputNode)

            // Output device is a soft failure — if it fails, we fall back
            // to the system default output (which is usually what the user wants).
            let outputSet = setOutputDeviceSoft(outputDeviceID, on: outputNode)
            if !outputSet {
                warningMessage = "Using system default output (couldn't set specific device)."
            }

            // Step 3: Get the hardware input format AFTER setting the device,
            // since the format depends on which device is selected.
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
                errorMessage = "Could not get a valid audio format from the selected input device."
                return
            }

            // Step 4: Connect the audio graph.
            // input → mixer → output
            // The mixer gives us volume control.
            engine.connect(inputNode, to: mainMixer, format: inputFormat)
            engine.connect(mainMixer, to: outputNode, format: nil)

            // Step 5: Set the passthrough volume.
            mainMixer.outputVolume = clampVolume(volume)

            // Step 6: Prepare and start.
            engine.prepare()
            try engine.start()

            isRunning = true
            estimatedLatencyMs = calculateLatency(engine: engine)

        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            self.audioEngine = nil
        }
    }

    /// Stop the audio passthrough.
    func stop() {
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        estimatedLatencyMs = 0
        warningMessage = nil
    }

    /// Update the passthrough volume while the engine is running.
    /// - Parameter volume: Volume level from 0.0 (silent) to 1.5 (amplified).
    func setVolume(_ volume: Float) {
        audioEngine?.mainMixerNode.outputVolume = clampVolume(volume)
    }

    // MARK: - Private Helpers

    private func clampVolume(_ volume: Float) -> Float {
        min(max(volume, 0.0), 1.5)
    }

    private func calculateLatency(engine: AVAudioEngine) -> Double {
        let inputLatency = engine.inputNode.presentationLatency
        let outputLatency = engine.outputNode.presentationLatency
        return (inputLatency + outputLatency) * 1000.0 // Convert to ms
    }

    /// Set the input device on the input node's Audio Unit.
    /// This is a hard requirement — throws on failure.
    private func setInputDevice(_ deviceID: AudioDeviceID, on inputNode: AVAudioInputNode) throws {
        guard let audioUnit = inputNode.audioUnit else {
            throw AudioEngineError.noAudioUnit(node: "input")
        }

        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw AudioEngineError.deviceSetFailed(
                device: "input",
                status: status
            )
        }
    }

    /// Try to set the output device on the output node's Audio Unit.
    /// Returns true if successful, false if it failed (non-fatal — system default is used).
    private func setOutputDeviceSoft(_ deviceID: AudioDeviceID, on outputNode: AVAudioOutputNode) -> Bool {
        guard let audioUnit = outputNode.audioUnit else {
            print("[ClarityBuds] Output node has no audio unit — using system default output.")
            return false
        }

        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            print("[ClarityBuds] Could not set output device (OSStatus: \(status)) — using system default output.")
            return false
        }

        return true
    }
}

// MARK: - Errors

enum AudioEngineError: LocalizedError {
    case noAudioUnit(node: String)
    case deviceSetFailed(device: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .noAudioUnit(let node):
            return "Could not access the \(node) audio unit for device configuration."
        case .deviceSetFailed(let device, let status):
            return "Failed to set \(device) device (error code: \(status))."
        }
    }
}
