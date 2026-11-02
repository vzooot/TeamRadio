#!/usr/bin/env python3
"""iPhone Duo store panels (inner display, 2853 × 2007): the phone panels'
system turned sideways. The headline block in a column on the left, the
unfolded Duo's screen large on the right, neon Madring line art and glow as
atmosphere behind. Raw captures: Marketing/raw/duo-<name>.png (the Duo
simulator's inner display, `xcrun simctl io <id> screenshot --display=3`)."""
import json
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(PROJ, "Marketing", "raw")
OUT = os.path.join(PROJ, "fastlane", "screenshots", "duo")
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
W, H = 2853, 2007
BLUE = (46, 178, 255)
RED = (253, 75, 40)
WHITE = (240, 246, 255)

track = json.load(open(f"{PROJ}/TeamRadio/Resources/madring.json"))
TX, TY = track["x"], track["y"]

PANELS = [
    ("countdown", "MADE FOR", "IPHONE DUO", "Two screens: pick on one, see it on the other"),
    ("circuit", "THE CIRCUIT", "ON THE DISPLAY", "Countdown, circuit or standings, your pick"),
    ("results", "EVERY ROUND,", "SIDE BY SIDE", "Pick a race, see how it finished"),
    ("standings", "THE TABLE", "AFTER EVERY RACE", "Who gained, who lost, and by how much"),
    ("games", "PLAY ON", "TWO SCREENS", "Your picks on one, the arcade on the other"),
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
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius], fill=color + (alpha,))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius / 2.0)))


def neon_track(size, rotation_deg, line_w=16):
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


# one shared atmosphere so every panel matches
TRACK_ART = neon_track(2400, -14)
TRACK_ART.putalpha(TRACK_ART.getchannel("A").point(lambda v: v * 55 // 255))

COLUMN = 760  # the headline column's width (clear of the device)


def headline(c, line1, line2, sub):
    d = ImageDraw.Draw(c)
    size = 150
    while size > 70:
        f = ImageFont.truetype(FONT, size)
        if max(d.textlength(line1, font=f), d.textlength(line2, font=f)) <= COLUMN:
            break
        size -= 4
    f = ImageFont.truetype(FONT, size)
    fs = ImageFont.truetype(FONT, 50)
    x, y = 120, 640
    for i, sx in enumerate([x, x + 52, x + 104]):
        d.polygon([(sx + 44, y - 20), (sx + 82, y - 20), (sx + 38, y + 118), (sx, y + 118)], fill=RED + (235 - i * 60,))
    d.text((x, y + 150), line1, font=f, fill=WHITE + (255,))
    d.text((x, y + 150 + size + 10), line2, font=f, fill=BLUE + (255,))
    # the line under it, wrapped to the column
    words, lines, line = sub.split(), [], ""
    for word in words:
        test = (line + " " + word).strip()
        if d.textlength(test, font=fs) <= COLUMN:
            line = test
        else:
            lines.append(line)
            line = word
    lines.append(line)
    for i, text in enumerate(lines):
        d.text((x + 4, y + 150 + 2 * size + 60 + i * 66), text, font=fs, fill=(152, 174, 206, 255))


def device(shot, pw):
    """The inner display as one large, straight device."""
    ph = int(shot.height * pw / shot.width)
    scr = shot.resize((pw, ph), Image.LANCZOS)
    mask = Image.new("L", scr.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw - 1, ph - 1], radius=96, fill=255)
    scr = scr.convert("RGBA")
    scr.putalpha(mask)
    bez = 18
    holder = Image.new("RGBA", (pw + bez * 2, ph + bez * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(holder)
    d.rounded_rectangle([0, 0, pw + 2 * bez - 1, ph + 2 * bez - 1], radius=96 + bez, fill=(16, 24, 40, 255))
    d.rounded_rectangle([0, 0, pw + 2 * bez - 1, ph + 2 * bez - 1], radius=96 + bez, outline=(74, 108, 156, 255), width=3)
    # the fold, a faint line down the middle of the bezel's top and bottom
    d.line([(holder.width // 2, 0), (holder.width // 2, bez)], fill=(74, 108, 156, 255), width=3)
    d.line([(holder.width // 2, holder.height - bez), (holder.width // 2, holder.height)], fill=(74, 108, 156, 255), width=3)
    holder.alpha_composite(scr, (bez, bez))
    return holder


def main():
    os.makedirs(OUT, exist_ok=True)
    for index, (name, l1, l2, sub) in enumerate(PANELS):
        c = gradient_bg()
        c.alpha_composite(TRACK_ART, (-500, -600))
        glow_blob(c, (W - 950, H // 2), 900, BLUE, 46)
        glow_blob(c, (W - 140, 260), 330, RED, 36)
        glow_blob(c, (260, H - 160), 380, BLUE, 30)

        headline(c, l1, l2, sub)

        shot = Image.open(f"{RAW}/duo-{name}.png").convert("RGB")
        dev = device(shot, 1700)
        dx = W - dev.width - 100
        dy = (H - dev.height) // 2

        halo = Image.new("RGBA", c.size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).rounded_rectangle([dx - 10, dy - 10, dx + dev.width + 10, dy + dev.height + 10], radius=130, fill=BLUE + (80,))
        c.alpha_composite(halo.filter(ImageFilter.GaussianBlur(70)))
        c.alpha_composite(dev, (dx, dy))
        c.convert("RGB").save(f"{OUT}/0{index + 1}-{name}.png", quality=95)
        print("duo", name)

    sheet = Image.new("RGB", (2 * 1000 + 30, 3 * 704 + 40), (8, 10, 16))
    for i, (name, *_rest) in enumerate(PANELS):
        p = Image.open(f"{OUT}/0{i + 1}-{name}.png").resize((1000, 704), Image.LANCZOS)
        sheet.paste(p, (10 + (i % 2) * 1010, 10 + (i // 2) * 714))
    sheet.save(f"{PROJ}/Marketing/store-duo-sheet.png")
    print("sheet done")


if __name__ == "__main__":
    main()
