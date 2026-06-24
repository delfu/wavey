import Observation
import WaveyEngine

/// Drives the tuner screen: runs mic capture, detects pitch, and maps it to a
/// tuning reading. Lives on the main actor; capture delivers frames on an audio
/// thread and we hop back here to publish.
@MainActor
@Observable
final class TunerViewModel {
    private(set) var reading: TunerReading?
    private(set) var isListening = false
    private(set) var errorMessage: String?

    private let sampleRate = 44_100.0
    private let tuner = Tuner()
    private let detector: PitchDetector
    private var capture: AudioCapture?

    init() {
        detector = PitchDetector(sampleRate: sampleRate)
    }

    func toggle() {
        isListening ? stop() : start()
    }

    func start() {
        guard !isListening else { return }
        errorMessage = nil

        // Capture immutable engine values so the audio-thread callback never
        // touches main-actor state except via the hop below.
        let detector = self.detector
        let tuner = self.tuner
        var smoother = PitchSmoother()
        let capture = AudioCapture(sampleRate: sampleRate, frameSize: 4096, hop: 2048) { [weak self] frame in
            guard let frequency = smoother.update(detector.detect(frame)) else {
                Task { @MainActor in self?.reading = nil }
                return
            }
            let reading = tuner.reading(forFrequency: frequency)
            Task { @MainActor in self?.reading = reading }
        }
        self.capture = capture

        Task {
            do {
                try await capture.start()
                isListening = true
            } catch {
                errorMessage = Self.message(for: error)
                self.capture = nil
            }
        }
    }

    func stop() {
        capture?.stop()
        capture = nil
        isListening = false
        reading = nil
    }

    private static func message(for error: Error) -> String {
        if case AudioCapture.CaptureError.permissionDenied = error {
            return "Microphone access is off. Enable it in Settings to use the tuner."
        }
        return "Couldn't start listening: \(error.localizedDescription)"
    }
}
