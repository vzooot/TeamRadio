#!/usr/bin/env python3
"""The "Made for iPhone Duo" in-app event art, in the Duo store panels'
look: the card (1920 × 1080) and the details page (1080 × 1920), each with
the headline and the unfolded Duo's screen. Writes Marketing/event-duo-*.png."""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import compose_panels_duo as duo  # noqa: E402

GRAD = [(0, (4, 7, 15)), (0.5, (7, 13, 28)), (1, (5, 9, 20))]


def background(w, h):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(GRAD) - 1):
            if GRAD[i][0] <= t <= GRAD[i + 1][0]:
                f = (t - GRAD[i][0]) / (GRAD[i + 1][0] - GRAD[i][0])
                img.putpixel((0, y), tuple(int(GRAD[i][1][k] + (GRAD[i + 1][1][k] - GRAD[i][1][k]) * f) for k in range(3)))
                break
    c = img.resize((w, h)).convert("RGBA")
    art = duo.neon_track(int(max(w, h) * 1.1), -14, line_w=12)
    art.putalpha(art.getchannel("A").point(lambda v: v * 55 // 255))
    c.alpha_composite(art, (-int(w * 0.25), -int(h * 0.3)))
    return c


def title(c, x, y, size, width):
    d = ImageDraw.Draw(c)
    while size > 40:
        f = ImageFont.truetype(duo.FONT, size)
        if d.textlength("IPHONE DUO", font=f) <= width:
            break
        size -= 4
    f = ImageFont.truetype(duo.FONT, size)
    s = size / 150
    for i, sx in enumerate([x, x + 52 * s, x + 104 * s]):
        d.polygon([(sx + 44 * s, y - 20 * s), (sx + 82 * s, y - 20 * s), (sx + 38 * s, y + 118 * s), (sx, y + 118 * s)],
                  fill=duo.RED + (235 - i * 60,))
    d.text((x, y + 150 * s), "MADE FOR", font=f, fill=duo.WHITE + (255,))
    d.text((x, y + 150 * s + size + 8), "IPHONE DUO", font=f, fill=duo.BLUE + (255,))


def place(c, shot, width, x, y):
    dev = duo.device(shot, width)
    halo = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle([x - 10, y - 10, x + dev.width + 10, y + dev.height + 10], radius=110, fill=duo.BLUE + (80,))
    c.alpha_composite(halo.filter(ImageFilter.GaussianBlur(55)))
    c.alpha_composite(dev, (x, y))


shot = Image.open(os.path.join(duo.RAW, "duo-countdown.png")).convert("RGB")

# the card: the headline on the left, the screen on the right
card = background(1920, 1080)
duo.glow_blob(card, (1250, 540), 560, duo.BLUE, 46)
duo.glow_blob(card, (1840, 120), 220, duo.RED, 36)
title(card, 110, 330, 110, 560)
place(card, shot, 1120, 1920 - 1156 - 80, (1080 - 820) // 2)
card.convert("RGB").save(os.path.join(duo.PROJ, "Marketing", "event-duo-card.png"))

# the details page: the headline on top, the screen below
page = background(1080, 1920)
duo.glow_blob(page, (540, 1250), 620, duo.BLUE, 46)
duo.glow_blob(page, (1000, 160), 240, duo.RED, 36)
title(page, 90, 260, 130, 880)
place(page, shot, 960, (1080 - 996) // 2, 980)
page.convert("RGB").save(os.path.join(duo.PROJ, "Marketing", "event-duo-details.png"))
print("event art done")
