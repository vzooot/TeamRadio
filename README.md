# Team Radio 📻🏎️

**A fast, F1-broadcast-inspired iOS app: countdowns to every session of the next Grand Prix, an interactive 3D circuit map, full race results, and live paddock news.**

Built entirely with SwiftUI and SceneKit — no dependencies, no packages, just one clean target.

## Features

### 📱 Lock Screen & Home Screen widgets
- **Lock Screen widgets** (inline, circular, rectangular) and small/medium Home Screen widgets counting down to the next session — the countdown text updates itself, no app launch needed
- Widgets flip to a **LIVE** state during sessions and back automatically

### 📍 Live Activity (Dynamic Island)
- **Pin any session** from the countdown card to get a Wolt-style Live Activity: a ticking countdown card on the Lock Screen and in the Dynamic Island, flipping to LIVE at green light

### 🔔 Session alerts
- Opt-in **local notifications 15 minutes before every session** of the season — scheduled fully on-device, no server, no account

### ℹ️ About & legal
- In-app About screen with the non-affiliation disclaimer, data accuracy notice, and source attributions (as required by the Jolpica CC BY-NC-SA license); privacy manifest included — the app collects no data

### 🔴 Live awareness
- When a session is on track, the app's first screen shows an unmissable pulsing **LIVE NOW** banner, the countdown card auto-selects the live session, and the timetable row gets a live indicator
- A broadcast-style **session clock with milliseconds** ticks in the banner and countdown card while a session runs

### ⏱️ Countdown
- **A countdown for every session** — tap any chip (FP1, Sprint Quali, Sprint, Qualifying, Race) to target it; defaults to the next session that hasn't started, with live and complete states
- **Start-light gantry** that progressively lights up through race week — all five burn in the final 24 hours
- **Race weekend timetable** in your local timezone with a mini-countdown on every row and a pulsing LIVE indicator during sessions
- **Sprint weekend detection** with its own badge
- **Drivers' championship top 5** with constructor color bars, and the **full season strip** auto-scrolled to the next round

### 🌀 The Circuit in 3D
- The **real track centerline** (664+ measured points per circuit) rendered as a 3D ribbon in SceneKit with a glowing racing line, corner-number markers, and the start/finish gate
- **Auto-rotates** — drag to orbit, pinch to zoom
- Stats derived from the actual geometry: **track length**, **corner count**, **direction of travel**, and **pit-lane time loss**

### 🏆 Results
- **Every completed Grand Prix of the season** — a round picker loads any race's podium, classification, and qualifying on demand
- Podium visualization, gaps, points, fastest-lap highlight, and grid-delta arrows showing positions gained or lost
- **Qualifying mode** with each driver's best time and the segment it came from (Q1/Q2/Q3)

### 🔢 Standings
- **Complete championships** — every driver and every constructor, with car numbers, wins, points, and gap to the leader

### 💬 Paddock Chat
- **A live chat room per race weekend**, built on CloudKit's public database — no accounts, no servers, users are their iCloud identity with a chosen paddock name
- Community-rules gate, profanity masking, long-press to **report or block** (App Review guideline 1.2 compliant)

### 🌦️ Session weather
- Hourly **forecast at the circuit** on every timetable row (Open-Meteo, no key): conditions, temperature, rain probability — highlighted when rain risk is real

### 🙈 Spoiler mode
- Eye toggle on Results: classifications stay **blurred until tapped**, re-arming when you switch rounds — for fans watching delayed

### 📰 Paddock News
- Latest F1 stories aggregated from **Formula1.com, BBC Sport, and Motorsport.com** RSS feeds — merged, deduplicated, sorted newest-first, with thumbnails
- No API keys, no accounts

## Data sources

