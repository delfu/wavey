/// Detects note/strum onsets from a stream of magnitude spectra using spectral
/// flux (sum of positive bin-to-bin increases) with an adaptive threshold and a
/// debounce. Feed frames in order; it tells the live loop when a fresh attempt
/// happened so each strum is judged once.
///
/// Stateful and single-threaded by design.
public struct OnsetDetector {
    /// Multiplier on the running flux standard deviation for the threshold.
    public var sensitivity: Double
    /// How many recent frames feed the adaptive threshold.
    public var windowFrames: Int
    /// Minimum seconds between reported onsets (debounce).
    public var minInterOnset: Double

    private var previous: [Float]?
    private var fluxWindow: [Float] = []
    private var lastOnset: Double = -.greatestFiniteMagnitude

    public init(sensitivity: Double = 2.0, windowFrames: Int = 15, minInterOnset: Double = 0.08) {
        self.sensitivity = sensitivity
        self.windowFrames = windowFrames
        self.minInterOnset = minInterOnset
    }

    /// Feed one frame's magnitude spectrum (sequential). Returns true if this
    /// frame is an onset.
    public mutating func process(magnitudes: [Float], time: Double) -> Bool {
        defer { previous = magnitudes }
        guard let previous else { return false }

        // Spectral flux: sum of positive changes since the last frame.
        var flux: Float = 0
        let count = min(magnitudes.count, previous.count)
        for k in 0..<count {
            let delta = magnitudes[k] - previous[k]
            if delta > 0 { flux += delta }
        }

        // Adaptive threshold from the recent flux history (excluding this frame).
        let mean = fluxWindow.isEmpty ? 0 : fluxWindow.reduce(0, +) / Float(fluxWindow.count)
        let variance = fluxWindow.isEmpty
            ? 0
            : fluxWindow.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(fluxWindow.count)
        let threshold = mean + Float(sensitivity) * variance.squareRoot()

        fluxWindow.append(flux)
        if fluxWindow.count > windowFrames { fluxWindow.removeFirst() }

        if flux > threshold, time - lastOnset >= minInterOnset {
            lastOnset = time
            return true
        }
        return false
    }

    public mutating func reset() {
        previous = nil
        fluxWindow.removeAll(keepingCapacity: true)
        lastOnset = -.greatestFiniteMagnitude
    }
}
