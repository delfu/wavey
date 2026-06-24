import Foundation
import Observation
// Swift-5-mode interop: the engine isn't strict-concurrency annotated yet (we
// intentionally stop AudioCapture off the main thread). Revisit on Swift 6.
@preconcurrency import WaveyEngine

/// Drives the tuner screen: runs mic capture, detects pitch, smooths it, and
/// maps it to a tuning reading. Lives on the main actor; capture delivers frames
/// on an audio thread and we hop back here to publish.
@MainActor
@Observable
final class TunerViewModel {
    private(set) var reading: TunerReading?
    private(set) var isListening = false
    private(set) var errorMessage: String?
    private(set) var permissionDenied = false

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
            let reading = smoother.update(detector.detect(frame)).map { tuner.reading(forFrequency: $0) }
            Task { @MainActor in
                guard self?.isListening == true else { return }  // drop frames arriving after stop
                self?.reading = reading
            }
        }
        self.capture = capture

        Task {
            do {
                try await capture.start()
                isListening = true
                permissionDenied = false
            } catch {
                if case AudioCapture.CaptureError.permissionDenied = error { permissionDenied = true }
                errorMessage = Self.message(for: error)
                self.capture = nil
            }
        }
    }

    func stop() {
        guard let capture else { return }
        // Update the UI immediately for instant feedback...
        self.capture = nil
        isListening = false
        reading = nil
        // ...then tear down off the main thread: AVAudioEngine.stop() and
        // AVAudioSession.setActive(false) can block long enough to stutter the UI.
        DispatchQueue.global(qos: .userInitiated).async {
            capture.stop()
        }
    }

    private static func message(for error: Error) -> String {
        if case AudioCapture.CaptureError.permissionDenied = error {
            return "Microphone access is off. Enable it in Settings to use the tuner."
        }
        return "Couldn't start listening: \(error.localizedDescription)"
    }
}
