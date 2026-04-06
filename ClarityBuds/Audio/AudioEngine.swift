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
    private var fadeTask: Task<Void, Never>?

    // MARK: - Public API

    /// Start the audio passthrough from the given input device to the given output device.
    /// - Parameters:
    ///   - inputDeviceID: The Core Audio device ID for the microphone input.
    ///                    Pass 0 to use system default.
    ///   - outputDeviceID: The Core Audio device ID for the headphone output.
    ///                     Pass 0 to use system default.
    ///   - volume: The passthrough volume (0.0 to 1.5).
    func start(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID, volume: Float) {
        stop()
        errorMessage = nil
        warningMessage = nil

        // Guard against feedback: same device for input and output (only if both are explicit)
        if inputDeviceID != 0 && outputDeviceID != 0 && inputDeviceID == outputDeviceID {
            errorMessage = "Input and output devices must be different to prevent audio feedback."
            return
        }

        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID

        // Try the preferred strategy, then fall back to simpler ones
        if !tryStartWithDeviceOverrides(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID, volume: volume) {
            if !tryStartWithDefaults(volume: volume) {
                // Both strategies failed — errorMessage is already set
                return
            }
        }
    }

    /// Stop the audio passthrough.
    func stop() {
        fadeTask?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        estimatedLatencyMs = 0
        warningMessage = nil
    }

    /// Update the passthrough volume while the engine is running.
    func setVolume(_ volume: Float) {
        fadeVolume(to: clampVolume(volume), duration: 0.1)
    }

    // MARK: - Start Strategies

    /// Strategy 1: Set specific input/output devices via AudioUnit properties.
    /// This is the preferred path when the user picks specific devices.
    private func tryStartWithDeviceOverrides(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID, volume: Float) -> Bool {
        let engine = AVAudioEngine()

        // Access nodes to force audio unit creation
        let inputNode = engine.inputNode
        _ = engine.mainMixerNode  // Force creation
        let outputNode = engine.outputNode

        // Try to set input device (only if non-default)
        if inputDeviceID != 0 {
            if !setDevice(inputDeviceID, onNode: inputNode, label: "input") {
                print("[ClarityBuds] Strategy 1 failed: couldn't set input device \(inputDeviceID)")
                return false // Fall through to Strategy 2
            }
        }

        // Try to set output device (only if non-default)
        if outputDeviceID != 0 {
            if !setDevice(outputDeviceID, onNode: outputNode, label: "output") {
                warningMessage = "Using system default output device."
                // Non-fatal — continue with default output
            }
        }

        return startEngine(engine, volume: volume)
    }

    /// Strategy 2: Use system defaults for everything — no device overrides.
    /// AVAudioEngine automatically uses the system default input/output.
    private func tryStartWithDefaults(volume: Float) -> Bool {
        warningMessage = "Using system default audio devices."
        let engine = AVAudioEngine()

        // Just access the nodes — don't set any devices.
        // AVAudioEngine will use whatever macOS has as default input/output.
        _ = engine.inputNode
        _ = engine.mainMixerNode
        _ = engine.outputNode

        return startEngine(engine, volume: volume)
    }

    /// Common engine start logic: connect nodes, set volume, start.
    private func startEngine(_ engine: AVAudioEngine, volume: Float) -> Bool {
        do {
            let inputNode = engine.inputNode
            let mainMixer = engine.mainMixerNode
            let outputNode = engine.outputNode

            // explicitly disable OS-level voice processing (AEC/AGC) which adds latency
            do {
                if #available(macOS 13.0, *) {
                    try inputNode.setVoiceProcessingEnabled(false)
                }
            } catch {
                print("[ClarityBuds] Notice: Could not disable voice processing: \(error)")
            }

            // Get the hardware input format
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
                errorMessage = "No valid audio format from the input device. Check microphone permissions in System Settings → Privacy & Security → Microphone."
                return false
            }

            // Connect: input → mixer → output
            engine.connect(inputNode, to: mainMixer, format: inputFormat)
            engine.connect(mainMixer, to: outputNode, format: nil)

            // Set initial volume to 0.0 for fade-in
            mainMixer.outputVolume = 0.0

            // Step: Aggressively optimize hardware buffer size to 64 frames for low latency
            optimizeDeviceBufferSizes(inputID: self.inputDeviceID ?? 0, outputID: self.outputDeviceID ?? 0)

            // Prepare and start
            engine.prepare()
            try engine.start()

            self.audioEngine = engine
            isRunning = true
            estimatedLatencyMs = calculateLatency(engine: engine)

            // Smooth fade in
            fadeVolume(to: clampVolume(volume), duration: 0.25)

            return true

        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Device Helpers

    /// Try to set a device on a node's audio unit. Returns true on success.
    private func setDevice(_ deviceID: AudioDeviceID, onNode node: AVAudioNode, label: String) -> Bool {
        // audioUnit is only available on AVAudioIONode subclasses
        let audioUnit: AudioUnit?
        if let ioNode = node as? AVAudioInputNode {
            audioUnit = ioNode.audioUnit
        } else if let ioNode = node as? AVAudioOutputNode {
            audioUnit = ioNode.audioUnit
        } else {
            print("[ClarityBuds] \(label) node is not an I/O node.")
            return false
        }

        guard let unit = audioUnit else {
            print("[ClarityBuds] \(label) node has no audio unit.")
            return false
        }

        var mutableID = deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            print("[ClarityBuds] Failed to set \(label) device \(deviceID) — OSStatus: \(status)")
            return false
        }

        return true
    }

    // MARK: - Buffer Optimization

    private func optimizeDeviceBufferSizes(inputID: AudioDeviceID, outputID: AudioDeviceID) {
        let actualInputID = inputID == 0 ? getDefaultDevice(isInput: true) : inputID
        let actualOutputID = outputID == 0 ? getDefaultDevice(isInput: false) : outputID

        if actualInputID != 0 { optimizeBufferSize(for: actualInputID, label: "Input") }
        if actualOutputID != 0 && actualOutputID != actualInputID { optimizeBufferSize(for: actualOutputID, label: "Output") }
    }

    private func optimizeBufferSize(for deviceID: AudioDeviceID, label: String) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var bufferSize: UInt32 = 64 // Aggressive low latency (64 frames = ~1.3ms at 48kHz)
        let size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            size,
            &bufferSize
        )

        if status != noErr {
            print("[ClarityBuds] Could not optimize buffer size for \(label) device \(deviceID) (OSStatus: \(status)).")
        } else {
            print("[ClarityBuds] Successfully optimized buffer size to \(bufferSize) frames for \(label) device \(deviceID).")
        }
    }

    private func getDefaultDevice(isInput: Bool) -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
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

    // MARK: - Private Helpers

    private func clampVolume(_ volume: Float) -> Float {
        min(max(volume, 0.0), 1.5)
    }

    private func calculateLatency(engine: AVAudioEngine) -> Double {
        let inputLatency = engine.inputNode.presentationLatency
        let outputLatency = engine.outputNode.presentationLatency
        return (inputLatency + outputLatency) * 1000.0
    }

    /// Smoothly animates the volume up or down over a duration.
    private func fadeVolume(to targetVolume: Float, duration: TimeInterval) {
        fadeTask?.cancel()

        guard let mixer = audioEngine?.mainMixerNode else { return }
        let startVolume = mixer.outputVolume

        // Don't fade if we're already exactly there
        if abs(startVolume - targetVolume) < 0.01 {
            mixer.outputVolume = targetVolume
            return
        }

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = (targetVolume - startVolume) / Float(steps)

        fadeTask = Task { @MainActor [weak self] in
            for i in 1...steps {
                if Task.isCancelled { break }
                let currentVol = startVolume + (volumeStep * Float(i))
                self?.audioEngine?.mainMixerNode.outputVolume = max(0, min(currentVol, 1.5))
                try? await Task.sleep(for: .seconds(stepDuration))
            }
            if !Task.isCancelled {
                self?.audioEngine?.mainMixerNode.outputVolume = max(0, min(targetVolume, 1.5))
            }
        }
    }
}
