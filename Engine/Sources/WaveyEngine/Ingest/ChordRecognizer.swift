import Foundation

/// Offline chord recognition: isolated guitar audio → a time-ordered sequence of
/// chords. Per-frame chroma is matched against a maj/min template vocabulary
/// (biased toward the estimated key's diatonic chords), mode-smoothed, short runs
/// absorbed into neighbours, segmented, and optionally snapped to a beat grid.
/// Open-ended recognition — fine here because it runs offline with the whole
/// track (the live game only verifies, never recognizes).
public struct ChordRecognizer {
    public struct TimedChord: Hashable, Sendable {
        public let chord: Chord
        public let start: Double       // seconds
        public let duration: Double    // seconds

        public init(chord: Chord, start: Double, duration: Double) {
            self.chord = chord
            self.start = start
            self.duration = duration
        }
    }

    public var sampleRate: Double
    public var fftSize: Int
    public var hop: Int
    /// Segments shorter than this are merged into a neighbour (de-flicker).
    public var minChordDuration: Double
    /// Mode-filter window (frames) applied to per-frame labels.
    public var smoothingFrames: Int
    /// Minimum cosine similarity to accept a chord for a frame.
    public var matchThreshold: Double
    /// Chord qualities in the recognition vocabulary.
    public var qualities: [ChordQuality]
    /// Bias recognition toward the estimated key's diatonic chords.
    public var keyAware: Bool
    /// Multiplier applied to non-diatonic chord scores when `keyAware` is on.
    public var diatonicPenalty: Double

