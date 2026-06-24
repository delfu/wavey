import Foundation

/// Estimates tempo and a beat grid from audio, offline. Builds a spectral-flux
/// onset envelope, finds the dominant period by (normalized) autocorrelation
/// under a tempo prior, then phase-aligns a comb of beats to the envelope.
///
/// This is the simple, well-trodden approach (à la librosa); good enough to snap
/// a transcribed sheet to the beat. Build it ourselves — the reputable beat
/// libraries are all GPL/AGPL (see DEL-201 notes).
public struct BeatTracker {
    public struct Result: Hashable, Sendable {
        /// Estimated tempo in beats per minute (0 if undetermined).
        public let bpm: Double
        /// Beat times in seconds.
        public let beats: [Double]
    }

    public var sampleRate: Double
    public var fftSize: Int
    public var hop: Int
    public var minBPM: Double
    public var maxBPM: Double
    /// Center of the log-normal tempo prior (BPM) used to resolve octave errors.
    public var preferredBPM: Double

    public init(sampleRate: Double = 44_100,
                fftSize: Int = 2048,
                hop: Int = 512,
                minBPM: Double = 60,
                maxBPM: Double = 180,
                preferredBPM: Double = 120) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.hop = hop
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.preferredBPM = preferredBPM
    }

    public func analyze(_ samples: [Float]) -> Result {
        let envelope = onsetEnvelope(samples)
        guard envelope.count > 4 else { return Result(bpm: 0, beats: []) }

        let hopTime = Double(hop) / sampleRate
        let minLag = max(1, Int((60.0 / maxBPM) / hopTime))
        let maxLag = min(envelope.count - 1, Int((60.0 / minBPM) / hopTime))
        guard maxLag > minLag else { return Result(bpm: 0, beats: []) }

        let period = bestPeriod(envelope, minLag: minLag, maxLag: maxLag, hopTime: hopTime)
        let bpm = 60.0 / (Double(period) * hopTime)

        let phase = bestPhase(envelope, period: period)
        var beats: [Double] = []
        var frame = phase
        while frame < envelope.count {
            beats.append(Double(frame) * hopTime)
            frame += period
        }
        return Result(bpm: bpm, beats: beats)
    }

    /// Spectral flux (positive magnitude change) per frame.
    private func onsetEnvelope(_ samples: [Float]) -> [Float] {
        guard let fft = FFT(size: fftSize) else { return [] }
        let window = Window.hann.coefficients(count: fftSize)
        var envelope: [Float] = []
        var previous: [Float]?
        var pos = 0
        while pos + fftSize <= samples.count {
            var frame = Array(samples[pos..<pos + fftSize])
            for i in 0..<fftSize { frame[i] *= window[i] }
            let magnitudes = fft.magnitudeSpectrum(frame)
            if let previous {
                var flux: Float = 0
                for k in 0..<magnitudes.count {
                    let delta = magnitudes[k] - previous[k]
                    if delta > 0 { flux += delta }
                }
                envelope.append(flux)
            } else {
                envelope.append(0)
            }
            previous = magnitudes
            pos += hop
        }
        return envelope
    }

    /// Lag (in frames) of the strongest normalized autocorrelation, weighted by a
    /// log-normal tempo prior so half/double-tempo octaves don't win.
    private func bestPeriod(_ envelope: [Float], minLag: Int, maxLag: Int, hopTime: Double) -> Int {
        var bestLag = minLag
        var bestScore = -Double.greatestFiniteMagnitude
        for lag in minLag...maxLag {
            var sum: Float = 0
            var i = lag
            while i < envelope.count {
                sum += envelope[i] * envelope[i - lag]
                i += 1
            }
            let normalized = Double(sum) / Double(envelope.count - lag)
            let bpm = 60.0 / (Double(lag) * hopTime)
            let prior = exp(-0.5 * pow(log2(bpm / preferredBPM), 2))   // sigma = 1 octave
            let score = normalized * prior
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }
        return bestLag
    }

    /// Phase offset (in frames) within one period that maximizes the comb energy.
    private func bestPhase(_ envelope: [Float], period: Int) -> Int {
        var bestPhase = 0
        var bestSum = -Float.greatestFiniteMagnitude
        for offset in 0..<period {
            var sum: Float = 0
            var i = offset
            while i < envelope.count {
                sum += envelope[i]
                i += period
            }
            if sum > bestSum {
                bestSum = sum
                bestPhase = offset
            }
        }
        return bestPhase
    }
}
