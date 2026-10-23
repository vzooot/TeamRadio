// Team Radio push worker: starts the session Live Activity on every
// registered iPhone ~1 hour before each F1 session, via APNs
// push-to-start. Cron fires every 5 minutes; a KV flag deduplicates.
//
// Secrets (wrangler secret put): APNS_KEY (the .p8 PEM), APNS_KEY_ID,
// APNS_TEAM_ID. KV binding: TOKENS. The prediction game lives in game.js.

import { handleGame, runGame } from "./game.js";
import { handleAsk } from "./ask.js";
import { handleGuide } from "./guide.js";

const TOPIC = "com.woqomoqo.OneF.push-type.liveactivity";
const HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

const FLAGS = {
  Australia: "🇦🇺", China: "🇨🇳", Japan: "🇯🇵", Bahrain: "🇧🇭",
  "Saudi Arabia": "🇸🇦", USA: "🇺🇸", "United States": "🇺🇸", Italy: "🇮🇹",
  Monaco: "🇲🇨", Canada: "🇨🇦", Spain: "🇪🇸", Austria: "🇦🇹",
  UK: "🇬🇧", "United Kingdom": "🇬🇧", Hungary: "🇭🇺", Belgium: "🇧🇪",
  Netherlands: "🇳🇱", Azerbaijan: "🇦🇿", Singapore: "🇸🇬", Mexico: "🇲🇽",
  Brazil: "🇧🇷", Qatar: "🇶🇦", UAE: "🇦🇪", Malaysia: "🇲🇾",
};

export default {
  // Devices register their push-to-start tokens here.
  async fetch(request, env) {
    const game = (await handleGame(request, env)) || (await handleAsk(request, env)) || (await handleGuide(request, env));
    if (game) return game;
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/register") {
      let body;
      try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
      const token = (body.token || "").toLowerCase();
      const apnsEnv = body.env === "sandbox" ? "sandbox" : "production";
      // Minutes before each session the countdown starts: 0 (off), 15, 60 or 180.
      const lead = [0, 15, 60, 180].includes(Number(body.lead)) ? Number(body.lead) : 60;
      if (!/^[0-9a-f]{32,200}$/.test(token)) return new Response("bad token", { status: 400 });
      await env.TOKENS.put("t:" + token, `${apnsEnv}|${lead}`);
      return new Response("ok");
    }
    // Devices register their regular APNs token here, for announcements.
    if (request.method === "POST" && url.pathname === "/register-device") {
      let body;
      try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
      const token = (body.token || "").toLowerCase();
      if (!/^[0-9a-f]{32,200}$/.test(token)) return new Response("bad token", { status: 400 });
      await env.TOKENS.put("d:" + token, body.env === "sandbox" ? "sandbox" : "production");
      return new Response("ok");
    }
    // Announcement to every device: {title, body, link?, env?}. Guarded by
    // the ADMIN_KEY secret; scripts/push/announce.sh sends one.
    if (request.method === "POST" && url.pathname === "/announce") {
      if (!env.ADMIN_KEY || request.headers.get("x-admin-key") !== env.ADMIN_KEY) {
        return new Response("no", { status: 403 });
      }
      let body;
      try { body = await request.json(); } catch { return new Response("bad json", { status: 400 }); }
      if (!body.title || !body.body) return new Response("title and body required", { status: 400 });
      return Response.json(await announce(env, body));
    }
    if (url.pathname === "/health") return new Response("ok");
    // Manual test fire: pushes a fake "session in 15 min" to all tokens.
    // Guarded by the TEST_KEY secret.
    if (request.method === "POST" && url.pathname === "/test") {
      if (request.headers.get("x-test-key") !== env.TEST_KEY) {
        return new Response("no", { status: 403 });
      }
      const race = await nextRace();
      if (!race) return new Response("no race data", { status: 502 });
      const next = race.sessions.find((s) => s.date.getTime() > Date.now())
        || { name: "Test Session", short: "TEST", date: new Date(Date.now() + 15 * 60_000), duration: 3600 };
      await pushSessionStart(env, race, next, 60);
      return new Response("pushed " + next.short);
    }
    return new Response("not found", { status: 404 });
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(checkAndPush(env));
    ctx.waitUntil(runGame(env, { onScored: (race) => announceOnce(env, `results:${race.season}-${race.round}`, {
      title: `🏁 Results are in for the ${race.raceName}`,
      body: "See your points and whether you beat the AI Strategist.",
      link: "teamradio://games",
    }) }).then((r) => r?.length && console.log("game", JSON.stringify(r)))
      .catch((e) => console.log("game", e)));
    ctx.waitUntil(autoAnnouncements(env).catch((e) => console.log("auto", String(e))));
  },
};

