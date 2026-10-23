#!/usr/bin/env python3
"""In-App Event art for the Reaction Wall Challenge: card 1920x1080 and
details page 1080x1920, in the store panels' look (gradient, neon track,
glows, real app screen in a device frame)."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(PROJ, "scripts", "store", "compose_panels.py")
g = {"__file__": SRC}
exec(open(SRC).read().split("for name, l1, l2, sub in PANELS:")[0], g)
FONT, BLUE, RED, WHITE = g["FONT"], g["BLUE"], g["RED"], g["WHITE"]
shot = Image.open(os.path.join(PROJ, "Marketing", "raw", "panel-wall.png")).convert("RGB")


def background(w, h):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        img.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip((4, 7, 15), (6, 11, 24))))
    c = img.resize((w, h)).convert("RGBA")
    track = g["neon_track"](int(max(w, h) * 1.1), -14)
    track.putalpha(track.getchannel("A").point(lambda v: v * 55 // 255))
    c.alpha_composite(track, (int(-w * 0.15), int(-h * 0.1)))
    return c


def device(height):
    d = g["device"](shot)
    return d.resize((int(d.width * height / d.height), height), Image.LANCZOS)


def headline(c, x, y, size, lines, sub=None, sub_size=40, center=False):
    d = ImageDraw.Draw(c)
    f = ImageFont.truetype(FONT, size)
    w = c.width
    for i, (text, col) in enumerate(lines):
        tw = d.textlength(text, font=f)
        d.text(((w - tw) / 2 if center else x, y + i * (size + 8)), text, font=f, fill=col + (255,))
    if sub:
        fs = ImageFont.truetype(FONT, sub_size)
        tw = d.textlength(sub, font=fs)
        d.text(((w - tw) / 2 if center else x + 4, y + len(lines) * (size + 8) + 22), sub, font=fs, fill=(152, 174, 206, 255))


def slashes(c, x, y, s=1.0):
    d = ImageDraw.Draw(c)
    for i, dx in enumerate([0, 52, 104]):
        X = x + dx * s
        d.polygon([(X + 44 * s, y - 20 * s), (X + 82 * s, y - 20 * s), (X + 38 * s, y + 118 * s), (X, y + 118 * s)], fill=RED + (235 - i * 60,))


# Card 1920x1080: headline left, device right (Apple adds the event name below)
card = background(1920, 1080)
g["glow_blob"](card, (1420, 560), 520, BLUE, 60)
g["glow_blob"](card, (1700, 220), 300, RED, 40)
slashes(card, 150, 300, 1.1)
headline(card, 150, 450, 120, [("TRAIN LIKE", WHITE), ("A DRIVER", BLUE)], "60 seconds. Every light counts.", 46)
dev = device(1500)
card.alpha_composite(dev, (1420 - dev.width // 2, 150))
card.convert("RGB").save(os.path.join(PROJ, "Marketing", "event-wall-card.png"))

# Details page 1080x1920: headline on top, device below
det = background(1080, 1920)
g["glow_blob"](det, (540, 1300), 560, BLUE, 60)
g["glow_blob"](det, (900, 260), 280, RED, 40)
slashes(det, 540 - 110, 170, 1.0)
headline(det, 0, 330, 104, [("TRAIN LIKE", WHITE), ("A DRIVER", BLUE)], "60 seconds. Weekly leaderboard.", 40, center=True)
dev = device(1640)
det.alpha_composite(dev, (540 - dev.width // 2, 700))
det.convert("RGB").save(os.path.join(PROJ, "Marketing", "event-wall-details.png"))
print("ok")
