"""Build TeamRadio/Resources/sepang.json from OSM circuit relation 284496.

Same format as madring.json: centerline in decimeters (x east, y north),
equal arc-length spacing, per-point elevation (Open-Meteo), corners detected
from curvature, start at the Start-Finish node, race direction.
"""
import json, math, sys, urllib.request

M = json.load(open('sepang_map.json'))
N = {e['id']: e for e in M['elements'] if e['type'] == 'node'}
W = {e['id']: e for e in M['elements'] if e['type'] == 'way'}
R = next(e for e in M['elements'] if e['type'] == 'relation' and e['id'] == 284496)

# --- stitch the oneway member ways into one loop (members are listed in reverse)
ways = [W[m['ref']]['nodes'] for m in R['members'] if m['type'] == 'way' and m['role'] == '']
by_start = {w[0]: w for w in ways}
loop, cur = [], ways[-1]
for _ in range(len(ways)):
    loop += cur[:-1]
    cur = by_start[cur[-1]]
assert cur is ways[-1], 'loop did not close'

LAT0, LON0 = 2.7607601, 101.7383513          # Start-Finish node
KX = 111320 * math.cos(math.radians(LAT0))
KY = 110574
def xy(lat, lon): return ((lon - LON0) * KX, (lat - LAT0) * KY)
pts = [xy(N[n]['lat'], N[n]['lon']) for n in loop]

# start at the node nearest the start line
i0 = min(range(len(pts)), key=lambda i: math.hypot(*pts[i]))
pts = pts[i0:] + pts[:i0]

# --- resample to equal spacing, then smooth (closed loop)
def resample(p, n):
    seg = [math.dist(p[i], p[(i + 1) % len(p)]) for i in range(len(p))]
    L = sum(seg); step = L / n; out = []; i = 0; acc = 0.0
    for k in range(n):
        t = k * step
        while acc + seg[i] < t: acc += seg[i]; i += 1
        f = (t - acc) / seg[i]; a, b = p[i], p[(i + 1) % len(p)]
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out, L
def smooth(p, r=2, passes=2):
    n = len(p)
    for _ in range(passes):
        p = [(sum(p[(i + k) % n][0] for k in range(-r, r + 1)) / (2 * r + 1),
              sum(p[(i + k) % n][1] for k in range(-r, r + 1)) / (2 * r + 1)) for i in range(n)]
    return p
dense, L = resample(pts, 2000)
dense = smooth(dense, 2, 2)
P, L2 = resample(dense, 640)
print('length m', round(L), '->', round(L2), file=sys.stderr)

# --- corners: peaks of turning angle over a ~60 m window, strongest 15, >=120 m apart
n = len(P); ds = L2 / n; w = max(2, round(30 / ds))
def heading(a, b): return math.atan2(b[1] - a[1], b[0] - a[0])
turn = []
for i in range(n):
    h1 = heading(P[(i - w) % n], P[i]); h2 = heading(P[i], P[(i + w) % n])
    turn.append(abs((h2 - h1 + math.pi) % (2 * math.pi) - math.pi))
cand = sorted(range(n), key=lambda i: -turn[i])
chosen = []
gap = round(120 / ds)
for i in cand:
    if all(min(abs(i - j), n - abs(i - j)) >= gap for j in chosen): chosen.append(i)
    if len(chosen) == int(sys.argv[1] if len(sys.argv) > 1 else 15): break
chosen.sort()

# --- elevation (Open-Meteo, 100 coords per call)
def ll(p): return (LAT0 + p[1] / KY, LON0 + p[0] / KX)
import os, time
elev = json.load(open('elev_cache.json')) if os.path.exists('elev_cache.json') else []
for k in range(len(elev), n, 100):
    chunk = [ll(p) for p in P[k:k + 100]]
    url = ('https://api.open-meteo.com/v1/elevation?latitude=' + ','.join(f'{a:.6f}' for a, _ in chunk)
           + '&longitude=' + ','.join(f'{b:.6f}' for _, b in chunk))
    for attempt in range(6):
        try:
            elev += json.load(urllib.request.urlopen(url, timeout=30))['elevation']; break
        except Exception as ex:
            print('retry', k, ex, file=sys.stderr); time.sleep(15 * (attempt + 1))
    json.dump(elev, open('elev_cache.json', 'w')); time.sleep(3)
# light smoothing, then relative to the lowest point, decimeters
e = elev
for _ in range(3): e = [(e[(i - 1) % n] + e[i] + e[(i + 1) % n]) / 3 for i in range(n)]
lo = min(e)

r1 = lambda v: round(v * 10, 1)
out = {
    'x': [r1(p[0]) for p in P],
    'y': [r1(p[1]) for p in P],
    'z': [round((v - lo) * 10, 1) for v in e],
    'corners': [{'number': k + 1, 'trackPosition': {'x': r1(P[i][0]), 'y': r1(P[i][1])}} for k, i in enumerate(chosen)],
    'rotation': 0, 'pitLoss': None, 'circuitName': 'Sepang', 'year': 2026,
}
json.dump(out, open('sepang.json', 'w'), separators=(',', ':'))
area = sum(P[i][0] * P[(i + 1) % n][1] - P[(i + 1) % n][0] * P[i][1] for i in range(n))
print('corners', len(chosen), 'clockwise', area < 0, 'elev spread m', round(max(e) - lo, 1), file=sys.stderr)