| Source | Used for |
|---|---|
| [Jolpica F1 API](https://github.com/jolpica/jolpica-f1) | Race calendar, session times, standings, results, qualifying |
| [MultiViewer circuits API](https://api.multiviewer.app) | Track centerline geometry, corners, pit loss |
| F1.com / BBC / Motorsport.com RSS | News stories |

All free, no keys required. OpenF1 was considered but is pay-walled during live sessions — exactly when an F1 app gets opened.

## Architecture

```
TeamRadio/
├── TeamRadioApp.swift                   # entry point + TabView
├── Theme.swift                     # palette, typography, team colors, flags
├── Models/
│   ├── F1Models.swift              # Codable models for the Ergast/Jolpica schema
│   ├── TrackMap.swift              # circuit geometry + derived length/direction
│   └── NewsItem.swift
├── Services/
│   ├── F1API.swift                 # async Jolpica client
│   ├── TrackAPI.swift              # MultiViewer client + circuitId→key map
│   └── NewsService.swift           # concurrent RSS aggregation + parser
├── ViewModels/
│   ├── RaceViewModel.swift         # @Observable, async-let fan-out
│   ├── ResultsViewModel.swift
│   ├── StandingsViewModel.swift
│   └── NewsViewModel.swift
└── Views/
    ├── ContentView.swift           # countdown tab layout
    ├── CountdownView.swift         # selectable session countdown + gantry
    ├── RaceHeroView.swift
    ├── WeekendScheduleView.swift   # timetable + per-row mini countdowns
    ├── Track3DView.swift           # SceneKit scene built from real coordinates
    ├── TrackSectionView.swift
    ├── StandingsView.swift
    ├── SeasonView.swift
    ├── ResultsView.swift           # podium, classifications, constructors
    ├── StandingsTabView.swift      # full drivers' and constructors' tables
    └── NewsView.swift
```

- Swift / SwiftUI / SceneKit, iOS 17+
- `@Observable` + structured concurrency (`async let`, `withTaskGroup`)
- `TimelineView` drives all countdowns — no timers to manage
- The 3D track ribbon is explicit triangle-strip geometry offset from the centerline, so rendering is deterministic on every circuit
- Zero third-party dependencies

## Running it

1. Open `TeamRadio.xcodeproj` in Xcode 16 or newer
2. Pick any iOS 17+ simulator or device
3. `⌘R`

## Releasing

No fastlane, no CI dependency — three scripts talk to App Store Connect directly
(credentials in `fastlane/asc_key.json` and `fastlane/AuthKey_*.p8`, both gitignored).

1. Bump `MARKETING_VERSION` in the project (a released version's train is closed) and
   push to main — Xcode Cloud ("Release to TestFlight") builds, lints, uploads the build
   and hands it to the internal testers. Note the build number it produced.
2. `python3 scripts/asc/release.py prepare 1.2.0 --keywords "…" --subtitle "…"` —
   creates the version (manual release), sets notes from
   `fastlane/metadata/en-US/release_notes.txt`, uploads `fastlane/screenshots/`.
3. `python3 scripts/asc/release.py submit 1.2.0 <build>` — waits for processing,
   attaches the build, submits for review. `… release 1.2.0` once approved.

If Xcode Cloud is down, `scripts/release.sh` archives and uploads from this Mac with
the highest build number on App Store Connect + 1; afterwards raise the workflow's
"Next Build Number" in Xcode Cloud past it.

Screenshots: capture the six screens into `Marketing/raw/` (`panel-*.png` from an
iPhone 6.9" simulator, `ipad-*.png` from a 13" iPad), then `scripts/store/compose_panels.py`
and `compose_panels_ipad.py` render the store panels into `fastlane/screenshots/`.
`scripts/design/make_carbon.py` regenerates the countdown card's carbon texture.

Lint: `.swiftlint.yml` runs on every Xcode Cloud build (`ci_scripts/ci_pre_xcodebuild.sh`);
errors fail the build, warnings don't.

## Roadmap ideas

The Jolpica API also serves lap-by-lap times and pit stop data — material for race strategy visualizations (stint charts, position graphs) down the road.

## License

MIT — see [LICENSE](LICENSE).

*Team Radio is an unofficial hobby project and is not associated in any way with Formula 1, the FIA, or any F1 team.*
