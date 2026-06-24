import Foundation

/// Estimates the ambient noise floor from a short calibration window and derives
/// a gate threshold, so live detection can ignore room noise. Feed it ambient
/// frames while the user isn't playing, finish calibration, then gate incoming
/// frames against the result.
public struct InputCalibrator {
    /// How many dB above the measured noise floor the gate sits.
    public var marginDB: Double

    public private(set) var noiseFloorRMS: Float = 0
    public private(set) var gateRMS: Float = 0

    private var ambientSamples: [Float] = []

    public init(marginDB: Double = 12) {
        self.marginDB = marginDB
    }

    /// Observe one ambient frame (the user is not playing) during calibration.
    public mutating func observeAmbient(_ frame: [Float]) {
        ambientSamples.append(Self.rms(frame))
    }

    /// Compute the noise floor and gate from the observed ambient frames.
    public mutating func finishCalibration() {
        guard let floor = ambientSamples.max() else { return }
        noiseFloorRMS = floor
        gateRMS = floor * Float(pow(10.0, marginDB / 20.0))
        ambientSamples.removeAll(keepingCapacity: true)
    }

    /// Is this frame above the gate — i.e. is the user likely playing?
    public func isAboveGate(_ frame: [Float]) -> Bool {
        Self.rms(frame) > gateRMS
    }

    /// RMS "listening level" of a frame, for a UI meter.
    public func level(_ frame: [Float]) -> Float {
        Self.rms(frame)
    }

    private static func rms(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in frame { sum += sample * sample }
        return (sum / Float(frame.count)).squareRoot()
    }
}
