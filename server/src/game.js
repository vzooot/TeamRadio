// Prediction game backend: scores every player's picks after each race,
// keeps the leaderboards, and runs the two AI extras (post-race comment,
// AI Strategist). Spec: Docs/prediction-game.md.
//
// Picks are read from CloudKit's public database with a server-to-server
// key (read-only). Scores are written only here, into KV, so no player can
// write their own score. The app reads leaderboards from the /game routes.
//
// Secrets: CK_KEY_ID (Development) + CK_KEY_ID_PRODUCTION + CK_PRIVATE_KEY
// (PKCS#8 PEM, P-256; one key pair registered in both environments); AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_KEY,
// AZURE_OPENAI_MODEL — optional, without them the AI extras are skipped.
// Vars: CK_ENVS, e.g. "development,production".

const CONTAINER = "iCloud.com.woqomoqo.OneF";
const JOLPICA = "https://api.jolpi.ca/ergast/f1";
const STRATEGIST_NAME = "AI Strategist";

// Mirrors GameRules in TeamRadio/Models/Prediction.swift. Keep in sync.
export const RULES = {
  pole: 5, winner: 10, second: 6, third: 6, podiumWrongSlot: 2,
  perfectPodium: 10, fastestLap: 5, wildcard: 5, sprintWinner: 5,
};

export const WILDCARDS = ["poleSitterWins", "retirements", "winningMargin"];

const WILDCARD_TEXT = {
  poleSitterWins: { question: "Will the pole-sitter win?", answers: { yes: "Yes", no: "No" } },
  retirements: { question: "How many cars fail to finish?", answers: { "0-1": "0–1", "2-3": "2–3", "4+": "4+" } },
  winningMargin: { question: "Winning margin over 5 seconds?", answers: { yes: "Yes", no: "No" } },
};

export function wildcardForRound(round) {
  return WILDCARDS[(Math.max(Number(round), 1) - 1) % WILDCARDS.length];
}

// Same as RaceResult.finished in F1Models.swift.
const finished = (r) => r.status === "Finished" || r.status.startsWith("+") || r.status === "Lapped";

export function resolveWildcard(kind, qualifying, race) {
  if (!race.length) return null;
  const at = (list, p) => list.find((r) => r.position === String(p));
  switch (kind) {
    case "poleSitterWins": {
      const pole = at(qualifying, 1)?.Driver.driverId;
      const winner = at(race, 1)?.Driver.driverId;
      if (!pole || !winner) return null;
      return pole === winner ? "yes" : "no";
    }
    case "retirements": {
      const out = race.filter((r) => !finished(r)).length;
      return out <= 1 ? "0-1" : out <= 3 ? "2-3" : "4+";
    }
    case "winningMargin": {
      const second = at(race, 2);
      if (!second) return null;
      const gap = second.Time?.time;
      if (!gap) return "yes";
      return parseFloat(gap.replace(/[+s]/g, "")) > 5 ? "yes" : "no";
    }
  }
  return null;
}

