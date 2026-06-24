import XCTest
@testable import WaveyEngine
import Foundation

final class ChromagramTests: XCTestCase {

    private let sr = 44100.0
    private let n = 4096

    /// Synthesize a sum of sines, window, and return its magnitude spectrum.
    private func magnitudes(_ frequencies: [Double]) -> [Float] {
        var signal = [Float](repeating: 0, count: n)
        for f in frequencies {
            for i in 0..<n { signal[i] += Float(sin(2 * .pi * f * Double(i) / sr)) }
        }
        let windowed = Window.hann.applied(to: signal)
        return FFT(size: n)!.magnitudeSpectrum(windowed)
    }

    private func argmax(_ v: [Float]) -> Int {
        v.enumerated().max(by: { $0.element < $1.element })!.offset
    }

    func testSingleNotePeaksAtItsPitchClass() {
        let chroma = Chromagram(sampleRate: sr, fftSize: n)
        XCTAssertEqual(argmax(chroma.chroma(fromMagnitudes: magnitudes([261.63]))), 0) // C4 -> C
        XCTAssertEqual(argmax(chroma.chroma(fromMagnitudes: magnitudes([440.0]))), 9)  // A4 -> A
    }

    func testOctaveInvariance() {
        let chroma = Chromagram(sampleRate: sr, fftSize: n)
        for f in [65.41, 130.81, 261.63] {   // C2, C3, C4
            XCTAssertEqual(argmax(chroma.chroma(fromMagnitudes: magnitudes([f]))), 0)
        }
    }

    func testTriadHasChordTonesAsTopBins() {
        let chroma = Chromagram(sampleRate: sr, fftSize: n)
        // C major: C4 E4 G4 -> pitch classes C(0) E(4) G(7)
        let c = chroma.chroma(fromMagnitudes: magnitudes([261.63, 329.63, 392.00]))
        let top3 = Set(c.enumerated().sorted { $0.element > $1.element }.prefix(3).map(\.offset))
        XCTAssertEqual(top3, [0, 4, 7])
    }

    func testSilenceGivesZeroChroma() {
        let chroma = Chromagram(sampleRate: sr, fftSize: n)
        XCTAssertEqual(chroma.chroma(fromMagnitudes: [Float](repeating: 0, count: n / 2)), [Float](repeating: 0, count: 12))
    }
}
