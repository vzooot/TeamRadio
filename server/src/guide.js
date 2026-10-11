// Circuit guide: one short text per corner, kept in KV ("guide:<circuitId>")
// and uploaded with scripts/guide/upload.sh, so a wrong line is fixed without
// an app update. Spec: Docs/ai-features.md.


const JOLPICA = "https://api.jolpi.ca/ergast/f1";

const SYSTEM = `You write the corner guide for a Formula 1 fan app.
For every corner number of the given circuit, write:
- name: the corner's widely used name (e.g. "Senna S", "Eau Rouge"), or "" if it has no well-known name. Never invent a name.
- text: one sentence, max 120 characters, on what the corner is like for a driver (direction, speed, braking, kerbs, what makes it hard or where overtakes happen). Plain and factual.
- moment: one famous, real moment at this corner in under 110 characters, or "" if you are not certain. Never invent incidents, drivers or years.
Use the official corner numbering of the current layout. If you are unsure about a corner, keep text generic and leave name and moment empty.`;

const SCHEMA = (n) => ({
  name: "guide",
  schema: {
    type: "object", additionalProperties: false, required: ["corners"],
    properties: {
      corners: {
        type: "array", minItems: n, maxItems: n,
        items: {
          type: "object", additionalProperties: false, required: ["number", "name", "text", "moment"],
          properties: { number: { type: "integer" }, name: { type: "string" }, text: { type: "string" }, moment: { type: "string" } },
        },
      },
    },
  },
});

/// GET /guide?circuit=<circuitId>&corners=<count>
export async function handleGuide(request, env) {
  const url = new URL(request.url);
  if (url.pathname !== "/guide") return null;
  const id = url.searchParams.get("circuit") || "";
  const n = Number(url.searchParams.get("corners"));
  if (!/^[a-z_]{2,40}$/.test(id) || !(n >= 5 && n <= 30)) return json({ error: "bad request" }, 400);

  const cached = await env.TOKENS.get(`guide:${id}`, "json");
  if (cached) return json(cached, 3600);

  // Only checked guides are served (scripts/guide/make_guide.py builds them
  // from the real track geometry). The AI draft path stays off: its corner
  // directions weren't reliable.
  return json({ error: "no guide" }, 404);
}

function json(data, maxAge = 0) {
  return new Response(JSON.stringify(data), {
    status: data.error ? (data.error === "no guide" ? 404 : data.error === "bad request" ? 400 : 503) : 200,
    headers: { "content-type": "application/json", "cache-control": maxAge ? `public, max-age=${maxAge}` : "no-store" },
  });
}
