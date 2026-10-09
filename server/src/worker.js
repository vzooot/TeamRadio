// Team Radio push worker: starts the session Live Activity on every
// registered iPhone ~15 minutes before each F1 session, via APNs
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
      if (!/^[0-9a-f]{32,200}$/.test(token)) return new Response("bad token", { status: 400 });
      await env.TOKENS.put("t:" + token, apnsEnv);
      return new Response("ok");
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
      await pushSessionStart(env, race, next);
      return new Response("pushed " + next.short);
    }
    return new Response("not found", { status: 404 });
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(checkAndPush(env));
    ctx.waitUntil(runGame(env).then((r) => r?.length && console.log("game", JSON.stringify(r)))
      .catch((e) => console.log("game", e)));
  },
};

async function checkAndPush(env) {
  const race = await nextRace();
  if (!race) return;

  const now = Date.now();
  for (const s of race.sessions) {
    const lead = s.date.getTime() - now;
    // Fire once inside the 10–20 minute window (cron period is 5 min).
    if (lead < 10 * 60_000 || lead > 20 * 60_000) continue;
    const dedupeKey = "sent:" + s.short + ":" + s.date.toISOString();
    if (await env.TOKENS.get(dedupeKey)) continue;
    await env.TOKENS.put(dedupeKey, "1", { expirationTtl: 86400 });
    await pushSessionStart(env, race, s);
  }
}

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

async function pushSessionStart(env, race, session) {
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
        body: `${race.raceName}: ${session.short} starts in 15 minutes.`,
      },
    },
  });

  const list = await env.TOKENS.list({ prefix: "t:" });
  for (const key of list.keys) {
    const token = key.name.slice(2);
    const apnsEnv = (await env.TOKENS.get(key.name)) || "production";
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
