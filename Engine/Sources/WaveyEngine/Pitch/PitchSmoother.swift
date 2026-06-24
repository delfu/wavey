import Foundation

/// Smooths a stream of per-frame pitch estimates into a stable readout for the
/// tuner: rejects low-confidence frames (noise/weak input), exponentially
/// smooths the accepted frequency, snaps to a clearly different note, and holds
/// briefly through short dropouts before clearing.
///
/// Stateful and single-threaded by design — feed it frames in order.
public struct PitchSmoother {
    /// Frames below this confidence are ignored (treated as no pitch).
    public var minConfidence: Double
    /// EMA factor in (0, 1]; lower is smoother (and laggier).
    public var smoothing: Double
    /// If a new pitch is more than this many cents from the current value, jump
    /// to it instead of smoothing (so changing strings is instant).
    public var snapCents: Double
    /// Keep emitting the last value through this many consecutive empty frames
    /// before clearing to nil.
    public var holdFrames: Int

    private var value: Double?
    private var emptyCount = 0

    public init(minConfidence: Double = 0.9,
                smoothing: Double = 0.2,
                snapCents: Double = 80,
                holdFrames: Int = 8) {
        self.minConfidence = minConfidence
        self.smoothing = smoothing
        self.snapCents = snapCents
        self.holdFrames = holdFrames
    }

    /// Feed one frame's pitch (or nil if none was detected). Returns the current
    /// smoothed frequency, or nil when there's no confident pitch to show.
    public mutating func update(_ pitch: PitchResult?) -> Double? {
        guard let pitch, pitch.confidence >= minConfidence else {
            emptyCount += 1
            if emptyCount > holdFrames { value = nil }
            return value
        }

        emptyCount = 0
        if let current = value {
            let centsApart = abs(1200 * log2(pitch.frequency / current))
            value = centsApart > snapCents
                ? pitch.frequency
                : current + smoothing * (pitch.frequency - current)
        } else {
            value = pitch.frequency
        }
        return value
    }

    public mutating func reset() {
        value = nil
        emptyCount = 0
    }
}
