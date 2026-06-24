import Foundation

/// One tuner reading: which open string the pitch is closest to (or locked to),
/// how many cents sharp/flat it is, and whether that's within tolerance.
public struct TunerReading: Hashable, Sendable {
    public let string: Note
    /// Signed deviation from `string` in cents (positive = sharp).
    public let cents: Double
    public let isInTune: Bool
}

/// Maps a detected frequency to the nearest guitar string and its tuning offset.
public struct Tuner: Sendable {
    public let strings: [Note]
    /// A reading within ±`inTuneTolerance` cents counts as in tune.
    public let inTuneTolerance: Double

    public init(strings: [Note] = StandardTuning.openStrings, inTuneTolerance: Double = 5) {
        precondition(!strings.isEmpty, "tuner needs at least one target string")
        self.strings = strings
        self.inTuneTolerance = inTuneTolerance
    }

    /// A reading for `frequency`. Pass `lockedTo` to hold a specific string — so
    /// tuning one string toward a neighbour doesn't jump targets — otherwise the
    /// nearest string is chosen.
    public func reading(forFrequency frequency: Double, lockedTo: Note? = nil) -> TunerReading {
        precondition(frequency > 0, "frequency must be positive")
        let target = lockedTo ?? nearestString(to: frequency)
        let cents = 1200 * log2(frequency / target.frequency)
        return TunerReading(string: target, cents: cents, isInTune: abs(cents) <= inTuneTolerance)
    }

    /// The string nearest `frequency` in log-frequency (i.e. fewest cents away).
    private func nearestString(to frequency: Double) -> Note {
        strings.min { a, b in
            abs(log2(frequency / a.frequency)) < abs(log2(frequency / b.frequency))
        }!
    }
}
