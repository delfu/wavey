import Accelerate

/// A single pitch estimate.
public struct PitchResult: Hashable, Sendable {
    /// Estimated fundamental frequency in Hz.
    public let frequency: Double
    /// Periodicity confidence in 0...1 (higher = cleaner pitch).
    public let confidence: Double
}

/// Monophonic pitch detection using the YIN algorithm (de Cheveigné & Kawahara,
/// 2002), tuned by default for the acoustic-guitar range. Returns nil for
/// silence or signals too aperiodic to call a pitch.
///
/// An immutable value type, cheap to construct. The per-frame cost is
/// O(window · maxLag); fine for a tuner, can be FFT-accelerated later if needed.
public struct PitchDetector: Sendable {
    public let sampleRate: Double
    public let minFrequency: Double
    public let maxFrequency: Double
    /// YIN absolute threshold; the first normalized-difference dip below this is
    /// taken as the period.
    public let threshold: Float

    public init(sampleRate: Double,
                minFrequency: Double = 80,
                maxFrequency: Double = 1350,
                threshold: Float = 0.15) {
        self.sampleRate = sampleRate
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
    }

    public func detect(_ frame: [Float]) -> PitchResult? {
        let n = frame.count
        let tauMax = min(Int((sampleRate / minFrequency).rounded(.up)), n / 2)
        let tauMin = max(2, Int(sampleRate / maxFrequency))
        guard tauMax > tauMin, n > tauMax else { return nil }

        // Silence gate (mean square ~ -70 dBFS).
        var meanSquare: Float = 0
        vDSP_measqv(frame, 1, &meanSquare, vDSP_Length(n))
        guard meanSquare > 1e-7 else { return nil }

        let w = n - tauMax

        // 1) Difference function d(τ).
        var d = [Float](repeating: 0, count: tauMax + 1)
        frame.withUnsafeBufferPointer { x in
            for tau in 1...tauMax {
                var sum: Float = 0
                for j in 0..<w {
                    let diff = x[j] - x[j + tau]
                    sum += diff * diff
                }
                d[tau] = sum
            }
        }

        // 2) Cumulative mean normalized difference d'(τ).
        var dPrime = [Float](repeating: 1, count: tauMax + 1)
        var runningSum: Float = 0
        for tau in 1...tauMax {
            runningSum += d[tau]
            dPrime[tau] = runningSum > 0 ? d[tau] * Float(tau) / runningSum : 1
        }

        // 3) First dip below threshold, descended to its local minimum.
        var chosen = -1
        var tau = tauMin
        while tau <= tauMax {
            if dPrime[tau] < threshold {
                while tau + 1 <= tauMax && dPrime[tau + 1] < dPrime[tau] { tau += 1 }
                chosen = tau
                break
            }
            tau += 1
        }
        if chosen == -1 {           // fallback: global minimum over the search range
            var best = Float.greatestFiniteMagnitude
            for t in tauMin...tauMax where dPrime[t] < best { best = dPrime[t]; chosen = t }
        }
        guard chosen > 0, dPrime[chosen] < 0.5 else { return nil }

        // 4) Parabolic interpolation for sub-sample period precision.
        let refinedTau = interpolatedMinimum(dPrime, around: chosen, lower: tauMin, upper: tauMax)
        let frequency = sampleRate / refinedTau
        guard frequency >= minFrequency, frequency <= maxFrequency else { return nil }

        return PitchResult(frequency: frequency,
                           confidence: max(0, min(1, 1 - Double(dPrime[chosen]))))
    }

    private func interpolatedMinimum(_ d: [Float], around tau: Int, lower: Int, upper: Int) -> Double {
        guard tau > lower, tau < upper else { return Double(tau) }
        let x0 = Double(d[tau - 1]), x1 = Double(d[tau]), x2 = Double(d[tau + 1])
        let denom = x0 + x2 - 2 * x1
        guard denom != 0 else { return Double(tau) }
        return Double(tau) + 0.5 * (x0 - x2) / denom
    }
}
