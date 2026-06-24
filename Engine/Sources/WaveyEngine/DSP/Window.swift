import Accelerate

/// A tapering window applied to a frame before spectral analysis to reduce
/// spectral leakage. Symmetric definitions (denominator N-1), so the endpoints
/// and centre take their textbook values.
public enum Window: Sendable {
    case hann
    case hamming

    /// Window coefficients for a frame of `count` samples.
    public func coefficients(count: Int) -> [Float] {
        precondition(count > 1, "window needs at least 2 samples")
        let denom = Double(count - 1)
        let (a0, a1): (Double, Double)
        switch self {
        case .hann: (a0, a1) = (0.5, 0.5)
        case .hamming: (a0, a1) = (0.54, 0.46)
        }
        return (0..<count).map { n in
            Float(a0 - a1 * cos(2.0 * Double.pi * Double(n) / denom))
        }
    }

    /// `signal` multiplied element-wise by this window. Lengths must match.
    public func applied(to signal: [Float]) -> [Float] {
        let w = coefficients(count: signal.count)
        var out = [Float](repeating: 0, count: signal.count)
        vDSP_vmul(signal, 1, w, 1, &out, 1, vDSP_Length(signal.count))
        return out
    }
}
