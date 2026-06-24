import XCTest
@testable import WaveyEngine
import AVFoundation

final class AudioFileTests: XCTestCase {

    func testLoadsAndResamplesMonoFromWav() throws {
        let sr = 44100.0
        let n = Int(0.5 * sr)
        let samples = (0..<n).map { Float(0.7 * sin(2 * .pi * 440 * Double($0) / sr)) }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wavey_test_\(UUID().uuidString).wav")
        try Self.writeWav(samples, sampleRate: sr, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try AudioFile.loadMono(url: url, sampleRate: sr)
        XCTAssertEqual(Double(loaded.count), Double(n), accuracy: 1024)   // ~same length (converter latency)

        // The decoded audio should still read as ~440 Hz.
        let pitch = PitchDetector(sampleRate: sr).detect(Array(loaded.prefix(4096)))
        XCTAssertEqual(pitch?.frequency ?? 0, 440, accuracy: 5)
    }

    func testResamplesToRequestedRate() throws {
        let inRate = 48000.0, outRate = 44100.0
        let n = Int(0.5 * inRate)
        let samples = (0..<n).map { Float(sin(2 * .pi * 220 * Double($0) / inRate)) }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wavey_test_\(UUID().uuidString).wav")
        try Self.writeWav(samples, sampleRate: inRate, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try AudioFile.loadMono(url: url, sampleRate: outRate)
        // 0.5 s at 44.1 kHz ≈ 22050 samples.
        XCTAssertEqual(Double(loaded.count), 0.5 * outRate, accuracy: 512)
    }

    private static func writeWav(_ samples: [Float], sampleRate: Double, to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in samples.indices { buffer.floatChannelData![0][i] = samples[i] }
        try file.write(from: buffer)
    }
}
