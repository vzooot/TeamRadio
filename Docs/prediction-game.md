# Prediction game: design

Status: draft for review, 2026-10-08. Branch `feature/prediction-game`.

## Goal

Give fans a reason to open Team Radio every race weekend: make picks before
qualifying, follow them during the weekend, see points and the leaderboard
after the race. No AI and no money involved in the core game.

Success: weekly active players, picks per race weekend, share rate of result
cards, 2nd-weekend retention.

## Rules

One set of picks per player per Grand Prix. Picks lock when qualifying starts.
Until then they can be changed freely.

| Pick | Points | Resolved from |
|---|---|---|
| Pole position | 5 | Qualifying P1 |
| Winner (P1) | 10 | Race result |
| P2 | 6 | Race result |
| P3 | 6 | Race result |
| Podium driver in the wrong podium slot | 2 each | Race result |
| Perfect podium bonus (P1, P2, P3 all exact) | +10 | Race result |
| Fastest lap | 5 | Race result, `FastestLap.rank == 1` |
| Wildcard question | 5 | See below |

Maximum per race: 47 points.

**Wildcard:** one question per weekend, chosen from a fixed list so that every
answer can be scored automatically from the results data:

- Will the pole-sitter win? (yes / no)
- How many cars fail to finish? (0–1 / 2–3 / 4+)
- Teammate duel: who finishes ahead, A or B? (picked per weekend)
- Winning margin over 5 seconds? (yes / no)

Rules that keep it fair and simple:

- Sprint races are not part of v1.
- A cancelled or shortened race scores what can be scored; no picks are voided.
- Ties on the leaderboard are broken by number of exact picks, then by who
  locked in first.
- No prizes, no money, no wagering. This keeps it out of gambling rules and
  App Store guideline 5.3.

## Where it lives in the app

The tab bar already has five tabs, so the game does not get a sixth.

- **Countdown tab:** a "Your picks" card under the countdown. Before lock: a
  call to action with the time left to pick. After lock: your picks. After the
  race: your points and rank.
- **Paddock tab:** a third segment, *Room · Messages · Leaderboard*, so the
  rivalry sits next to the chat.
- **Picks flow:** a sheet with one step per pick, then a review and
  "Lock in".
- **Result reveal:** after the race, each pick flips to show right or wrong
  with its points, ending on a shareable result card.

Screens to design: Countdown card (4 states: open, picked, locked, scored),
picks sheet (pole, podium, fastest lap, wildcard, review), result reveal,
leaderboard (global and league, round and season), league create/join, rules,
empty and error states.

## Data model

Picks live in CloudKit's public database, the same as the chat. Every player
already has a Paddock name and an iCloud identity there.

| Record type | Key | Fields | Written by |
|---|---|---|---|
| `Prediction` | `pred-<round>-<userId>` (one per player per round) | userId, name, round, pole, p1, p2, p3, fastestLap, wildcard, wildcardAnswer | the player |
| `Score` | `score-<round>-<userId>` | userId, name, round, points, exactPicks, breakdown, seasonPoints | scorer only |
| `Leaderboard` | `board-<round>`, `board-season` | top 100 as a compact list, total players | scorer only |
| `League` | `league-<code>` | name, ownerId, code, created | the owner |
| `LeagueMember` | `member-<code>-<userId>` | leagueId, userId, name | the player |

Driver values are Jolpica driver ids (for example `norris`), so picks map
directly onto results.

The deterministic record names make "one entry per player per round" a
database guarantee, not a client promise.

## Fairness and anti-cheat

There is no server in the app today, and CloudKit's public database lets each
player write their own records. Two things must therefore be enforced outside
the player's phone:

1. **Locking.** A pick only counts if CloudKit's server-set
   `modificationDate` is before the qualifying start. The phone clock is never
   trusted. Editing a prediction after the lock moves its `modificationDate`
   past the lock and voids it.
2. **Scores.** Players never write their own score. A scorer computes every
   score from the predictions and the official results, and only the scorer
   can write `Score` and `Leaderboard` records (CloudKit security roles:
   authenticated users get no create or write permission on those types).

### Scorer: options

| Option | How | Verdict |
|---|---|---|
| A. Phone computes its own score | Each player's app writes its score | Rejected: anyone can write any score. |
| B. Every phone computes everyone | Each app downloads all predictions | Rejected: does not scale past a few hundred players. |
| **C. Azure Function scorer** | A timer function runs after each race: reads results from Jolpica, reads all predictions through CloudKit Web Services with a server-to-server key, writes scores and leaderboards | **Recommended.** Tamper-proof, scales, costs cents. It is also the backend the planned AI features need, and it keeps scoring logic portable for the future move off CloudKit. |
| D. Move the game to Firebase now | Firestore + Cloud Functions | Not now: needs a new sign-in system. Revisit with the Android port. |

