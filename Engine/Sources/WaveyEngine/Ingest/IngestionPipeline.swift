import Foundation

/// Isolates the guitar from mixed audio. The real implementation (Demucs → Core
/// ML) is gated on a quality spike (DEL-199); until then the pipeline uses a
/// pass-through for already-isolated guitar.
public protocol GuitarSeparator {
    /// Return guitar-only samples at the same sample rate.
    func separate(_ samples: [Float], sampleRate: Double) -> [Float]
}

/// Identity separator — for audio that is already isolated guitar (and tests).
public struct PassthroughSeparator: GuitarSeparator {
    public init() {}
    public func separate(_ samples: [Float], sampleRate: Double) -> [Float] { samples }
}

/// The offline ingestion pipeline: audio → guitar stem → beat grid → chords →
/// `Sheet`. Separation is injected so it can be a pass-through now and the
/// Core ML Demucs runner later.
public struct IngestionPipeline {
    public enum Stage: Hashable, Sendable { case separating, beats, chords, done }

    public var sampleRate: Double
    public var separator: GuitarSeparator
    public var beatTracker: BeatTracker
    public var chordRecognizer: ChordRecognizer

    public init(sampleRate: Double = 44_100,
                separator: GuitarSeparator = PassthroughSeparator(),
                beatTracker: BeatTracker? = nil,
                chordRecognizer: ChordRecognizer? = nil) {
        self.sampleRate = sampleRate
        self.separator = separator
        self.beatTracker = beatTracker ?? BeatTracker(sampleRate: sampleRate)
        self.chordRecognizer = chordRecognizer ?? ChordRecognizer(sampleRate: sampleRate)
    }

    /// Run the pipeline and assemble a `Sheet`. `onProgress` fires per stage; for
    /// cancellation, run this inside a `Task` and check `Task.isCancelled` from
    /// the caller. Beat-snapping is off by default (the recognizer's own timing
    /// is reliable; snapping only helps strongly-rhythmic input).
    public func makeSheet(from samples: [Float],
                          title: String,
                          snapToBeats: Bool = false,
                          onProgress: ((Stage) -> Void)? = nil) -> Sheet {
        onProgress?(.separating)
        let guitar = separator.separate(samples, sampleRate: sampleRate)

        onProgress?(.beats)
        let beat = beatTracker.analyze(guitar)

        onProgress?(.chords)
        let chords = chordRecognizer.recognize(guitar, snappingTo: snapToBeats ? beat.beats : nil)

        onProgress?(.done)
        let events = chords.map {
            SheetEvent(time: $0.start, duration: $0.duration, payload: .chord($0.chord))
        }
        return Sheet(title: title,
                     bpm: beat.bpm,
                     duration: Double(samples.count) / sampleRate,
                     events: events)
    }
}
