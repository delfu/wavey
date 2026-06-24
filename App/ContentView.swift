import SwiftUI
import WaveyEngine

/// Placeholder root view. Confirms the app links `WaveyEngine`; the real
/// Tuner / Library / Game navigation arrives in M1 (DEL-185).
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Wavey")
                .font(.largeTitle.bold())
            Text("Engine v\(WaveyEngine.version)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
