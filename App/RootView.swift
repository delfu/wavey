import SwiftUI

/// Root navigation: the three top-level destinations. Library and Game are
/// placeholders until M3.
struct RootView: View {
    var body: some View {
        TabView {
            TunerView()
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
            PlaceholderView(title: "Songs", subtitle: "Your sheets will live here.")
                .tabItem { Label("Songs", systemImage: "music.note.list") }
            PlaceholderView(title: "Play", subtitle: "Play-along game coming in M3.")
                .tabItem { Label("Play", systemImage: "guitars") }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview { RootView() }