    public init(sampleRate: Double = 44_100,
                fftSize: Int = 4096,
                hop: Int = 2048,
                minChordDuration: Double = 0.5,
                smoothingFrames: Int = 9,
                matchThreshold: Double = 0.6,
                qualities: [ChordQuality] = [.major, .minor],
                keyAware: Bool = true,
                diatonicPenalty: Double = 0.82) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.hop = hop
        self.minChordDuration = minChordDuration
        self.smoothingFrames = smoothingFrames
        self.matchThreshold = matchThreshold
        self.qualities = qualities
        self.keyAware = keyAware
        self.diatonicPenalty = diatonicPenalty
    }

    /// Recognize a chord sequence; pass `beats` to snap segment edges to the grid.
    public func recognize(_ samples: [Float], snappingTo beats: [Double]? = nil) -> [TimedChord] {
        let frames = chromaFrames(samples)
        guard !frames.isEmpty else { return [] }
        let templates = buildTemplates()
        let hopTime = Double(hop) / sampleRate

        let diatonic = keyAware ? Self.diatonicChords(forKey: Self.estimateKey(Self.aggregate(frames))) : nil
        let labels = frames.map { bestChord($0, templates: templates, diatonic: diatonic) }
        let smoothed = modeSmooth(labels, window: smoothingFrames)
        let cleaned = enforceMinRun(smoothed, minFrames: max(1, Int(minChordDuration / hopTime)))
        let result = segments(cleaned, hopTime: hopTime)
        return beats.map { snap(result, to: $0) } ?? result
    }

    // MARK: - Frames & matching

    private func chromaFrames(_ samples: [Float]) -> [[Float]] {
        guard let fft = FFT(size: fftSize) else { return [] }
        let chromagram = Chromagram(sampleRate: sampleRate, fftSize: fftSize)
        let window = Window.hann.coefficients(count: fftSize)
        var frames: [[Float]] = []
        var pos = 0
        while pos + fftSize <= samples.count {
            var frame = Array(samples[pos..<pos + fftSize])
            for i in 0..<fftSize { frame[i] *= window[i] }
            frames.append(chromagram.chroma(fromMagnitudes: fft.magnitudeSpectrum(frame)))
            pos += hop
        }
        return frames
    }

    private func buildTemplates() -> [(chord: Chord, vector: [Float])] {
        var templates: [(Chord, [Float])] = []
        for root in PitchClass.allCases {
            for quality in qualities {
                let chord = Chord(root: root, quality: quality)
                var vector = [Float](repeating: 0, count: 12)
                for pitchClass in chord.pitchClasses { vector[pitchClass.rawValue] = 1 }
                templates.append((chord, vector))
            }
        }
        return templates
    }

    private func bestChord(_ chroma: [Float],
                           templates: [(chord: Chord, vector: [Float])],
                           diatonic: Set<Chord>?) -> Chord? {
        var best: Chord?
        var bestScore = matchThreshold
        for (chord, vector) in templates {
            var score = cosine(chroma, vector)
            if let diatonic, !diatonic.contains(chord) { score *= diatonicPenalty }
            if score > bestScore {
                bestScore = score
                best = chord
            }
        }
        return best
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Double {
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<min(a.count, b.count) {
            dot += Double(a[i]) * Double(b[i])
            normA += Double(a[i]) * Double(a[i])
            normB += Double(b[i]) * Double(b[i])
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    // MARK: - Key estimation (Krumhansl–Schmuckler)

    private static let majorProfile: [Double] =
        [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile: [Double] =
        [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// Sum of all per-frame chroma vectors.
    static func aggregate(_ frames: [[Float]]) -> [Double] {
        var sum = [Double](repeating: 0, count: 12)
        for frame in frames {
            for i in 0..<min(12, frame.count) { sum[i] += Double(frame[i]) }
        }
        return sum
    }

    /// Best-correlating key (root + major/minor) for an aggregate chroma.
    static func estimateKey(_ chroma: [Double]) -> (root: PitchClass, isMajor: Bool) {
        var bestRoot = 0, bestIsMajor = true
        var bestCorrelation = -Double.greatestFiniteMagnitude
        for isMajor in [true, false] {
            let profile = isMajor ? majorProfile : minorProfile
            for root in 0..<12 {
                let rotated = (0..<12).map { profile[(($0 - root) % 12 + 12) % 12] }
                let correlation = pearson(chroma, rotated)
                if correlation > bestCorrelation {
                    bestCorrelation = correlation
                    bestRoot = root
                    bestIsMajor = isMajor
                }
            }
        }
        return (PitchClass(rawValue: bestRoot)!, bestIsMajor)
    }

    private static func pearson(_ a: [Double], _ b: [Double]) -> Double {
        let n = Double(min(a.count, b.count))
        let meanA = a.reduce(0, +) / n
        let meanB = b.reduce(0, +) / n
        var covariance = 0.0, varianceA = 0.0, varianceB = 0.0
        for i in 0..<Int(n) {
            let da = a[i] - meanA, db = b[i] - meanB
            covariance += da * db
            varianceA += da * da
            varianceB += db * db
        }
        guard varianceA > 0, varianceB > 0 else { return 0 }
        return covariance / (varianceA.squareRoot() * varianceB.squareRoot())
    }

    /// The diatonic triads of a key — its relative major's I ii iii IV V vi.
    static func diatonicChords(forKey key: (root: PitchClass, isMajor: Bool)) -> Set<Chord> {
        let majorRoot = key.isMajor ? key.root.rawValue : (key.root.rawValue + 3) % 12
        func pitchClass(_ n: Int) -> PitchClass { PitchClass(rawValue: (n % 12 + 12) % 12)! }
        return [
            Chord(root: pitchClass(majorRoot), quality: .major),       // I
            Chord(root: pitchClass(majorRoot + 2), quality: .minor),   // ii
            Chord(root: pitchClass(majorRoot + 4), quality: .minor),   // iii
            Chord(root: pitchClass(majorRoot + 5), quality: .major),   // IV
            Chord(root: pitchClass(majorRoot + 7), quality: .major),   // V
            Chord(root: pitchClass(majorRoot + 9), quality: .minor),   // vi
        ]
    }

    // MARK: - Smoothing & segmentation

    private func modeSmooth(_ labels: [Chord?], window: Int) -> [Chord?] {
        guard window > 1 else { return labels }
        let half = window / 2
        return labels.indices.map { i in
            var counts: [Chord?: Int] = [:]
            for j in max(0, i - half)...min(labels.count - 1, i + half) {
                counts[labels[j], default: 0] += 1
            }
            return counts.max { $0.value < $1.value }!.key
        }
    }

    /// Absorb runs shorter than `minFrames` into the longer adjacent run, so short
    /// spurious chords (and brief no-chord gaps) disappear without leaving holes.
    private func enforceMinRun(_ input: [Chord?], minFrames: Int) -> [Chord?] {
        guard minFrames > 1 else { return input }
        var labels = input
        while true {
            let runs = runLengths(labels)
            guard runs.count > 1 else { break }
            guard let shortIndex = runs.indices
                .filter({ runs[$0].range.count < minFrames })
                .min(by: { runs[$0].range.count < runs[$1].range.count })
            else { break }

            let prevLength = shortIndex > 0 ? runs[shortIndex - 1].range.count : -1
            let nextLength = shortIndex < runs.count - 1 ? runs[shortIndex + 1].range.count : -1
            let neighbor = prevLength >= nextLength ? runs[shortIndex - 1].label : runs[shortIndex + 1].label
            for k in runs[shortIndex].range { labels[k] = neighbor }
        }
        return labels
    }

    private func runLengths(_ labels: [Chord?]) -> [(range: Range<Int>, label: Chord?)] {
        var runs: [(Range<Int>, Chord?)] = []
        var i = 0
        while i < labels.count {
            var j = i
            while j < labels.count, labels[j] == labels[i] { j += 1 }
            runs.append((i..<j, labels[i]))
            i = j
        }
        return runs
    }

    private func segments(_ labels: [Chord?], hopTime: Double) -> [TimedChord] {
        var result: [TimedChord] = []
        var i = 0
        while i < labels.count {
            guard let chord = labels[i] else { i += 1; continue }
            var j = i
            while j < labels.count, labels[j] == chord { j += 1 }
            let duration = Double(j - i) * hopTime
            if duration >= minChordDuration {
                result.append(TimedChord(chord: chord, start: Double(i) * hopTime, duration: duration))
            }
            i = j
        }
        return result
    }

    private func snap(_ chords: [TimedChord], to beats: [Double]) -> [TimedChord] {
        guard !beats.isEmpty else { return chords }
        return chords.map { tc in
            let start = nearestBeat(tc.start, beats)
            let end = nearestBeat(tc.start + tc.duration, beats)
            return TimedChord(chord: tc.chord, start: start, duration: max(0, end - start))
        }
    }

    private func nearestBeat(_ time: Double, _ beats: [Double]) -> Double {
        beats.min { abs($0 - time) < abs($1 - time) } ?? time
    }
}
