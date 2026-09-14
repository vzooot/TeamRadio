#!/usr/bin/env python3
"""Store panels v3 — one disciplined system: headline block on top, a single
large grounded device (full screen, bleeding off the bottom), neon Madring
line art and glow as atmosphere behind. Identical structure on all panels."""
import json
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import os
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(PROJ, "Marketing", "raw")          # raw simulator captures
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
W, H = 1320, 2868
BLUE = (46, 178, 255)
RED = (253, 75, 40)
WHITE = (240, 246, 255)

track = json.load(open(f"{PROJ}/TeamRadio/Resources/madring.json"))
TX, TY = track["x"], track["y"]

PANELS = [
    ("countdown", "NEVER MISS", "LIGHTS OUT", "Alerts & Lock Screen countdowns, automatic"),
    ("track", "THE CIRCUIT,", "ALIVE IN 3D", "Ghost car, sector colors & real elevation"),
    ("chat", "THE PADDOCK,", "LIVE", "Fan chat with GIFs, photos & videos"),
    ("results", "RESULTS,", "SPOILER-SAFE", "Hidden until you say so"),
    ("standings", "EVERY POINT", "COUNTS", "Full championship tables, always live"),
    ("news", "EVERY", "HEADLINE", "F1.com, BBC Sport & Motorsport.com, in one feed"),
]

def gradient_bg():
    img = Image.new("RGB", (1, H))
    stops = [(0, (4, 7, 15)), (0.5, (7, 13, 28)), (1, (5, 9, 20))]
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                f = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                img.putpixel((0, y), tuple(int(stops[i][1][k] + (stops[i + 1][1][k] - stops[i][1][k]) * f) for k in range(3)))
                break
    return img.resize((W, H)).convert("RGBA")

def glow_blob(c, center, radius, color, alpha):
    l = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(l).ellipse([center[0]-radius, center[1]-radius, center[0]+radius, center[1]+radius], fill=color+(alpha,))
    c.alpha_composite(l.filter(ImageFilter.GaussianBlur(radius/2.0)))

def neon_track(size, rotation_deg, line_w=14):
    n = len(TX)
    minx, maxx, miny, maxy = min(TX), max(TX), min(TY), max(TY)
    span = max(maxx - minx, maxy - miny)
    pad = 0.14 * size
    pts = [((TX[i] - minx) / span * (size - 2 * pad) + pad,
            size - ((TY[i] - miny) / span * (size - 2 * pad) + pad)) for i in range(n)]
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    third = n // 3
    for s, col in enumerate([BLUE, WHITE, RED]):
        seg = pts[s * third:(s + 1) * third + 2] if s < 2 else pts[2 * third:] + pts[:2]
        d.line(seg, fill=col + (255,), width=line_w, joint="curve")
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(line_w * 1.7)))
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(line_w * 0.5)))
    out.alpha_composite(layer)
    return out.rotate(rotation_deg, expand=True, resample=Image.BICUBIC)

# one shared, pre-rendered atmosphere so every panel matches exactly
TRACK_ART = neon_track(1900, -14)
TRACK_ART.putalpha(TRACK_ART.getchannel("A").point(lambda v: v * 60 // 255))

head_cache = {}
def headline(c, line1, line2, sub):
    d = ImageDraw.Draw(c)
    size = 160
    while size > 90:
        f = ImageFont.truetype(FONT, size)
        if max(d.textlength(line1, font=f), d.textlength(line2, font=f)) <= W - 200:
            break
        size -= 6
    f = ImageFont.truetype(FONT, size)
    fs = ImageFont.truetype(FONT, 47)
    y = 150
    for i, x in enumerate([100, 152, 204]):
        d.polygon([(x + 44, y - 20), (x + 82, y - 20), (x + 38, y + 118), (x, y + 118)], fill=RED + (235 - i * 60,))
    d.text((100, y + 140), line1, font=f, fill=WHITE + (255,))
    d.text((100, y + 140 + size + 10), line2, font=f, fill=BLUE + (255,))
    d.text((104, y + 140 + 2 * size + 48), sub, font=fs, fill=(152, 174, 206, 255))

def device(shot):
    """Full screenshot as one large, straight, grounded device."""
    pw = 1104
    ph = int(shot.height * pw / shot.width)
    scr = shot.resize((pw, ph), Image.LANCZOS)
    mask = Image.new("L", scr.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw - 1, ph - 1], radius=124, fill=255)
    scr = scr.convert("RGBA")
    scr.putalpha(mask)

    bez = 16
    holder = Image.new("RGBA", (pw + bez * 2, ph + bez * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(holder)
    d.rounded_rectangle([0, 0, pw + 2 * bez - 1, ph + 2 * bez - 1], radius=124 + bez, fill=(16, 24, 40, 255))
    d.rounded_rectangle([0, 0, pw + 2 * bez - 1, ph + 2 * bez - 1], radius=124 + bez, outline=(74, 108, 156, 255), width=3)
    holder.alpha_composite(scr, (bez, bez))
    return holder

for name, l1, l2, sub in PANELS:
    c = gradient_bg()
    # fixed atmosphere: track art upper area, glows in the same three spots
    c.alpha_composite(TRACK_ART, (-290, -60))
    glow_blob(c, (W // 2, 1120), 720, BLUE, 46)
    glow_blob(c, (W - 110, 300), 330, RED, 36)
    glow_blob(c, (90, 2700), 380, BLUE, 30)

    headline(c, l1, l2, sub)

    shot = Image.open(f"{RAW}/panel-{name}.png").convert("RGB")
    dev = device(shot)
    dx = (W - dev.width) // 2
    dy = 880

    # halo behind the device's visible top half
    halo = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle([dx - 10, dy - 10, dx + dev.width + 10, H + 200],
                                           radius=150, fill=BLUE + (85,))
    c.alpha_composite(halo.filter(ImageFilter.GaussianBlur(70)))

    c.alpha_composite(dev, (dx, dy))
    c.convert("RGB").save(f"{PROJ}/fastlane/screenshots/en-US/0{PANELS.index((name, l1, l2, sub)) + 1}-{name}.png", quality=95)
    print("v3", name)

sheet = Image.new("RGB", (6 * 440 + 60, 1000), (8, 10, 16))
for i, (name, *_r) in enumerate(PANELS):
    p = Image.open(f"{PROJ}/fastlane/screenshots/en-US/0{i + 1}-{name}.png").resize((440, 956), Image.LANCZOS)
    sheet.paste(p, (10 + i * 440, 22))
sheet.save(f"{PROJ}/Marketing/store-contact-sheet.png")
print("sheet done")
