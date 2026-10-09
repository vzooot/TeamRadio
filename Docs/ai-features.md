# AI features: Ask the race engineer, Circuit guide

Status: draft for review, 2026-10-09. Backend: the Cloudflare Worker
`teamradio-push` calling Azure OpenAI (`teamradio-ai`, deployment `gpt-5-mini`).
The Azure key never ships in the app.

## Ask the race engineer

Fans ask Emily a question and she answers in team-radio style: short, calm,
concrete.

> "Why did Russell pit so early?"
> "Box, box: he was losing time on old mediums. The undercut was worth more
> than track position. Copy?"

Where: a "Radio Emily" button in the Paddock header and on the Results tab.
The answer appears as a radio message (her avatar, the waveform), with an
"AI · may be wrong" label.

Grounding, so she doesn't invent facts. The Worker adds the facts to every
question:
- the current weekend's schedule and the latest session results (Jolpica)
- the championship standings
- the last race's classification, grid positions and status (DNFs, penalties)

Rules for the model: answer only from the given data plus general F1
knowledge (rules, strategy, tyres); say "I don't have that data" otherwise;
max 3 sentences; never predict results as fact; no personal data.

Limits and safety:
- 100 questions per player per day (counted in KV by iCloud user id), plus a
  per-IP ceiling: generous for fans, a stop for scripts.
- Questions go through the same moderation as the chat; answers are never
  stored with the player's name.
- Cost: about $0.001 per question with gpt-5-mini. 1,000 questions ≈ $1.

Decided 2026-10-09: text only for now; voice (Azure text to speech,
~$0.015/answer) maybe later.

## Circuit guide

On the circuit card, tap a corner number on the 3D track: a sheet shows the
corner's name, what makes it hard, and one memorable moment.

> **Turn 1 · Senna S** — Hard braking downhill from 300 km/h into a
> left-right; the classic overtaking spot after the start.

Content:
- Corner positions already exist in the track maps (`TrackMap.corners`).
- Texts are generated once per circuit with a stronger model, then reviewed
  by hand before shipping: no invented names or moments. Uncertain corners
  get only the factual line (braking, speed, direction).
- Stored as JSON per circuit (`Resources/corners/<circuitId>.json`), shipped
  in the app, so it works offline and costs nothing per user.
- First the six remaining 2026 circuits (Austin, Mexico City, Interlagos,
  Las Vegas, Lusail, Yas Marina), then the full calendar for 2027.

Cost: a few dollars once.

## Privacy and App Store

- Questions are sent to Azure OpenAI (EU region, Sweden Central) without the
  player's name; the privacy policy and App Store privacy label get a line.
- AI answers are labelled as AI in the app.

## Release plan

| Release | Content | Target |
|---|---|---|
| 1.2.0 | Prediction game + Ask the race engineer | submit ~Oct 19, live for Austin |
| 1.2.1 | Circuit guide for the six remaining circuits | before Mexico City (Oct 30) |

