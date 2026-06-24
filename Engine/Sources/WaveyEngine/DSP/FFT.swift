import Accelerate

/// A reusable real-input FFT over power-of-two frames, backed by vDSP.
///
/// Create once (the setup is the expensive part) and reuse across frames. Not
/// `Sendable`: give each processing thread its own instance.
public final class FFT {
    /// FFT length N (a power of two).
    public let size: Int
    private let halfN: Int
    private let fft: vDSP.FFT<DSPSplitComplex>

    /// Returns nil if `size` is < 2 or not a power of two.
    public init?(size: Int) {
        guard size >= 2, (size & (size - 1)) == 0 else { return nil }
        guard let fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(size))),
                                 radix: .radix2,
                                 ofType: DSPSplitComplex.self) else { return nil }
        self.size = size
        self.halfN = size / 2
        self.fft = fft
    }

    /// Squared-magnitude (power) spectrum for bins `0..<size/2` (index 0 = DC).
    /// The Nyquist bin is not returned.
    public func powerSpectrum(_ signal: [Float]) -> [Float] {
        precondition(signal.count == size, "signal length must equal FFT size")
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        var power = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)

                // Deinterleave the real signal into split-complex form.
                signal.withUnsafeBufferPointer { sigBuf in
                    sigBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }

                fft.forward(input: split, output: &split)

                // vDSP's real forward transform is 2x the mathematical DFT.
                var scale = Float(0.5)
                vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(halfN))
                vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(halfN))

                power.withUnsafeMutableBufferPointer { powBuf in
                    vDSP_zvmags(&split, 1, powBuf.baseAddress!, 1, vDSP_Length(halfN))
                }
                // imagp[0] packs the Nyquist term, which isn't part of DC — drop it.
                power[0] = realBuf[0] * realBuf[0]
            }
        }
        return power
    }

    /// Magnitude spectrum for bins `0..<size/2` (index 0 = DC).
    public func magnitudeSpectrum(_ signal: [Float]) -> [Float] {
        var power = powerSpectrum(signal)
        var mags = [Float](repeating: 0, count: power.count)
        var n = Int32(power.count)
        vvsqrtf(&mags, &power, &n)
        return mags
    }

    /// Centre frequency of a bin, in Hz.
    public func frequency(ofBin bin: Int, sampleRate: Double) -> Double {
        Double(bin) * sampleRate / Double(size)
    }

    /// The bin whose centre frequency is nearest `frequency`.
    public func bin(forFrequency frequency: Double, sampleRate: Double) -> Int {
        Int((frequency * Double(size) / sampleRate).rounded())
    }
}
