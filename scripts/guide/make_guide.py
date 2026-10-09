#!/usr/bin/env python3
"""Builds the circuit guide (one line per corner) from facts measured on the
real track geometry (geometry.py): direction, sharpness, the straight before.
Names only where they're certain; no invented "famous moments".

    scripts/guide/make_guide.py              # all circuits in KEYS
    scripts/guide/make_guide.py americas     # one

Output: server/guides/<circuitId>.json, uploaded to the Worker's KV
(guide:<circuitId>) with scripts/guide/upload.sh.
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geometry as G

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'server', 'guides')

# Widely used corner names, current layouts. Only names we're sure of.
NAMES = {
    'interlagos': {1: 'Senna S', 2: 'Senna S', 4: 'Descida do Lago', 6: 'Ferradura', 7: 'Ferradura',
                   8: 'Pinheirinho', 10: 'Bico de Pato', 11: 'Mergulho', 12: 'Junção'},
    'rodriguez': {12: 'Foro Sol stadium', 13: 'Foro Sol stadium', 14: 'Foro Sol stadium', 15: 'Foro Sol stadium',
                  16: 'Foro Sol stadium'},
}


def sharpness(a):
    if a >= 100:
        return 'hairpin'
    if a >= 60:
        return 'slow'
    if a >= 35:
        return 'medium'
    if a >= 18:
        return 'fast'
    return 'kink'


def line(f, longest, lap_m):
    side = 'left' if f['turn'] > 0 else 'right'
    kind = sharpness(abs(f['turn']))
    gap_m = int(round(f['gap'] * lap_m / 10 / 10) * 10)      # map units are decimetres
    head = {
        'hairpin': f'Tight {side}-hand hairpin',
        'slow': f'Slow {side}-hander',
        'medium': f'Medium-speed {side}-hander',
        'fast': f'Fast {side}-hand sweep',
        'kink': f'Flat-out {side} kink',
    }[kind]
    if f['number'] in longest and gap_m >= 400:
        return f'{head} at the end of a {gap_m} m straight. Heavy braking and a prime overtaking spot.'
    if gap_m >= 400 and kind in ('hairpin', 'slow', 'medium'):
        return f'{head} after a {gap_m} m run. A big stop and a chance to dive down the inside.'
    if gap_m < 120 and f['number'] > 1:
        return f'{head}, straight after Turn {f["number"] - 1}: a quick change of direction.'
    if kind in ('hairpin', 'slow'):
        return f'{head}. Traction out of here decides the next straight.'
    if kind == 'kink':
        return f'{head}, taken at full throttle with the car settled.'
    return f'{head}. Carry the speed and keep the car tidy over the kerbs.'


def build(circuit):
    d = G.load(circuit)
    facts, lap = G.facts(d)
    # the two corners after the longest straights get the overtaking line
    longest = {f['number'] for f in sorted(facts, key=lambda f: -f['gap'])[:2]}
    names = NAMES.get(circuit, {})
    corners = [{'number': f['number'], 'name': names.get(f['number'], ''),
                'text': line(f, longest, lap), 'moment': '',
                'side': 'left' if f['turn'] > 0 else 'right', 'kind': sharpness(abs(f['turn']))}
               for f in facts]
    guide = {'circuitId': circuit, 'reviewed': True, 'source': 'track geometry (MultiViewer)', 'corners': corners}
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f'{circuit}.json'), 'w') as fh:
        json.dump(guide, fh, ensure_ascii=False, indent=1)
    return guide


if __name__ == '__main__':
    for c in (sys.argv[1:] or G.KEYS):
        g = build(c)
        print(f'== {c} ({len(g["corners"])} corners)')
        for k in g['corners']:
            print(f'  T{k["number"]:<2} {k["name"] + " · " if k["name"] else ""}{k["text"]}')
