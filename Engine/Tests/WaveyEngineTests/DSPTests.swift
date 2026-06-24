import XCTest
@testable import WaveyEngine
import Foundation

final class DSPTests: XCTestCase {

    // MARK: Window

    func testHannEndpointsAndCentre() {
        let w = Window.hann.coefficients(count: 1025)
        XCTAssertEqual(w.first!, 0.0, accuracy: 1e-6)
        XCTAssertEqual(w.last!, 0.0, accuracy: 1e-6)
        XCTAssertEqual(w[512], 1.0, accuracy: 1e-6)
    }

    func testHammingEndpointsAndCentre() {
        let w = Window.hamming.coefficients(count: 1025)
        XCTAssertEqual(w.first!, 0.08, accuracy: 1e-6)
        XCTAssertEqual(w.last!, 0.08, accuracy: 1e-6)
        XCTAssertEqual(w[512], 1.0, accuracy: 1e-6)
    }

    func testWindowAppliedToOnesEqualsCoefficients() {
        let ones = [Float](repeating: 1, count: 16)
        XCTAssertEqual(Window.hann.applied(to: ones), Window.hann.coefficients(count: 16))
    }

    // MARK: FFT

    private func sinusoid(bin: Int, amplitude: Float, count n: Int, cosine: Bool = true) -> [Float] {
        (0..<n).map { i in
            let phase = 2.0 * Float.pi * Float(bin) * Float(i) / Float(n)
            return amplitude * (cosine ? cos(phase) : sin(phase))
        }
    }

    func testInitRejectsNonPowerOfTwo() {
        XCTAssertNil(FFT(size: 1000))
        XCTAssertNotNil(FFT(size: 1024))
    }

    func testPeakAtCorrectBin() throws {
        let n = 1024, k0 = 64
        let fft = try XCTUnwrap(FFT(size: n))
        let mags = fft.magnitudeSpectrum(sinusoid(bin: k0, amplitude: 1.0, count: n))
        let peak = mags.enumerated().max(by: { $0.element < $1.element })!.offset
        XCTAssertEqual(peak, k0)
        XCTAssertEqual(mags[k0], Float(n) / 2, accuracy: 1.0)   // amplitude * N / 2
    }

    func testParsevalEnergy() throws {
        let n = 1024
        let fft = try XCTUnwrap(FFT(size: n))
        // Two exact-bin sinusoids — no DC, no Nyquist content.
        let a = sinusoid(bin: 64, amplitude: 1.0, count: n)
        let b = sinusoid(bin: 100, amplitude: 0.5, count: n, cosine: false)
        let signal = zip(a, b).map(+)

        let timeEnergy = signal.reduce(Float(0)) { $0 + $1 * $1 }
        let power = fft.powerSpectrum(signal)
        var spectral = power[0]
        for k in 1..<power.count { spectral += 2 * power[k] }   // one-sided sum, Nyquist dropped
        XCTAssertEqual(spectral / Float(n), timeEnergy, accuracy: timeEnergy * 0.02)
    }

    func testBinFrequencyRoundTrip() throws {
        let fft = try XCTUnwrap(FFT(size: 1024))
        XCTAssertEqual(fft.frequency(ofBin: 64, sampleRate: 44100), 2756.25, accuracy: 1e-6)
        XCTAssertEqual(fft.bin(forFrequency: 2756.25, sampleRate: 44100), 64)
    }
}