export function score(p, wildcard, qualifying, race, sprint = []) {
  const items = [];
  if (p.sprintWinner != null || sprint.length) {
    const winner = sprint.find((r) => r.position === "1")?.Driver.driverId ?? null;
    const hit = p.sprintWinner != null && p.sprintWinner === winner;
    items.push({ kind: "sprint", picked: p.sprintWinner ?? null, actual: winner, points: hit ? RULES.sprintWinner : 0, outcome: hit ? "exact" : "miss" });
  }
  const id = (r) => r?.Driver.driverId ?? null;
  const pole = id(qualifying.find((r) => r.position === "1"));
  const podium = [1, 2, 3].map((n) => id(race.find((r) => r.position === String(n))));

  const poleHit = p.pole != null && p.pole === pole;
  items.push({ kind: "pole", picked: p.pole ?? null, actual: pole, points: poleHit ? RULES.pole : 0, outcome: poleHit ? "exact" : "miss" });

  const slotPoints = [RULES.winner, RULES.second, RULES.third];
  const picks = [p.p1 ?? null, p.p2 ?? null, p.p3 ?? null];
  picks.forEach((pick, i) => {
    let outcome = "miss", points = 0;
    if (pick != null && pick === podium[i]) [outcome, points] = ["exact", slotPoints[i]];
    else if (pick != null && podium.includes(pick)) [outcome, points] = ["partial", RULES.podiumWrongSlot];
    items.push({ kind: ["p1", "p2", "p3"][i], picked: pick, actual: podium[i], points, outcome });
  });
  if (picks.every((x) => x != null) && picks.every((x, i) => x === podium[i])) {
    items.push({ kind: "perfectPodium", picked: null, actual: null, points: RULES.perfectPodium, outcome: "exact" });
  }

  const fastest = id(race.find((r) => r.FastestLap?.rank === "1"));
  const fastHit = p.fastestLap != null && p.fastestLap === fastest;
  items.push({ kind: "fastestLap", picked: p.fastestLap ?? null, actual: fastest, points: fastHit ? RULES.fastestLap : 0, outcome: fastHit ? "exact" : "miss" });

  const answer = resolveWildcard(wildcard, qualifying, race);
  const wildHit = p.wildcard != null && p.wildcard === answer;
  items.push({ kind: "wildcard", picked: p.wildcard ?? null, actual: answer, points: wildHit ? RULES.wildcard : 0, outcome: wildHit ? "exact" : "miss" });

  const total = items.reduce((s, i) => s + i.points, 0);
  const exact = items.filter((i) => i.outcome === "exact" && i.kind !== "perfectPodium").length;
  return { total, exact, items };
}

// Each pick locks when its session starts: pole at qualifying, the podium,
// fastest lap and wildcard at the race. Same as GameRules.lockDate in Swift.
const at = (s) => (s?.date ? new Date(`${s.date}T${s.time || "00:00:00Z"}`) : null);
export const GROUP_FIELDS = { sprint: ["sprintWinner"], quali: ["pole"], race: ["p1", "p2", "p3", "fastestLap", "wildcard"] };

export function groupLock(race, group) {
  if (group === "sprint") return at(race.Sprint);
  return group === "quali" ? at(race.Qualifying) : at({ date: race.date, time: race.time });
}

/// The first lock of the weekend (qualifying): the AI Strategist picks
/// before it and reveals after it.
export function lockDate(race) {
  return groupLock(race, "quali");
}

/// Merges each player's records into one prediction, keeping only groups
/// saved before their lock (server time) and owned by that player.
/// Records: pred-<round>-<user>-quali / -race, or the early single record
/// pred-<round>-<user> holding both groups.
export function mergePicks(records, race) {
  const id = `${race.season}-${race.round}`;
  const locks = { sprint: groupLock(race, "sprint")?.getTime() ?? 0, quali: groupLock(race, "quali")?.getTime() ?? 0, race: groupLock(race, "race")?.getTime() ?? 0 };
  const players = {};
  let voided = 0;
  for (const r of records) {
    if (!r.userId) continue;
    const base = `pred-${id}-${r.userId}`;
    const groups = r.recordName === base ? ["quali", "race"]
      : r.recordName === `${base}-quali` ? ["quali"]
      : r.recordName === `${base}-race` ? ["race"]
      : r.recordName === `${base}-sprint` ? ["sprint"] : [];
    for (const g of groups) {
      if (r.modified >= locks[g]) { voided++; continue; }
      const p = players[r.userId] ||= { userId: r.userId, name: r.name, locked: 0 };
      for (const f of GROUP_FIELDS[g]) p[f] = r[f];
      p.locked = Math.max(p.locked, r.modified);
      if (r.name) p.name = r.name;
    }
  }
  return { players: Object.values(players), voided };
}

// ---------------------------------------------------------------- data

