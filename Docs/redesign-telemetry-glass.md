# Future redesign: "Telemetry glass"

Approved by the owner on 2026-10-12 as the direction for a future full redesign
of Team Radio. It is not in the shipping app yet. It will be introduced step by
step, starting with the new 1.2 features.

## Where to see it

| What | Where |
|---|---|
| Feature cards (the approved look) | `Marketing/drafts/2026-10-12/blend.png` |
| Whole Countdown tab in this style | `Marketing/drafts/2026-10-12/countdown-full-new-style.jpg` |
| Next to the current main screen | `Marketing/drafts/2026-10-12/blend-vs-current.jpg` |
| Live SwiftUI drafts (debug builds only) | `TeamRadio/Views/DesignLabBlend.swift` (`BlendDraft`, `FullDraft`) |

To open the drafts in the simulator, launch a debug build with `-DesignLab blend`
or `-DesignLab full -DesignPage 0`.

## The idea

It blends three things with the current app aesthetics: the dark carbon
background, chrome italic F1 type, cyan / violet / red neon and the orange LED
board.

1. **Liquid glass.** Panels are frosted glass (`glassEffect` on iOS 26, with
   `ultraThinMaterial` as the fallback). Soft coloured light sits behind each
   panel for the glass to bend. No drawn borders.
2. **Telemetry.**
   - Sections start with a numbered rule ("01 / PREDICTION GAME"), a meta label
     on the right, and a hairline with tick marks.
   - Data is set like a timing screen: monospaced labels, team-colour stripes
     and hairline row dividers.
   - Small charts carry the data: a reaction-time trace, vote bars, a radio
     waveform, a 6-segment progress bar.
3. **LED type.** Hero numbers and driver codes are drawn in round LEDs (a 5×7
   dot font) with dim sockets and a glow, matching the main countdown board.
   The best time is amber, and driver codes use their team colour.

## Rules

- Keep chrome italic F1 titles, `Theme.accent` / `violet` / `live`, and the app
  background.
- Glass panels have a 24–30 pt corner radius and a coloured light behind them:
  - cyan: game
  - teal: team colour
  - red: Lights Out and race
  - violet: AI
- Use monospaced type (`.system(design: .monospaced)`, tracking 1.2) only for
  labels and data, never for titles.
- Each card gets one idea. Avoid identical boxes; vary layout and visuals.
- The "Call in your crew" gradient card stays as the one bright, filled card.
