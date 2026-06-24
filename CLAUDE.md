# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Wavey is an iOS app for learning **acoustic guitar**, gamified like Guitar Hero. You feed in a song; the app isolates the guitar part, turns it into a chord (and later, note) sheet, then you play along on a real guitar while the phone mic listens and the sheet advances when you play the right chord/note.

Five capabilities: (1) ingest a song and isolate the guitar, (2) turn that into a chord progression / note sheet, (3) live-detect what the user plays via the mic, (4) a guitar tuner, (5) a game UI that advances on correct play and flags wrong notes.

**Out of scope (v1):** non-guitar instruments, electric guitar, Guitar-Hero-grade graphics, recording/playback, scoring.

## Source of truth

**The Linear project "Wavey" is the status + task list.** Each issue is self-contained — read the project description, the files the issue names, and this file, and you can start cold. Team `Delongfu` (key `DEL`). Milestones **M0 → M5** group the work and are done roughly in order. Issues are tagged `engine`, `app`, `ml`, or `infra`.

## Architecture

Two layers, matching the `engine`/`app` issue tags:

**`Engine/` — the `WaveyEngine` Swift Package. No UI. Every component unit-tested.** All DSP, ML, and music theory lives here so it builds and tests on the host Mac without a simulator (fast TDD). Platform-agnostic apart from thin AVFoundation/CoreML wrappers.

**`App/` — the SwiftUI app target. Thin.** Navigation, screens (Tuner / Library / Game), game-session presentation. It delegates every audio decision to the engine and holds no DSP.

### The one idea that makes this tractable

Real-time polyphonic chord *recognition* (open-ended "what chord is this?") is hard. The game never needs it: it always knows the **expected** chord/note from the sheet, so the live path only **verifies** incoming audio against that target (match / wrong / silence). Verification is cheap and robust. Open-ended recognition is used **only offline**, during song ingestion, where there is time and the full track.

### Engine module map

- `Audio/` — AVAudioEngine capture wrapper; delivers fixed-size `Float` frames. Buffer-processing logic is injectable so it tests without a live mic.
- `DSP/` — windowing, vDSP FFT, magnitude spectrum, chromagram, onset detection.
- `Pitch/` — monophonic pitch detection (YIN). Powers the tuner and single-note matching.
- `Theory/` — `Note`, `PitchClass`, `Chord` (root + quality + voicing), frequency↔note, equal-temperament tables.
- `Tuner/` — frequency → nearest string + cents; standard tuning E2 A2 D3 G3 B3 E4.
- `Match/` — live verifiers: chord verifier (chroma vs expected) and note verifier (pitch vs expected), with frame-stability/debounce.
- `Sheet/` — the song/sheet data model: a timeline of timed chord/note events, Codable JSON.
- `Ingest/` — offline pipeline: separation → beat grid → chord (later, note) recognition → `Sheet`.
- `ML/` — Core ML wrappers (Demucs 6-stem separation; later, Basic Pitch note transcription).

### Live game data flow

`AudioCapture` → `Onset` (did a new strum happen?) → `Chromagram`/`Pitch` → `Match` verifier (vs the expected event from the sheet) → `GameSession` state machine (advance on match, flag on wrong).

### Offline ingestion data flow

audio file → `Separation` (Demucs Core ML → guitar stem) → `BeatTracker` (tempo + beat grid) → `ChordRecognizer` → `Sheet` JSON saved to the library. Note transcription (Basic Pitch) is layered in at M5.

## Key technical decisions

- **Guitar separation runs on-device** via a Demucs 6-stem model converted to Core ML — no backend, no hosting cost, no uploading copyrighted audio. It is offline (not real-time): a song is processed once into a sheet.
- **Chords before notes.** v1 ingestion yields chord progressions; polyphonic note transcription (Spotify **Basic Pitch**) is the M5 stretch.
- **Acoustic only.** Pitch/chroma parameters are tuned for acoustic-guitar timbre and range.
- **iOS 17+, Swift + SwiftUI.** Accelerate (vDSP) for DSP, Core ML for models, XCTest for the engine.

## Commands

The app's Xcode project is generated from `project.yml` via XcodeGen — the `.xcodeproj` is gitignored, so run `xcodegen generate` after cloning (and `brew install xcodegen` if you don't have it).

```bash
# Engine — fast, no simulator (the primary TDD loop)
cd Engine && swift build
cd Engine && swift test
# a single test:
cd Engine && swift test --filter WaveyEngineTests.PitchDetectorTests/testDetectsA440

# App — generate the project, then build/test on a simulator
xcodegen generate
xcodebuild -scheme Wavey -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme Wavey -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Before each commit, run the local check** — engine tests + app build in one command. This is the verification gate until GitHub Actions is set up (deferred — DEL-180):

```bash
scripts/check.sh
```

## Conventions

- **Engine changes ship with tests.** DSP/theory/match logic is verified against synthesized signals and labeled audio fixtures in `Fixtures/`. ML runners get integration tests against known clips (tolerance-based, not exact-match).
- **The app stays thin.** If you find yourself writing signal logic in a SwiftUI view, it belongs in the engine.
- **Sheets are JSON** conforming to the `Sheet` model; hand-authored sheets (M3) and pipeline-generated sheets (M4+) share one format.

## Commit messages

Use the global format (`[scope] type: subject` + a why-focused body), and **always end the message with a `Test Plan` section** — a few concrete steps someone can follow to verify what this commit changed: the exact command(s) to run, and/or the manual checks for UI work. Engine commits cite the relevant `swift test --filter …`; app commits give the build + simulator/on-device steps. For pure docs/config changes, a one-line "docs only" check is fine.

    Test Plan:
    - cd Engine && swift test --filter TheoryTests
    - 9 cases pass: MIDI/frequency/cents round-trips, chord pitch classes, tuning.
