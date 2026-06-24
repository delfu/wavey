/// One frame's detection outcome: the verdict against the expected target, plus
/// whether a new strum/pluck started this frame.
public struct DetectionEvent: Hashable, Sendable {
    public let result: MatchResult
    public let isOnset: Bool
}

/// The single object the game talks to for live detection. It ties the pieces
/// together — level gate → onset → chroma/pitch → the chord or note verifier,
/// chosen by the expected target — and emits a `DetectionEvent` per frame.
///
/// Source-agnostic: feed it frames (the app wires `AudioCapture` to it; tests
/// feed synthesized/file audio). Not `Sendable`; own it from one thread.
public final class LiveDetector {
    public enum Target: Hashable, Sendable {
        case chord(Chord)
        case note(Note)
    }

    /// The note/chord we're currently waiting for. Nil → reports `.silence`.
    public var target: Target?
    /// Optional ambient-noise gate; when nil, `silenceRMS` is the floor.
    public var calibrator: InputCalibrator?
    /// Minimum RMS to treat a frame as signal (used when not calibrated).
    public var silenceRMS: Float

    public let sampleRate: Double
    public let frameSize: Int

    private let fft: FFT
    private let chromagram: Chromagram
    private let windowCoeffs: [Float]
    private let pitchDetector: PitchDetector
    private var onsetDetector: OnsetDetector
    private var chordVerifier: ChordVerifier
    private var noteVerifier: NoteVerifier

    /// `frameSize` must be a power of two.
    public init(sampleRate: Double = 44_100,
                frameSize: Int = 4096,
                calibrator: InputCalibrator? = nil,
                silenceRMS: Float = 1e-3) {
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.calibrator = calibrator
        self.silenceRMS = silenceRMS
        self.fft = FFT(size: frameSize)!
        self.chromagram = Chromagram(sampleRate: sampleRate, fftSize: frameSize)
        self.windowCoeffs = Window.hann.coefficients(count: frameSize)
        self.pitchDetector = PitchDetector(sampleRate: sampleRate)
        self.onsetDetector = OnsetDetector()
        self.chordVerifier = ChordVerifier()
        self.noteVerifier = NoteVerifier()
    }

    /// Process one frame (length == `frameSize`) at `time` seconds.
    public func process(_ frame: [Float], at time: Double) -> DetectionEvent {
        guard let target else { return DetectionEvent(result: .silence, isOnset: false) }
        precondition(frame.count == frameSize, "frame length must equal frameSize")

        var windowed = frame
        for i in 0..<frameSize { windowed[i] *= windowCoeffs[i] }
        let magnitudes = fft.magnitudeSpectrum(windowed)

        let isOnset = onsetDetector.process(magnitudes: magnitudes, time: time)

        let gate = max(silenceRMS, calibrator?.gateRMS ?? 0)
        let belowGate = Self.rms(frame) <= gate

        let result: MatchResult
        switch target {
        case .chord(let chord):
            let chroma = belowGate ? nil : chromagram.chroma(fromMagnitudes: magnitudes)
            result = chordVerifier.verify(expected: chord, chroma: chroma)
        case .note(let note):
            let pitch = belowGate ? nil : pitchDetector.detect(frame)
            result = noteVerifier.verify(expected: note, pitch: pitch)
        }
        return DetectionEvent(result: result, isOnset: isOnset)
    }

    /// Clear stability/onset state (e.g. when changing target or restarting).
    public func reset() {
        onsetDetector.reset()
        chordVerifier.reset()
        noteVerifier.reset()
    }

    private static func rms(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in frame { sum += sample * sample }
        return (sum / Float(frame.count)).squareRoot()
    }
}