/// Jolpica rate-limits bursts (429), so back off and retry a few times.
async function jolpica(path) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${JOLPICA}/${path}`, { cf: { cacheTtl: 300 } });
    if (res.ok) return (await res.json()).MRData;
    if (res.status !== 429 || attempt >= 3) throw new Error(`jolpica ${res.status} ${path}`);
    await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
  }
}

async function season() {
  return (await jolpica("current.json?limit=30")).RaceTable.Races;
}

async function raceData(r) {
  const [res, quali, sprint] = await Promise.all([
    jolpica(`${r.season}/${r.round}/results.json?limit=40`),
    jolpica(`${r.season}/${r.round}/qualifying.json?limit=40`),
    r.Sprint ? jolpica(`${r.season}/${r.round}/sprint.json?limit=40`) : null,
  ]);
  return {
    results: res.RaceTable.Races[0]?.Results ?? [],
    qualifying: quali.RaceTable.Races[0]?.QualifyingResults ?? [],
    sprint: sprint?.RaceTable.Races[0]?.SprintResults ?? [],
  };
}

// ------------------------------------------------------------- CloudKit

// CloudKit Web Services, server-to-server: each request is signed with
// ECDSA P-256 over "date:base64(sha256(body)):subpath", DER-encoded.
async function ckRequest(env, ckEnv, op, body) {
  const subpath = `/database/1/${CONTAINER}/${ckEnv}/public/${op}`;
  const json = JSON.stringify(body);
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const bodyHash = b64(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(json)));
  const key = await importKey(env.CK_PRIVATE_KEY);
  const raw = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${date}:${bodyHash}:${subpath}`));
  const res = await fetch(`https://api.apple-cloudkit.com${subpath}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "X-Apple-CloudKit-Request-KeyID": ckEnv === "production" ? env.CK_KEY_ID_PRODUCTION : env.CK_KEY_ID,
      "X-Apple-CloudKit-Request-ISO8601Date": date,
      "X-Apple-CloudKit-Request-SignatureV1": b64(derSignature(new Uint8Array(raw))),
    },
    body: json,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`cloudkit ${res.status} ${JSON.stringify(data).slice(0, 300)}`);
  return data;
}

/// Every prediction for a round, paging through the whole result set.
async function predictions(env, ckEnv, roundId) {
  const all = [];
  let marker;
  do {
    const data = await ckRequest(env, ckEnv, "records/query", {
      query: {
        recordType: "Prediction",
        filterBy: [{ fieldName: "round", comparator: "EQUALS", fieldValue: { value: roundId } }],
      },
      resultsLimit: 200,
      ...(marker ? { continuationMarker: marker } : {}),
    });
    for (const r of data.records ?? []) {
      if (r.serverErrorCode) continue;
      const f = (k) => r.fields?.[k]?.value ?? null;
      all.push({
        userId: f("userId"), name: f("name"),
        pole: f("pole"), p1: f("p1"), p2: f("p2"), p3: f("p3"),
        fastestLap: f("fastestLap"), wildcard: f("wildcard"), sprintWinner: f("sprintWinner"),
        modified: r.modified?.timestamp ?? r.created?.timestamp ?? 0,
        recordName: r.recordName,
      });
    }
    marker = data.continuationMarker;
  } while (marker);
  return all;
}

// ------------------------------------------------------ driver of the day

/// Voting opens 2 h after the race starts (the flag) and closes 4 days later.
export function dotdWindow(race) {
  const start = groupLock(race, "race")?.getTime() ?? 0;
  return { opens: start + 2 * 3600_000, closes: start + 96 * 3600_000 };
}

/// Counts the fan vote: one record per player (dotd-<round>-<user>), cast
/// inside the window. Cached for a minute so a busy race night stays cheap.
async function dotdTally(env, ckEnv, race) {
  const id = `${race.season}-${race.round}`;
  const key = `game:${ckEnv}:dotd:${id}`;
  const cached = await env.TOKENS.get(key, "json");
  if (cached && Date.now() - cached.at < 60_000) return cached;
  const { opens, closes } = dotdWindow(race);
  const counts = {};
  let total = 0, marker;
  do {
    const data = await ckRequest(env, ckEnv, "records/query", {
      query: { recordType: "DotdVote", filterBy: [{ fieldName: "round", comparator: "EQUALS", fieldValue: { value: id } }] },
      resultsLimit: 200, ...(marker ? { continuationMarker: marker } : {}),
    });
    for (const r of data.records ?? []) {
      if (r.serverErrorCode) continue;
      const user = r.fields?.userId?.value, driver = r.fields?.driverId?.value;
      const at = r.modified?.timestamp ?? 0;
      if (!user || !driver || r.recordName !== `dotd-${id}-${user}` || at < opens || at > closes) continue;
      counts[driver] = (counts[driver] || 0) + 1;
      total++;
    }
    marker = data.continuationMarker;
  } while (marker);
  const votes = Object.entries(counts).sort((a, b) => b[1] - a[1])
    .map(([driverId, count]) => ({ driverId, count, pct: Math.round((count / total) * 100) }));
  const result = { round: id, total, votes, at: Date.now(), closes };
  await env.TOKENS.put(key, JSON.stringify(result), { expirationTtl: 86400 * 30 });
  return result;
}

// --------------------------------------------------------------- scoring

/// Scores one finished round for one CloudKit environment, then rebuilds
/// the season table. Idempotent: rerunning replaces the round.
export async function scoreRound(env, ckEnv, race) {
  const id = `${race.season}-${race.round}`;
  const { results, qualifying, sprint } = await raceData(race);
  if (!results.length) return { id, skipped: "no results yet" };

  const wildcard = wildcardForRound(race.round);
  const { players: picks, voided } = mergePicks(await predictions(env, ckEnv, id), race);

  const players = {};
  for (const p of picks) {
    const s = score(p, wildcard, qualifying, results, sprint);
    players[p.userId] = { name: p.name || "Player", points: s.total, exact: s.exact, items: s.items, locked: p.modified };
  }

  const strategist = await env.TOKENS.get(`game:strategist:${id}`, "json");
  let strategistScore = null;
  if (strategist) {
    const s = score(strategist.picks, wildcard, qualifying, results);
    strategistScore = { points: s.total, exact: s.exact, items: s.items };
  }

  await addComments(env, race, players, results, qualifying);

  const ranked = rank(players);
  const round = {
    id, raceName: race.raceName, scoredAt: Date.now(), wildcard,
    total: ranked.length, voided, players: Object.fromEntries(ranked.map((p) => [p.userId, p])),
    strategist: strategist ? { ...strategistScore, picks: strategist.picks, reasons: strategist.reasons } : null,
  };
  await env.TOKENS.put(`game:${ckEnv}:round:${id}`, JSON.stringify(round));
  await rebuildSeason(env, ckEnv, race.season);
  return { id, players: ranked.length, voided };
}

/// Highest points first; ties broken by exact picks, then who locked in first.
function rank(players) {
  const list = Object.entries(players).map(([userId, p]) => ({ userId, ...p }));
  list.sort((a, b) => b.points - a.points || b.exact - a.exact || a.locked - b.locked);
  list.forEach((p, i) => { p.rank = i + 1; });
  return list;
}

async function rebuildSeason(env, ckEnv, year) {
  const races = await season();
  const totals = {};
  let strategist = { points: 0, exact: 0, rounds: 0 };
  for (const r of races) {
    const round = await env.TOKENS.get(`game:${ckEnv}:round:${r.season}-${r.round}`, "json");
    if (!round) continue;
    for (const [uid, p] of Object.entries(round.players)) {
      const t = totals[uid] ||= { name: p.name, points: 0, exact: 0, locked: p.locked, rounds: 0 };
      t.name = p.name;
      t.points += p.points;
      t.exact += p.exact;
      t.rounds += 1;
    }
    if (round.strategist) {
      strategist.points += round.strategist.points;
      strategist.exact += round.strategist.exact;
      strategist.rounds += 1;
    }
  }
  const ranked = rank(totals);
  await env.TOKENS.put(`game:${ckEnv}:season:${year}`, JSON.stringify({
    year, updatedAt: Date.now(), total: ranked.length,
    players: Object.fromEntries(ranked.map((p) => [p.userId, p])), strategist,
  }));
}

// ----------------------------------------------------------- AI extras

/// Plain-text chat completion (Ask the race engineer). Null on any failure.
export async function azureChat(env, messages) {
  if (!env.AZURE_OPENAI_ENDPOINT || !env.AZURE_OPENAI_KEY) return null;
  const base = new URL(env.AZURE_OPENAI_ENDPOINT.trim()).origin;
  const res = await fetch(`${base}/openai/v1/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", "api-key": env.AZURE_OPENAI_KEY },
    body: JSON.stringify({ model: env.AZURE_OPENAI_MODEL || "gpt-4.1-mini", messages, reasoning_effort: "low" }),
  });
  if (!res.ok) {
    console.log("azure chat", res.status, (await res.text()).slice(0, 300));
    return null;
  }
  const data = await res.json();
  return data.choices?.[0]?.message?.content || null;
}

