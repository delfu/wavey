/// Buffers incoming audio of arbitrary sizes and emits fixed-size frames with a
/// configurable hop (overlap). Pure and synchronous so it can be unit-tested
/// without a live microphone.
public struct FrameAccumulator {
    public let frameSize: Int
    /// Samples advanced between consecutive frames. `hop == frameSize` means no
    /// overlap; `hop < frameSize` overlaps neighbouring frames.
    public let hop: Int
    private var buffer: [Float] = []

    public init(frameSize: Int, hop: Int? = nil) {
        precondition(frameSize > 0, "frameSize must be positive")
        let resolvedHop = hop ?? frameSize
        precondition(resolvedHop > 0 && resolvedHop <= frameSize, "hop must be in 1...frameSize")
        self.frameSize = frameSize
        self.hop = resolvedHop
    }

    /// Append `samples` and return every frame that is now complete, in order.
    public mutating func push(_ samples: [Float]) -> [[Float]] {
        buffer.append(contentsOf: samples)
        var frames: [[Float]] = []
        while buffer.count >= frameSize {
            frames.append(Array(buffer[0..<frameSize]))
            buffer.removeFirst(hop)
        }
        return frames
    }

    /// Discard any buffered samples.
    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}
