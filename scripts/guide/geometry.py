#!/usr/bin/env python3
"""Corner facts from the real track geometry (MultiViewer maps, the same data
the app draws): direction, how sharp, the straight before it.

    scripts/guide/geometry.py marina_bay
"""
import json, math, sys, urllib.request

KEYS = {'marina_bay': 61, 'americas': 9, 'rodriguez': 65, 'interlagos': 14, 'vegas': 152, 'losail': 150, 'yas_marina': 70}


def load(circuit, season=2026):
    url = f'https://api.multiviewer.app/api/v1/circuits/{KEYS[circuit]}/{season}'
    req = urllib.request.Request(url, headers={'User-Agent': 'TeamRadio-guide'})
    return json.load(urllib.request.urlopen(req, timeout=20))


def facts(d):
    pts = list(zip(d['x'], d['y']))
    n = len(pts)
    seg = [math.dist(pts[i], pts[(i + 1) % n]) for i in range(n)]
    lap = sum(seg)
    cum = [0.0]
    for s in seg[:-1]:
        cum.append(cum[-1] + s)

    def heading(i):
        a, b = pts[i % n], pts[(i + 1) % n]
        return math.atan2(b[1] - a[1], b[0] - a[0])

    def turn(i0, i1):
        """Total signed heading change from point i0 to i1 (degrees)."""
        tot, i = 0.0, i0
        while i % n != i1 % n:
            d = heading(i + 1) - heading(i)
            d = (d + math.pi) % (2 * math.pi) - math.pi
            tot += d
            i += 1
        return math.degrees(tot)

    def idx_at(dist):
        dist %= lap
        return min(range(n), key=lambda i: abs(cum[i] - dist))

    corners = sorted(d['corners'], key=lambda c: c['number'])
    idxs = [min(range(n), key=lambda i: math.dist(pts[i], (c['trackPosition']['x'], c['trackPosition']['y'])))
            for c in corners]
    out = []
    win = lap * 0.006   # window around the apex, share of the lap
    for k, (c, i) in enumerate(zip(corners, idxs)):
        a = turn(idx_at(cum[i] - win), idx_at(cum[i] + win))
        # straight before: distance back to the previous corner's apex
        prev = idxs[k - 1]
        gap = (cum[i] - cum[prev]) % lap
        out.append({'number': c['number'], 'turn': round(a), 'gap': gap / lap})
    return out, lap


if __name__ == '__main__':
    d = load(sys.argv[1])
    f, lap = facts(d)
    print('lap units', round(lap))
    for x in f:
        print(x)