async function checkAndPush(env) {
  const race = await nextRace();
  if (!race) return;

  // Rolling countdown: each session's Lock Screen countdown starts 8 hours
  // ahead (Apple's limit for a Live Activity), or when the previous session
  // ends if that's later, so the next session is always there all weekend.
  const now = Date.now();
  const sessions = [...race.sessions].sort((a, b) => a.date - b.date);
  let previousEnd = 0;
  for (const s of sessions) {
    const start = s.date.getTime();
    const startAt = Math.max(start - ROLLING_LEAD_MS, previousEnd);
    previousEnd = start + s.duration * 1000;
    if (now < startAt || now >= start) continue;
    const dedupeKey = `sent:roll:${s.short}:${s.date.toISOString()}`;
    if (await env.TOKENS.get(dedupeKey)) continue;
    await env.TOKENS.put(dedupeKey, "1", { expirationTtl: 86400 * 2 });
    await pushSessionStart(env, race, s, start - now);
  }
}

const ROLLING_LEAD_MS = 8 * 3600_000;

async function nextRace() {
  const res = await fetch("https://api.jolpi.ca/ergast/f1/current/next.json", {
    cf: { cacheTtl: 240 },
  });
  if (!res.ok) return null;
  const data = await res.json();
  const r = data?.MRData?.RaceTable?.Races?.[0];
  if (!r) return null;

  const parse = (s) => (s?.date ? new Date(`${s.date}T${s.time || "00:00:00Z"}`) : null);
  const defs = [
    ["Practice 1", "FP1", r.FirstPractice, 3600],
    ["Practice 2", "FP2", r.SecondPractice, 3600],
    ["Practice 3", "FP3", r.ThirdPractice, 3600],
    ["Sprint Quali", "SQ", r.SprintQualifying, 3600],
    ["Sprint", "SPRINT", r.Sprint, 3600],
    ["Qualifying", "QUALI", r.Qualifying, 3600],
    ["Race", "RACE", { date: r.date, time: r.time }, 7200],
  ];
  const sessions = [];
  for (const [name, short, src, duration] of defs) {
    const date = parse(src);
    if (date) sessions.push({ name, short, date, duration });
  }
  return {
    raceName: r.raceName,
    country: r.Circuit?.Location?.country || "",
    sessions,
  };
}

/// "env|lead" since 1.2.0; older devices stored just the env (1 hour lead).
/// Lead 0 means the player turned automatic countdowns off; any other
/// value now gets the rolling countdown.
function parseToken(value) {
  const [apnsEnv, lead] = (value || "production").split("|");
  return { apnsEnv: apnsEnv === "sandbox" ? "sandbox" : "production", lead: lead === undefined ? 60 : Number(lead) };
}

/// "8 hours", "1 hour", "40 minutes": the time left, rounded for an alert.
const leftText = (ms) => {
  const minutes = Math.round(ms / 60_000);
  if (minutes < 60) return `${minutes} minutes`;
  const hours = Math.round(minutes / 60);
  return hours === 1 ? "1 hour" : `${hours} hours`;
};

