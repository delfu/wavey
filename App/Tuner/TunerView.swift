import SwiftUI
import UIKit
import WaveyEngine

/// The tuner screen, built to the Figma "Warm Daylight" design: nearest string,
/// cents meter, in-tune / sharp status, and a microphone-permission state.
struct TunerView: View {
    @State private var model = TunerViewModel()

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if model.permissionDenied {
                permissionNeeded
            } else {
                tuner
            }
        }
        .onDisappear { model.stop() }
    }

    // MARK: - Tuner

    private var tuner: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer().frame(height: 28)
            noteDisplay
            Spacer().frame(height: 24)
            statusCard
            Spacer().frame(height: 20)
            stringPills
            Spacer(minLength: 24)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tuner")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Standard tuning · E A D G B E")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteDisplay: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(model.reading?.string.pitchClass.name ?? "—")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(model.reading == nil ? Theme.textTertiary : Theme.ink)
                if let octave = model.reading?.string.octave {
                    Text("\(octave)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Text(stringDescription)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: model.reading?.string)
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            Text(statusTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(statusColor)
            Text(statusSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecond)
            HStack(spacing: 10) {
                Text("♭").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
                meter
                Text("♯").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
    }

    private var meter: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let clamped = max(-50.0, min(50.0, model.reading?.cents ?? 0))
            let markerX = mid + (clamped / 50) * (mid - 16)
            let inTune = model.reading?.isInTune ?? false
            ZStack {
                Capsule().fill(Theme.sunken).frame(height: 6)
                if inTune {
                    Capsule().fill(Theme.matchTint).frame(width: 84, height: 6)
                }
                Rectangle().fill(Theme.textTertiary)
                    .frame(width: 2, height: 16)
                    .position(x: mid, y: geo.size.height / 2)
                if model.reading != nil {
                    Circle()
                        .fill(inTune ? Theme.match : Theme.warn)
                        .frame(width: 22, height: 22)
                        .position(x: markerX, y: geo.size.height / 2)
                        .animation(.snappy, value: clamped)
                }
            }
        }
        .frame(height: 24)
    }

    private var stringPills: some View {
        HStack(spacing: 8) {
            ForEach(Array(StandardTuning.openStrings.enumerated()), id: \.offset) { _, note in
                let active = model.reading?.string == note
                Text(note.pitchClass.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(active ? Theme.onColor : Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(active ? Theme.primary : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(active ? Color.clear : Theme.hairline, lineWidth: 1))
            }
        }
        .animation(.snappy, value: model.reading?.string)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if model.isListening {
                HStack(spacing: 6) {
                    Circle().fill(Theme.secondary).frame(width: 8, height: 8)
                    Text("Listening…").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.secondaryTint, in: Capsule())
                .transition(.opacity)
            }
            Button(model.isListening ? "Stop" : "Start Tuning") { model.toggle() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.bottom, 8)
        .animation(.snappy, value: model.isListening)
    }

    // MARK: - Permission

    private var permissionNeeded: some View {
        VStack(spacing: 0) {
            Text("Tuner")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.sunken).frame(width: 96, height: 96)
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text("Microphone access needed")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Wavey listens through your mic to detect pitch. Turn on microphone access to tune your guitar.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecond)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()

            VStack(spacing: 12) {
                Button("Enable microphone") { model.start() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Open Settings") { openSettings() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Derived text

    private var stringDescription: String {
        guard let note = model.reading?.string,
              let index = StandardTuning.openStrings.firstIndex(of: note) else {
            return model.isListening ? "Pluck a string" : "Tap Start, then pluck a string"
        }
        let labels = ["6th string · low E", "5th string · A", "4th string · D",
                      "3rd string · G", "2nd string · B", "1st string · high E"]
        return labels[index]
    }

    private var statusTitle: String {
        guard let r = model.reading else { return model.isListening ? "Listening…" : "Ready to tune" }
        if r.isInTune { return "In tune" }
        let cents = Int(r.cents.rounded())
        return "\(cents > 0 ? "+" : "")\(cents)¢"
    }

    private var statusColor: Color {
        guard let r = model.reading else { return Theme.textSecond }
        return r.isInTune ? Theme.match : Theme.warn
    }

    private var statusSubtitle: String {
        guard let r = model.reading else { return "We'll show the nearest string" }
        if r.isInTune { return "Hold steady — you're locked in" }
        return r.cents > 0 ? "A touch sharp — ease the peg down" : "A touch flat — bring it up"
    }
}

#Preview { TunerView() }
