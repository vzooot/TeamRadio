#!/usr/bin/env python3
"""App Store search results asset (3:2, 3840x2560): headline on the left,
three real app screens fanned on the right, in the store panels' look."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(PROJ, "scripts", "store", "compose_panels.py")
g = {"__file__": SRC}
exec(open(SRC).read().split("for name, l1, l2, sub in PANELS:")[0], g)
FONT, BLUE, RED, WHITE = g["FONT"], g["BLUE"], g["RED"], g["WHITE"]
RAW = os.path.join(PROJ, "Marketing", "raw")
W, H = 3840, 2560

img = Image.new("RGB", (1, H))
for y in range(H):
    t = y / (H - 1)
    img.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip((4, 7, 15), (6, 11, 24))))
c = img.resize((W, H)).convert("RGBA")
track = g["neon_track"](3000, -14)
track.putalpha(track.getchannel("A").point(lambda v: v * 50 // 255))
c.alpha_composite(track, (-500, -300))
g["glow_blob"](c, (2700, 1350), 1100, BLUE, 60)
g["glow_blob"](c, (3500, 400), 500, RED, 45)

d = ImageDraw.Draw(c)
for i, dx in enumerate([0, 70, 140]):
    X = 260 + dx
    d.polygon([(X + 60, 560), (X + 112, 560), (X + 52, 750), (X, 750)], fill=RED + (235 - i * 60,))
f = ImageFont.truetype(FONT, 230)
d.text((260, 820), "NEVER MISS", font=f, fill=WHITE + (255,))
d.text((260, 1070), "LIGHTS OUT", font=f, fill=BLUE + (255,))
fs = ImageFont.truetype(FONT, 82)
for i, line in enumerate(["Live countdowns · predictions", "3D circuits · fan chat"]):
    d.text((268, 1420 + i * 110), line.replace("·", "-"), font=fs, fill=(152, 174, 206, 255))


def phone(name, height, angle):
    dev = g["device"](Image.open(os.path.join(RAW, f"panel-{name}.png")).convert("RGB"))
    dev = dev.resize((int(dev.width * height / dev.height), height), Image.LANCZOS)
    return dev.rotate(angle, expand=True, resample=Image.BICUBIC)


for name, x, y, h, a in [("game", 2380, 1300, 2050, 8), ("track", 3420, 1300, 2050, -8), ("countdown", 2900, 1260, 2300, 0)]:
    p = phone(name, h, a)
    shadow = Image.new("RGBA", c.size, (0, 0, 0, 0))
    shadow.alpha_composite(p, (x - p.width // 2, y - p.height // 2 + 60))
    blk = Image.new("RGBA", c.size, (0, 0, 0, 0))
    blk.putalpha(shadow.getchannel("A").point(lambda v: v * 150 // 255))
    c.alpha_composite(blk.filter(ImageFilter.GaussianBlur(60)))
    c.alpha_composite(p, (x - p.width // 2, y - p.height // 2))

out = os.path.join(PROJ, "Marketing", "search-asset-3840x2560.png")
c.convert("RGB").save(out)
print(out)
