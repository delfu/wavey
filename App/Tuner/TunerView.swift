import SwiftUI
import WaveyEngine

/// The tuner screen: shows the nearest string, cents offset, and an in-tune
/// indicator, driven live by the microphone.
struct TunerView: View {
    @State private var model = TunerViewModel()

    var body: some View {
        VStack(spacing: 28) {
            Text("Tuner").font(.largeTitle.bold())

            VStack(spacing: 4) {
                Text(model.reading?.string.name ?? "—")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(model.reading?.isInTune == true ? Color.green : Color.primary)
                    .animation(.snappy, value: model.reading?.string)
                Text(centsLabel)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            CentsMeter(cents: model.reading?.cents, inTune: model.reading?.isInTune ?? false)
                .frame(height: 56)
                .padding(.horizontal, 24)
                .animation(.snappy, value: model.reading?.cents)

            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(model.isListening ? "Stop" : "Start Tuning") {
                model.toggle()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .onDisappear { model.stop() }
    }

    private var centsLabel: String {
        guard let cents = model.reading?.cents else {
            return model.isListening ? "Play a string…" : "Tap Start, then pluck a string"
        }
        let rounded = Int(cents.rounded())
        return rounded == 0 ? "in tune" : "\(rounded > 0 ? "+" : "")\(rounded) cents"
    }
}

/// A simple left/right meter: the marker sits at centre when in tune and slides
/// up to ±50 cents either side.
private struct CentsMeter: View {
    let cents: Double?
    let inTune: Bool

    var body: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let clamped = max(-50.0, min(50.0, cents ?? 0))
            let markerX = mid + (clamped / 50.0) * (mid - 16)

            ZStack {
                Capsule().fill(.quaternary).frame(height: 6)
                Rectangle().fill(.secondary).frame(width: 2, height: geo.size.height * 0.6)
                if cents != nil {
                    Circle()
                        .fill(inTune ? Color.green : Color.orange)
                        .frame(width: 26, height: 26)
                        .position(x: markerX, y: geo.size.height / 2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview { TunerView() }
