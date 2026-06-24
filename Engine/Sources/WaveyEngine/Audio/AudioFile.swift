import AVFoundation

/// Decodes an audio file (mp3 / m4a / wav / …) into mono `Float` samples at a
/// target sample rate — the entry point for offline ingestion. Reads the whole
/// file into memory (fine for songs; chunk if we ever need very long inputs).
public enum AudioFile {
    public enum LoadError: Error {
        case unreadable
        case conversionUnavailable
    }

    /// Load `url` as mono Float samples resampled to `sampleRate`.
    public static func loadMono(url: URL, sampleRate: Double = 44_100) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat

        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: sampleRate,
                                               channels: 1,
                                               interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { throw LoadError.conversionUnavailable }
        converter.primeMethod = .none   // offline file load — no priming latency

        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                                 frameCapacity: AVAudioFrameCount(file.length))
        else { throw LoadError.unreadable }
        try file.read(into: inputBuffer)

        // Drain the converter (one convert call doesn't emit everything).
        var output: [Float] = []
        var fedInput = false
        while true {
            guard let chunk = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 16384) else {
                throw LoadError.conversionUnavailable
            }
            var conversionError: NSError?
            let status = converter.convert(to: chunk, error: &conversionError) { _, inputStatus in
                if fedInput {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                fedInput = true
                inputStatus.pointee = .haveData
                return inputBuffer
            }
            if let conversionError { throw conversionError }
            if chunk.frameLength > 0, let channel = chunk.floatChannelData?[0] {
                output.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(chunk.frameLength)))
            }
            if status == .endOfStream || status == .error || chunk.frameLength == 0 { break }
        }
        return output
    }
}