To verify in a spike before building (half a day):

- A CloudKit server-to-server key can query `Prediction` and write `Score`
  and `Leaderboard` in the Production public database.
- Security roles can block authenticated users from writing `Score` and
  `Leaderboard` while the server key still can.
- Querying all predictions of a round needs queryable indexes on `round` and
  `userId` and a sortable index on `modificationDate`.

## Leaderboards and leagues

- **Global:** per round and for the season. Loaded as one `Leaderboard`
  record (top 100 plus the player's own `Score`), so it is a single fetch.
- **Leagues:** private groups for friends. Create one, share a 6-character
  invite code or link, and see a table of just its members. League tables are
  built in the app from the members' `Score` records (at most a few dozen per
  league).
- The player's own row is always pinned, even outside the top 100.

## Notifications

- Picks open: Thursday of race week ("Picks are open for Singapore").
- Reminder: 3 hours before the lock, only if the player has not picked.
- Scored: when the scorer finishes ("You scored 23 points, you're 41st").

The first two are local notifications scheduled from the race calendar. The
third is a CloudKit subscription on the player's own `Score` record.

## Costs

| Part | Cost |
|---|---|
| CloudKit storage and requests | Free within the public-database quota at this scale |
| Azure Function scorer | Within the free monthly grant (one run per race) |
| Optional AI comment per player | about $0.0006 per player per race with gpt-4.1-mini |

## AI extras

Both run in the scorer backend, never in the app, so the Azure OpenAI key
stays a server secret (a Worker secret if the scorer is the Cloudflare
Worker). Scoring itself never uses AI.

### Post-race comment

After scoring, each player gets one or two sentences about their weekend,
shown on the result card and the result reveal:

> "You called Verstappen on pole, then had him nowhere near the podium. The
> fastest-lap pick saved your weekend."

- Input is structured only: the player's picks, the results and the
  breakdown. Nicknames are not sent; the comment says "you".
- Tone: playful team-radio banter, never insulting. A fixed system prompt and
  a length limit keep it on brand.
- Model: gpt-4.1-mini, several players per request. About $0.0006 per player
  per race.
- Stored as `comment` on the player's `Score` record. If generation fails,
  the card simply shows no comment.

### AI Strategist

The AI Strategist: an AI player on the leaderboard that everyone can try to beat.

- On Thursday of race week the scorer asks a stronger model for a full set of
  picks, giving it only data available before the lock: standings, recent
  results, last year's result at the circuit.
- Its picks are saved like anyone's (`pred-<round>-ai-analyst`), before the
  lock, and scored by the same rules.
- It shows one line of reasoning per pick ("Pole: VER, three poles in the
  last four races"), visible after the lock so nobody copies it.
- On the leaderboard it has its own badge, and players see "You beat the
  analyst" on their result.
- Cost: one request per race, a few cents at most.

Decided 2026-10-09: it is called **AI Strategist**, and it sits beside the
global ranking as a benchmark (a marked row), never taking a real player's
place.

## Privacy and App Store

- Predictions and scores are public under the player's Paddock name. The
  privacy policy gets one paragraph on that.
- Picks and results (no names) are sent to Azure OpenAI for the post-race
  comment; the privacy policy and App Store privacy label mention it.
- AI-written text is labelled as such in the app.
- The App Store age rating questionnaire is reviewed for contests; no change
  is expected because nothing is wagered.
- Launch is promoted with an In-App Event, badge **Competition**.

## Launch plan

7 races remain in 2026. Singapore is this weekend; the season ends in Abu Dhabi
on Dec 6.

| Milestone | Content | Target |
|---|---|---|
| M0 | Spike: server key, security roles, indexes | this week |
| M1 | Figma design of all screens, review | this week |
| M2 | Picks flow, lock, Countdown card (app) | next week |
| M3 | Scorer function on Azure, notifications | next week |
| M4 | Leaderboard, leagues, result reveal | week 3 |
| M5 | TestFlight beta with friends for Mexico City / Brazil, polish, 1.2.0 | early Nov |
| Launch | **"Season Finale Challenge"** In-App Event for Las Vegas, Qatar and Abu Dhabi (Nov 20 – Dec 6), promoted from Nov 6 | Nov 20 |

The finale run is the public beta. The full launch is a **"New Season"**
In-App Event for the 2027 season opener, with what the finale taught us.

## Open questions for review

1. Scoring values above: fine, or simpler (for example winner only plus
   podium)?
2. Lock at qualifying start (pole pick included), or at race start without a
   pole pick (simpler, but people can copy the grid)?
3. Leaderboard as a Paddock segment, or somewhere else?
4. Scorer on Azure (recommended) as the first piece of the AI backend?
