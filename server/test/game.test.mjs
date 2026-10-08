// Run: node server/test/game.test.mjs  (needs network: reads real Jolpica results)
import { score, wildcardForRound, resolveWildcard, derSignature, scoreRound, lockDate } from "../src/game.js";
import crypto from "node:crypto";
const ok = (c, m) => { console.log((c ? "PASS " : "FAIL ") + m); if (!c) process.exitCode = 1; };
const j = async (u) => (await (await fetch(u)).json()).MRData;
const race = (await j("https://api.jolpi.ca/ergast/f1/2026/16/results.json?limit=40")).RaceTable.Races[0];
const quali = (await j("https://api.jolpi.ca/ergast/f1/2026/16/qualifying.json?limit=40")).RaceTable.Races[0].QualifyingResults;
const R = race.Results;
// 1. parity with the Swift harness (perfect 47, swapped 20, empty 0)
const perfect = { pole: quali[0].Driver.driverId, p1: R[0].Driver.driverId, p2: R[1].Driver.driverId, p3: R[2].Driver.driverId,
  fastestLap: R.find(r => r.FastestLap?.rank === "1").Driver.driverId, wildcard: resolveWildcard("retirements", quali, R) };
ok(score(perfect, "retirements", quali, R).total === 47, "perfect picks = 47");
ok(score({ ...perfect, p1: perfect.p2, p2: perfect.p1, pole: "nobody" }, "retirements", quali, R).total === 20, "swapped P1/P2 = 20");
ok(score({}, "retirements", quali, R).total === 0, "empty = 0");
ok(["yes","2-3","no"].join() === ["poleSitterWins","retirements","winningMargin"].map(w => resolveWildcard(w, quali, R)).join(), "wildcards match Swift (yes, 2-3, no)");
ok(wildcardForRound("16") === "poleSitterWins" && wildcardForRound("17") === "retirements", "wildcard rotation matches Swift");
// 2. DER signature verifies with OpenSSL
const pem = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ type: "pkcs8", format: "pem" });
const key = await crypto.webcrypto.subtle.importKey("pkcs8", crypto.createPrivateKey(pem).export({ type: "pkcs8", format: "der" }), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
const msg = new TextEncoder().encode("2026-10-09T10:00:00Z:abc=:/database/1/x");
for (let i = 0; i < 20; i++) {
  const raw = new Uint8Array(await crypto.webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, msg));
  if (!crypto.verify("sha256", msg, crypto.createPublicKey(pem), Buffer.from(derSignature(raw)))) { ok(false, "DER signature"); break; }
  if (i === 19) ok(true, "DER signature verifies (20 runs)");
}
// 3. end-to-end scoreRound with mocked CloudKit and in-memory KV
const cal = (await j("https://api.jolpi.ca/ergast/f1/2026.json?limit=30")).RaceTable.Races.find(r => r.round === "16");
const lock = lockDate(cal).getTime();
const fakeRecords = [
  { recordName: "pred-2026-16-userA", fields: { userId: {value:"userA"}, name:{value:"Alice"}, pole:{value:perfect.pole}, p1:{value:perfect.p1}, p2:{value:perfect.p2}, p3:{value:perfect.p3}, fastestLap:{value:perfect.fastestLap}, wildcard:{value:"yes"} }, modified: { timestamp: lock - 3600_000 } },
  { recordName: "pred-2026-16-userB", fields: { userId: {value:"userB"}, name:{value:"Bob"}, p1:{value:perfect.p2} }, modified: { timestamp: lock - 60_000 } },
  { recordName: "pred-2026-16-userC", fields: { userId: {value:"userC"}, name:{value:"Late"}, p1:{value:perfect.p1} }, modified: { timestamp: lock + 60_000 } },
  { recordName: "pred-2026-16-userA", fields: { userId: {value:"userD"}, name:{value:"Spoof"}, p1:{value:perfect.p1} }, modified: { timestamp: lock - 60_000 } },
];
let signed;
const realFetch = globalThis.fetch;
globalThis.fetch = async (u, init) => {
  if (String(u).startsWith("https://api.apple-cloudkit.com")) { signed = init.headers; return new Response(JSON.stringify({ records: fakeRecords })); }
  return realFetch(u, init);
};
const kv = new Map();
const env = { CK_KEY_ID: "test", CK_PRIVATE_KEY: pem, TOKENS: {
  get: async (k, t) => kv.has(k) ? (t === "json" ? JSON.parse(kv.get(k)) : kv.get(k)) : null,
  put: async (k, v) => kv.set(k, v) } };
const res = await scoreRound(env, "development", cal);
const round = JSON.parse(kv.get("game:development:round:2026-16"));
ok(res.players === 2 && res.voided === 1, `2 players scored, 1 late pick voided (${JSON.stringify(res)})`);
ok(!round.players.userD, "spoofed record name ignored");
ok(round.players.userA.points === 47 && round.players.userA.rank === 1 && round.players.userB.rank === 2, "ranking: Alice 47 first, Bob second");
ok(JSON.parse(kv.get("game:development:season:2026")).players.userA.points === 47, "season table built");
ok(signed["X-Apple-CloudKit-Request-SignatureV1"]?.length > 80 && /Z$/.test(signed["X-Apple-CloudKit-Request-ISO8601Date"]), "CloudKit request carries signature + date headers");
