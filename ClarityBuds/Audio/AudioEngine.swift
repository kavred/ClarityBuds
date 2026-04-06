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
            // Set the input and output devices on the audio engine's underlying Audio Units
            try setInputDevice(inputDeviceID, on: engine)
            try setOutputDevice(outputDeviceID, on: engine)

            let inputNode = engine.inputNode
            let mainMixer = engine.mainMixerNode
            let outputNode = engine.outputNode

            // Get the hardware input format
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
                errorMessage = "Could not get a valid audio format from the selected input device."
                return
            }

            // Connect: input → mixer → output
            // The mixer allows us to control volume independently
            engine.connect(inputNode, to: mainMixer, format: inputFormat)

            // Use nil format for mixer→output to let the engine negotiate
            engine.connect(mainMixer, to: outputNode, format: nil)

            // Set the passthrough volume
            mainMixer.outputVolume = clampVolume(volume)

            // Prepare and start
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

    /// Set the input device on the AVAudioEngine's input node Audio Unit.
    private func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        let inputNode = engine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            throw AudioEngineError.noAudioUnit
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

    /// Set the output device on the AVAudioEngine's output node Audio Unit.
    private func setOutputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        let outputNode = engine.outputNode
        guard let audioUnit = outputNode.audioUnit else {
            throw AudioEngineError.noAudioUnit
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
                device: "output",
                status: status
            )
        }
    }
}

// MARK: - Errors

enum AudioEngineError: LocalizedError {
    case noAudioUnit
    case deviceSetFailed(device: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .noAudioUnit:
            return "Could not access the audio unit for device configuration."
        case .deviceSetFailed(let device, let status):
            return "Failed to set \(device) device (error code: \(status))."
        }
    }
}