async function pushSessionStart(env, race, session, leftMs) {
  const jwt = await apnsJWT(env);
  const start = session.date.getTime() / 1000;
  const end = start + session.duration;
  // ActivityKit decodes ContentState with Swift's default JSON date coding:
  // seconds since 2001-01-01 (reference date = unix − 978307200).
  const ref = (unix) => unix - 978307200;

  const payload = JSON.stringify({
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "start",
      "content-state": {
        sessionDate: ref(start),
        sessionEndDate: ref(end),
        isLive: false,
      },
      "attributes-type": "RaceActivityAttributes",
      attributes: {
        raceName: race.raceName,
        flag: FLAGS[race.country] || "🏁",
        sessionName: session.name,
        sessionShort: session.short,
      },
      alert: {
        title: `${FLAGS[race.country] || "🏁"} ${session.name} soon`,
        body: `${race.raceName}: ${session.short} starts in ${leftText(leftMs)}.`,
      },
    },
  });

  const list = await env.TOKENS.list({ prefix: "t:" });
  for (const key of list.keys) {
    const token = key.name.slice(2);
    const { apnsEnv, lead } = parseToken(await env.TOKENS.get(key.name));
    if (lead === 0) continue;   // turned off in the app
    const res = await fetch(`${HOSTS[apnsEnv]}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": TOPIC,
        "apns-push-type": "liveactivity",
        "apns-priority": "10",
        "apns-expiration": String(Math.floor(start)),
      },
      body: payload,
    });
    if (res.status === 400 || res.status === 410) {
      const reason = await res.text();
      // Dead or foreign token — drop it so the list stays clean.
      if (reason.includes("BadDeviceToken") || reason.includes("Unregistered")) {
        await env.TOKENS.delete(key.name);
      }
      console.log("apns reject", res.status, reason);
    }
  }
}

/// A normal notification to every registered device (or only `onlyEnv`:
/// "sandbox" to test on development builds first). `link` opens a tab,
/// e.g. "teamradio://games". Dead tokens are dropped.
async function announce(env, { title, body, link, onlyEnv }) {
  const jwt = await apnsJWT(env);
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: "default" },
    ...(link ? { link } : {}),
  });
  const counts = { sent: 0, failed: 0, removed: 0 };
  let cursor;
  do {
    const page = await env.TOKENS.list({ prefix: "d:", cursor });
    for (const key of page.keys) {
      const apnsEnv = (await env.TOKENS.get(key.name)) === "sandbox" ? "sandbox" : "production";
      if (onlyEnv && apnsEnv !== onlyEnv) continue;
      const res = await fetch(`${HOSTS[apnsEnv]}/3/device/${key.name.slice(2)}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": APP_TOPIC,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: payload,
      });
      if (res.ok) { counts.sent++; continue; }
      counts.failed++;
      const reason = await res.text();
      if (reason.includes("BadDeviceToken") || reason.includes("Unregistered")) {
        await env.TOKENS.delete(key.name);
        counts.removed++;
      }
      console.log("announce reject", res.status, reason);
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return counts;
}

const APP_TOPIC = "com.woqomoqo.OneF";

/// Sends an announcement once per `id`, however often it's called.
async function announceOnce(env, id, message) {
  const key = `ann:${id}`;
  if (await env.TOKENS.get(key)) return;
  await env.TOKENS.put(key, "1", { expirationTtl: 86400 * 14 });
  const counts = await announce(env, message);
  console.log("announced", id, JSON.stringify(counts));
}

/// Scheduled messages each race weekend (the results one comes from the
/// game scorer): picks open two days before qualifying.
async function autoAnnouncements(env) {
  const race = await nextRace();
  if (!race) return;
  const quali = race.sessions.find((s) => s.short === "QUALI");
  if (!quali) return;
  const openAt = quali.date.getTime() - 2 * 86400_000;
  const now = Date.now();
  // within an hour of the moment (cron runs every 5 minutes)
  if (now < openAt || now > openAt + 3600_000) return;
  const flag = FLAGS[race.country] || "🏁";
  await announceOnce(env, `open:${quali.date.toISOString()}`, {
    title: `${flag} Picks are open for the ${race.raceName}`,
    body: "Call pole, the podium and fastest lap. Can you beat the AI Strategist?",
    link: "teamradio://games",
  });
}

// ES256 JWT for APNs, signed with the .p8 key via WebCrypto.
async function apnsJWT(env) {
  const b64url = (buf) =>
    btoa(String.fromCharCode(...new Uint8Array(buf)))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const pem = env.APNS_KEY.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]
  );

  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const claims = b64url(enc.encode(JSON.stringify({
    iss: env.APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  })));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${header}.${claims}`)
  );
  return `${header}.${claims}.${b64url(signature)}`;
}
