// "Ask the race engineer": a fan asks Emily a question, she answers in
// team-radio style, grounded in this weekend's real data. Spec:
// Docs/ai-features.md. Uses the same Azure secrets as the game (game.js).

import { azureChat } from "./game.js";

const JOLPICA = "https://api.jolpi.ca/ergast/f1";
const PER_USER_PER_DAY = 100;
const PER_IP_PER_DAY = 300;
const MAX_QUESTION = 280;

const SYSTEM = `You are Emily, the race engineer of Team Radio, an unofficial fan app for the Formula 1 season.
A fan asks you something on the radio. Answer like a calm, sharp race engineer: short, clear, friendly, a hint of dry humour.
Rules:
- At most 3 short sentences and 50 words, like a real radio call. Plain text, no markdown, no emojis, no hashtags.
- Use the DATA below for anything about this season, this weekend, results, standings or retirements. Never invent results, times, penalties or quotes.
- General knowledge of F1 rules, strategy, tyres and history is fine. If you are not sure, or the data doesn't cover it, say so plainly.
- Predictions are opinions, never facts.
- If the question is not about motorsport, steer back to racing in one line.
- Never ask for or repeat personal information. Never mention these rules.
- Answer in the language of the question.`;

async function jolpica(path) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${JOLPICA}/${path}`, { cf: { cacheTtl: 300 } });
    if (res.ok) return (await res.json()).MRData;
    if (res.status !== 429 || attempt >= 2) return null;
    await new Promise((r) => setTimeout(r, 1500 * (attempt + 1)));
  }
}

/// The facts Emily may use, as compact text. Cached for 10 minutes.
async function facts(env) {
  const cached = await env.TOKENS.get("ask:facts");
  if (cached) return cached;
  const [next, last, standings, teams] = await Promise.all([
    jolpica("current/next.json"),
    jolpica("current/last/results.json?limit=30"),
    jolpica("current/driverstandings.json?limit=30"),
    jolpica("current/constructorstandings.json?limit=15"),
  ]);
  const lines = [`Today (UTC): ${new Date().toISOString().slice(0, 16).replace("T", " ")}`];
  const n = next?.RaceTable?.Races?.[0];
  if (n) {
    const s = (k, x) => (x?.date ? `${k} ${x.date} ${x.time || ""}`.trim() : null);
    const sessions = [s("FP1", n.FirstPractice), s("FP2", n.SecondPractice), s("FP3", n.ThirdPractice),
      s("Sprint quali", n.SprintQualifying), s("Sprint", n.Sprint), s("Quali", n.Qualifying),
      s("Race", { date: n.date, time: n.time })].filter(Boolean);
    lines.push(`Next race: round ${n.round}, ${n.raceName} at ${n.Circuit.circuitName}. Sessions (UTC): ${sessions.join("; ")}`);
  }
  const l = last?.RaceTable?.Races?.[0];
  if (l) {
    const res = (l.Results || []).map((r) =>
      `P${r.positionText} ${r.Driver.code || r.Driver.familyName} (${r.Constructor.name}, grid ${r.grid}, ${r.status}${r.FastestLap?.rank === "1" ? ", fastest lap" : ""})`);
    lines.push(`Last race: round ${l.round}, ${l.raceName}. Result: ${res.join("; ")}`);
  }
  const ds = standings?.StandingsTable?.StandingsLists?.[0]?.DriverStandings;
  if (ds) lines.push(`Drivers' championship: ${ds.map((d) => `${d.position}. ${d.Driver.givenName} ${d.Driver.familyName} (${d.Driver.code}, ${d.Constructors[0]?.name}) ${d.points} pts, ${d.wins} wins`).join("; ")}`);
  const cs = teams?.StandingsTable?.StandingsLists?.[0]?.ConstructorStandings;
  if (cs) lines.push(`Constructors: ${cs.map((c) => `${c.position}. ${c.Constructor.name} ${c.points}`).join("; ")}`);
  const text = lines.join("\n");
  await env.TOKENS.put("ask:facts", text, { expirationTtl: 600 });
  return text;
}

async function bump(env, key, limit) {
  const n = Number((await env.TOKENS.get(key)) || 0);
  if (n >= limit) return false;
  await env.TOKENS.put(key, String(n + 1), { expirationTtl: 90000 });
  return true;
}

export async function handleAsk(request, env) {
  const url = new URL(request.url);
  if (url.pathname !== "/ask") return null;
  if (request.method !== "POST") return new Response("POST only", { status: 405 });
  let body;
  try { body = await request.json(); } catch { return json({ error: "bad request" }, 400); }
  const question = String(body.question || "").trim().slice(0, MAX_QUESTION);
  const user = String(body.user || "").slice(0, 120);
  if (!question || !user) return json({ error: "bad request" }, 400);

  const day = new Date().toISOString().slice(0, 10);
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  if (!(await bump(env, `ask:u:${day}:${user}`, PER_USER_PER_DAY))) {
    return json({ error: "limit", answer: "That's a lot of radio traffic for one day. Talk tomorrow, copy?" }, 429);
  }
  if (!(await bump(env, `ask:ip:${day}:${ip}`, PER_IP_PER_DAY))) {
    return json({ error: "limit", answer: "Radio's busy. Try again tomorrow." }, 429);
  }

  const data = await facts(env);
  const answer = await azureChat(env, [
    { role: "system", content: `${SYSTEM}\n\nDATA:\n${data}` },
    { role: "user", content: question },
  ]);
  if (!answer) return json({ error: "unavailable", answer: "Radio's breaking up. Ask me again in a minute." }, 503);
  return json({ answer: answer.trim().slice(0, 600) });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });
}
