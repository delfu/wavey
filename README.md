# Wavey

Learn acoustic guitar like a rhythm game. Feed Wavey a song; it isolates the guitar, turns it into a chord sheet, and you play along on a real guitar while your phone listens — the sheet advances when you hit the right chord and flags you when you don't.

> **Status:** early development. The repo is being scaffolded via milestone **M0**; the Linear project "Wavey" holds live status and the task list.

## Features

- 🎚️ **Song ingestion** — import a song, isolate the guitar on-device, get a chord progression.
- 🎼 **Sheets** — chord progressions now; full note sheets later.
- 🎤 **Live detection** — the mic hears what you play and checks it against the sheet.
- 🎯 **Tuner** — standard-tuning acoustic guitar tuner.
- 🕹️ **Play-along game** — a scrolling sheet that progresses on correct play.

## Architecture

- **`Engine/`** — `WaveyEngine`, a pure, fully-tested Swift Package: DSP, pitch/chord detection, music theory, and the on-device ML pipeline. Builds and tests on macOS without a simulator.
- **`App/`** — a thin SwiftUI app (Tuner / Library / Game).

The live game only ever **verifies** your playing against the expected chord/note from the sheet — open-ended recognition is reserved for offline song ingestion. See [CLAUDE.md](CLAUDE.md) for the full design.

## Roadmap

| Milestone | Focus |
|---|---|
| **M0** | Foundation — Xcode project, engine package, CI, music-theory + sheet models, audio capture, DSP primitives |
| **M1** | Tuner — pitch detection + tuner UI (first vertical slice) |
| **M2** | Live detection — chromagram, onset, chord/note verification against an expected target |
| **M3** | Game loop — game state machine + game UI, played against hand-authored sheets |
| **M4** | Song ingestion — separation (Demucs → Core ML) + chord recognition → sheet |
| **M5** | Song ingestion — note transcription (Basic Pitch), a stretch goal |

## Build

```bash
# Engine (fast, no simulator)
cd Engine && swift test

# App (XcodeGen generates the project from project.yml)
xcodegen generate
xcodebuild -scheme Wavey -destination 'generic/platform=iOS Simulator' build
```

## Scope (v1)

Acoustic guitar only. **Not** in v1: other instruments, electric guitar, elaborate graphics, recording/playback, scoring.
