import Foundation

/// Folds a magnitude spectrum into a 12-bin pitch-class profile (chroma) — the
/// basis for chord verification and recognition. Each FFT bin is mapped to its
/// nearest pitch class (which gives ±50 cents of tuning tolerance) and its
/// magnitude accumulated; the result is normalized so the strongest class is 1.
public struct Chromagram {
    public let sampleRate: Double
    public let fftSize: Int
    public let minFrequency: Double
    public let maxFrequency: Double
    /// Log-compress bin magnitudes before accumulating, so loud partials don't
    /// dominate (helps when several notes sound at once).
    public let whiten: Bool

    public init(sampleRate: Double,
                fftSize: Int,
                minFrequency: Double = 55,
                maxFrequency: Double = 2000,
                whiten: Bool = false) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.whiten = whiten
    }

    /// Map a magnitude spectrum (length `fftSize/2`, index 0 = DC) to a
    /// normalized 12-element chroma vector (index 0 = C).
    public func chroma(fromMagnitudes magnitudes: [Float]) -> [Float] {
        var chroma = [Float](repeating: 0, count: 12)
        for k in magnitudes.indices {
            let frequency = Double(k) * sampleRate / Double(fftSize)
            guard frequency >= minFrequency, frequency <= maxFrequency else { continue }
            let magnitude = whiten ? log1pf(magnitudes[k]) : magnitudes[k]
            chroma[pitchClassIndex(for: frequency)] += magnitude
        }
        if let peak = chroma.max(), peak > 0 {
            for i in chroma.indices { chroma[i] /= peak }
        }
        return chroma
    }

    /// Nearest pitch class (0 = C) for a frequency, via its MIDI number.
    private func pitchClassIndex(for frequency: Double) -> Int {
        let midi = 69.0 + 12.0 * log2(frequency / 440.0)
        return ((Int(midi.rounded()) % 12) + 12) % 12
    }
}