export async function azure(env, messages, schema) {
  if (!env.AZURE_OPENAI_ENDPOINT || !env.AZURE_OPENAI_KEY) return null;
  // Accepts the endpoint in any form the portal shows (base, /openai/v1, a
  // full target URI with deployment and api-version): only the host counts.
  const base = new URL(env.AZURE_OPENAI_ENDPOINT.trim()).origin;
  const res = await fetch(`${base}/openai/v1/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", "api-key": env.AZURE_OPENAI_KEY },
    body: JSON.stringify({
      model: env.AZURE_OPENAI_MODEL || "gpt-4.1-mini",
      messages,
      response_format: { type: "json_schema", json_schema: { name: schema.name, strict: true, schema: schema.schema } },
    }),
  });
  if (!res.ok) {
    console.log("azure", res.status, (await res.text()).slice(0, 300));
    return null;
  }
  const data = await res.json();
  try { return JSON.parse(data.choices[0].message.content); } catch {
    console.log("azure unparsable", JSON.stringify(data).slice(0, 300));
    return null;
  }
}

const codeOf = (results, qualifying) => {
  const map = {};
  for (const r of [...results, ...qualifying]) map[r.Driver.driverId] = r.Driver.code || r.Driver.familyName;
  return (id) => (id ? map[id] || id : "none");
};

/// One or two lines of banter per player. Names are never sent.
async function addComments(env, race, players, results, qualifying) {
  const code = codeOf(results, qualifying);
  const ids = Object.keys(players);
  for (let i = 0; i < ids.length; i += 25) {
    const batch = ids.slice(i, i + 25);
    const lines = batch.map((uid, n) => {
      const items = players[uid].items.map((it) =>
        `${it.kind}: picked ${it.kind === "wildcard" ? it.picked : code(it.picked)}, actual ${it.kind === "wildcard" ? it.actual : code(it.actual)}, ${it.points} pts`).join("; ");
      return `${n}: total ${players[uid].points} pts. ${items}`;
    });
    const out = await azure(env, [
      { role: "system", content: "You are a race engineer on team radio, giving a fan short feedback on their prediction-game picks after a Formula race. Write 1–2 sentences, max 160 characters, second person (\"you\"). Playful and warm, light teasing is fine, never insulting or crude. Mention a concrete pick. Use driver codes as given. No hashtags, no emojis." },
      { role: "user", content: `Race: ${race.raceName}.\nPlayers:\n${lines.join("\n")}\nReturn one comment per player index.` },
    ], {
      name: "comments",
      schema: {
        type: "object", additionalProperties: false, required: ["comments"],
        properties: { comments: { type: "array", items: {
          type: "object", additionalProperties: false, required: ["index", "text"],
          properties: { index: { type: "integer" }, text: { type: "string" } },
        } } },
      },
    });
    for (const c of out?.comments ?? []) {
      const uid = batch[c.index];
      if (uid && typeof c.text === "string") players[uid].comment = c.text.slice(0, 200);
    }
  }
}

/// The AI Strategist's picks for the next round, made once before the lock
/// from data available at that moment.
export async function makeStrategistPicks(env, race) {
  const id = `${race.season}-${race.round}`;
  if (await env.TOKENS.get(`game:strategist:${id}`)) return { id, skipped: "already picked" };
  const [standings, recent] = await Promise.all([
    jolpica("current/driverstandings.json?limit=30"),
    jolpica(`current/results.json?limit=100&offset=${Math.max(0, (Number(race.round) - 4) * 22)}`),
  ]);
  const drivers = standings.StandingsTable.StandingsLists[0]?.DriverStandings ?? [];
  if (!drivers.length) return { id, skipped: "no standings" };
  const ids = drivers.map((d) => d.Driver.driverId);
  const table = drivers.map((d) => `${d.Driver.driverId} (${d.Driver.code}, ${d.Constructors[0]?.name}): P${d.position}, ${d.points} pts, ${d.wins} wins`).join("\n");
  const form = (recent.RaceTable.Races ?? []).slice(-3).map((r) => {
    const top = (r.Results ?? []).slice(0, 3).map((x) => x.Driver.code).join(", ");
    const fl = (r.Results ?? []).find((x) => x.FastestLap?.rank === "1")?.Driver.code ?? "?";
    return `R${r.round} ${r.raceName}: podium ${top}; fastest lap ${fl}`;
  }).join("\n");
  const wildcard = wildcardForRound(race.round);
  const wc = WILDCARD_TEXT[wildcard];

  const out = await azure(env, [
    { role: "system", content: "You are the AI Strategist, a sharp Formula race analyst competing in a prediction game against fans. Make the most likely picks from the data. Keep each reason under 80 characters, factual, based only on the data given." },
    { role: "user", content: `Next race: ${race.raceName} (round ${race.round}, ${race.Circuit.circuitName}).\nChampionship:\n${table}\nRecent form:\n${form}\nWildcard: ${wc.question} Answers: ${Object.keys(wc.answers).join(", ")}.\nPick pole, P1, P2, P3 (three different drivers), fastest lap, and the wildcard answer. Use the driver ids exactly as listed.` },
  ], {
    name: "picks",
    schema: {
      type: "object", additionalProperties: false,
      required: ["pole", "p1", "p2", "p3", "fastestLap", "wildcard", "reasons"],
      properties: {
        pole: { type: "string", enum: ids }, p1: { type: "string", enum: ids },
        p2: { type: "string", enum: ids }, p3: { type: "string", enum: ids },
        fastestLap: { type: "string", enum: ids },
        wildcard: { type: "string", enum: Object.keys(wc.answers) },
        reasons: {
          type: "object", additionalProperties: false,
          required: ["pole", "podium", "fastestLap", "wildcard"],
          properties: { pole: { type: "string" }, podium: { type: "string" }, fastestLap: { type: "string" }, wildcard: { type: "string" } },
        },
      },
    },
  });
  if (!out) return { id, skipped: "no answer from Azure" };
  if (new Set([out.p1, out.p2, out.p3]).size !== 3) return { id, skipped: "podium not three different drivers", out };
  const { reasons, ...picks } = out;
  await env.TOKENS.put(`game:strategist:${id}`, JSON.stringify({ picks, reasons, madeAt: Date.now() }));
  return { id, picks };
}

// ------------------------------------------------------------ cron + http

/// Called from the 5-minute cron: strategist picks in race week, scoring
/// once results are out.
export async function runGame(env) {
  if (!env.CK_KEY_ID || !env.CK_PRIVATE_KEY) return;
  const races = await season();
  const now = Date.now();
  const report = [];

  const next = races.find((r) => (lockDate(r)?.getTime() ?? 0) > now);
  if (next) {
    const lock = lockDate(next).getTime();
    // One failing step must not block the others.
    if (lock - now < 4 * 86400_000) {
      report.push(await makeStrategistPicks(env, next).catch((e) => ({ strategist: String(e) })));
    }
  }

  // The most recent race that has started at least 3 hours ago.
  const past = races.filter((r) => new Date(`${r.date}T${r.time || "00:00:00Z"}`).getTime() < now - 3 * 3600_000);
  const last = past[past.length - 1];
  if (last) {
    const id = `${last.season}-${last.round}`;
    for (const ckEnv of (env.CK_ENVS || "production").split(",").map((s) => s.trim())) {
      const flag = `game:${ckEnv}:scored:${id}`;
      if (await env.TOKENS.get(flag)) continue;
      try {
        const r = await scoreRound(env, ckEnv, last);
        report.push({ ckEnv, ...r });
        // Scored once per environment; POST /game/run after deleting the
        // flag rescores (e.g. after a results correction).
        if (!r.skipped) await env.TOKENS.put(flag, "1", { expirationTtl: 86400 * 30 });
      } catch (e) {
        report.push({ ckEnv, id, error: String(e) });
      }
    }
  }
  return report;
}

/// Read-only routes the app uses. Returns null when the path isn't ours.
export async function handleGame(request, env) {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/game/")) return null;
  const q = url.searchParams;
  const ckEnv = q.get("env") === "development" ? "development" : "production";

  // Manual run, guarded like /test.
  if (request.method === "POST" && url.pathname === "/game/run") {
    if (request.headers.get("x-test-key") !== env.TEST_KEY) return new Response("no", { status: 403 });
    return json(await runGame(env));
  }

  if (url.pathname === "/game/board") {
    // ?scope=season&year=2026 or ?scope=round&round=2026-17, plus &user=<id>
    const scope = q.get("scope") === "round" ? "round" : "season";
    const key = scope === "round"
      ? `game:${ckEnv}:round:${q.get("round")}`
      : `game:${ckEnv}:season:${q.get("year") || new Date().getUTCFullYear()}`;
    const data = await env.TOKENS.get(key, "json");
    if (!data) return json({ total: 0, top: [], me: null, strategist: null });
    const list = Object.entries(data.players).map(([userId, p]) => ({ userId, ...p }));
    const slim = (p) => p && ({ userId: p.userId, name: p.name, points: p.points, exact: p.exact, rank: p.rank });
    const me = q.get("user") ? list.find((p) => p.userId === q.get("user")) : null;
    return json({
      scope, total: data.total,
      top: list.slice(0, Math.min(Number(q.get("limit")) || 100, 200)).map(slim),
      me: me ? { ...slim(me), comment: me.comment ?? null, items: me.items ?? null } : null,
      strategist: data.strategist ? { name: STRATEGIST_NAME, points: data.strategist.points, exact: data.strategist.exact } : null,
    }, 60);
  }

  if (url.pathname === "/game/scores" && request.method === "POST") {
    // League tables: the app sends its members' ids.
    let body;
    try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
    const year = body.year || new Date().getUTCFullYear();
    const data = await env.TOKENS.get(`game:${ckEnv}:season:${year}`, "json");
    const ids = (body.ids || []).slice(0, 200);
    return json({ players: ids.map((id) => data?.players?.[id] && { userId: id, name: data.players[id].name, points: data.players[id].points, exact: data.players[id].exact }).filter(Boolean) });
  }

  // Private leagues: a 6-character code, a name and a member list; the
  // standings come from the season table, so leagues cost nothing to score.
  if (url.pathname.startsWith("/game/league")) {
    let body = {};
    if (request.method === "POST") {
      try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
    }
    const user = String(body.user || q.get("user") || "").slice(0, 120);
    const name = String(body.name || "").trim().slice(0, 24);
    const leagueKey = (code) => `game:${ckEnv}:league:${code}`;

    if (url.pathname === "/game/league/create" && request.method === "POST") {
      const title = String(body.title || "").trim().slice(0, 30);
      if (!user || !name || !title) return json({ error: "bad request" });
      let code;
      for (let i = 0; i < 8 && !code; i++) {
        const c = Array.from(crypto.getRandomValues(new Uint8Array(6)), (b) => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[b % 32]).join("");
        if (!(await env.TOKENS.get(leagueKey(c)))) code = c;
      }
      const league = { code, title, owner: user, members: { [user]: name }, createdAt: Date.now() };
      await env.TOKENS.put(leagueKey(code), JSON.stringify(league));
      return json({ code, title });
    }

    if ((url.pathname === "/game/league/join" || url.pathname === "/game/league/leave") && request.method === "POST") {
      const code = String(body.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
      const league = await env.TOKENS.get(leagueKey(code), "json");
      if (!league) return json({ error: "no league with that code" });
      if (!user) return json({ error: "bad request" });
      if (url.pathname.endsWith("/join")) {
        if (Object.keys(league.members).length >= 200 && !league.members[user]) return json({ error: "league is full" });
        if (!name) return json({ error: "bad request" });
        league.members[user] = name;
      } else {
        delete league.members[user];
      }
      await env.TOKENS.put(leagueKey(code), JSON.stringify(league));
      return json({ code, title: league.title });
    }

    if (url.pathname === "/game/league") {
      const code = String(q.get("code") || "").toUpperCase();
      const league = await env.TOKENS.get(leagueKey(code), "json");
      if (!league) return json({ error: "no league with that code" });
      const year = q.get("year") || new Date().getUTCFullYear();
      const seasonTable = await env.TOKENS.get(`game:${ckEnv}:season:${year}`, "json");
      const rows = Object.entries(league.members).map(([userId, memberName]) => {
        const p = seasonTable?.players?.[userId];
        return { userId, name: p?.name || memberName, points: p?.points || 0, exact: p?.exact || 0 };
      }).sort((a, b) => b.points - a.points || b.exact - a.exact || a.name.localeCompare(b.name));
      rows.forEach((r, i) => { r.rank = i + 1; });
      return json({ code, title: league.title, members: rows });
    }
    return new Response("not found", { status: 404 });
  }

  // Lights Out reaction leaderboard, per week (Monday-based, UTC).
  if (url.pathname === "/game/reaction") {
    const week = reactionWeek();
    const key = `game:${ckEnv}:reaction:${week}`;
    const board = (await env.TOKENS.get(key, "json")) || {};
    if (request.method === "POST") {
      let body;
      try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
      const user = String(body.user || "").slice(0, 120);
      const name = String(body.name || "").trim().slice(0, 24);
      const ms = Math.round(Number(body.ms));
      // Human limit: anything under 100 ms is a guess, not a reaction.
      if (!user || !name || !(ms >= 100 && ms <= 2000)) return json({ error: "rejected" });
      const day = new Date().toISOString().slice(0, 10);
      const rateKey = `rx:${day}:${user}`;
      const tries = Number((await env.TOKENS.get(rateKey)) || 0);
      if (tries >= 200) return json({ error: "limit" });
      await env.TOKENS.put(rateKey, String(tries + 1), { expirationTtl: 90000 });
      if (!board[user] || ms < board[user].ms) {
        board[user] = { name, ms, at: Date.now() };
        await env.TOKENS.put(key, JSON.stringify(board), { expirationTtl: 86400 * 21 });
      }
    }
    const list = Object.entries(board).map(([userId, v]) => ({ userId, ...v })).sort((a, b) => a.ms - b.ms);
    list.forEach((e, i) => { e.rank = i + 1; });
    const me = q.get("user") ? list.find((e) => e.userId === q.get("user")) : null;
    return json({ week, total: list.length, top: list.slice(0, 20).map(({ userId, name, ms, rank }) => ({ userId, name, ms, rank })),
                  me: me ? { name: me.name, ms: me.ms, rank: me.rank } : null });
  }

  if (url.pathname === "/game/dotd") {
    const round = q.get("round") || "";
    const race = (await season()).find((r) => `${r.season}-${r.round}` === round);
    if (!race) return json({ error: "unknown round" }, 0);
    if (!env.CK_KEY_ID) return json({ round, total: 0, votes: [] });
    try {
      return json(await dotdTally(env, ckEnv, race), 30);
    } catch (e) {
      console.log("dotd", String(e));
      return json({ round, total: 0, votes: [], error: "unavailable" });
    }
  }

  if (url.pathname === "/game/strategist") {
    // Picks are only revealed once the round is locked.
    const round = q.get("round") || "";
    const races = await season();
    const race = races.find((r) => `${r.season}-${r.round}` === round);
    const lock = race && lockDate(race);
    if (!lock || Date.now() < lock.getTime()) return json({ revealed: false, name: STRATEGIST_NAME });
    const s = await env.TOKENS.get(`game:strategist:${round}`, "json");
    return json(s ? { revealed: true, name: STRATEGIST_NAME, picks: s.picks, reasons: s.reasons } : { revealed: false, name: STRATEGIST_NAME }, 300);
  }

  return new Response("not found", { status: 404 });
}

// --------------------------------------------------------------- helpers

/// "2026-10-12": the Monday that starts the current UTC week.
function reactionWeek() {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return d.toISOString().slice(0, 10);
}

function json(data, maxAge = 0) {
  return new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json", "cache-control": maxAge ? `public, max-age=${maxAge}` : "no-store" },
  });
}

function b64(buf) {
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}

async function importKey(pem) {
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "")), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

/// WebCrypto returns r||s; CloudKit expects an ASN.1 DER signature.
export function derSignature(raw) {
  const int = (bytes) => {
    let i = 0;
    while (i < bytes.length - 1 && bytes[i] === 0) i++;
    let b = bytes.slice(i);
    if (b[0] & 0x80) b = Uint8Array.of(0, ...b);
    return Uint8Array.of(0x02, b.length, ...b);
  };
  const r = int(raw.slice(0, 32)), s = int(raw.slice(32));
  return Uint8Array.of(0x30, r.length + s.length, ...r, ...s);
}
