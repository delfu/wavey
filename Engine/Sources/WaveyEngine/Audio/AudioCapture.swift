import AVFoundation

/// Captures microphone input and delivers it as fixed-size mono `Float` frames
/// at a target sample rate.
///
/// `onFrame` is invoked on an audio thread — keep it fast and hop to the main
/// actor for any UI. Not `Sendable`: own it from the main actor and only
/// `start()`/`stop()` from there.
public final class AudioCapture {
    public enum CaptureError: Error {
        case permissionDenied
        case converterUnavailable
        case engineFailure(Error)
    }

    public let sampleRate: Double
    public let frameSize: Int

    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private let onFrame: ([Float]) -> Void
    private var accumulator: FrameAccumulator
    private var converter: AVAudioConverter?

    public init(sampleRate: Double = 44_100,
                frameSize: Int = 2048,
                hop: Int? = nil,
                onFrame: @escaping ([Float]) -> Void) {
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.onFrame = onFrame
        self.accumulator = FrameAccumulator(frameSize: frameSize, hop: hop)
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: sampleRate,
                                          channels: 1,
                                          interleaved: false)!
    }

    /// Request mic permission, configure the session, and begin delivering frames.
    public func start() async throws {
        try await requestPermission()

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        #endif

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw CaptureError.converterUnavailable
        }
        self.converter = converter
        accumulator.reset()

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw CaptureError.engineFailure(error)
        }
    }

    /// Stop capture and tear down the tap.
    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    // MARK: - Private

    private func requestPermission() async throws {
        #if os(iOS)
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else { throw CaptureError.permissionDenied }
        #endif
    }

    /// Resample/downmix one input buffer to the target format and emit frames.
    private func process(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }
        guard status != .error, conversionError == nil else { return }

        let count = Int(outBuffer.frameLength)
        guard count > 0, let channel = outBuffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: count))
        for frame in accumulator.push(samples) {
            onFrame(frame)
        }
    }
}
