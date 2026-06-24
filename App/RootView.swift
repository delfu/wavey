import SwiftUI

/// Root navigation: Tuner / Songs / Play. Songs and Play are placeholders until
/// their screens are built. Tangerine accent per the Warm Daylight design.
struct RootView: View {
    var body: some View {
        TabView {
            TunerView()
                .tabItem { Label("Tuner", systemImage: "gauge.medium") }
            PlaceholderView(title: "Songs",
                            subtitle: "Your sheets will live here.",
                            systemImage: "music.note.list")
                .tabItem { Label("Songs", systemImage: "music.note") }
            PlaceholderView(title: "Play",
                            subtitle: "Play-along game coming soon.",
                            systemImage: "guitars.fill")
                .tabItem { Label("Play", systemImage: "guitars.fill") }
        }
        .tint(Theme.primary)
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textTertiary)
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecond)
            }
            .padding()
        }
    }
}

#Preview { RootView() }
