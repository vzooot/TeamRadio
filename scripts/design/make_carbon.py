#!/usr/bin/env python3
"""2×2 twill carbon fibre, the way it actually looks under clear coat:
- rectangular tows (each visible float is two cells long, one wide)
- fine fibre striations running along every tow
- each tow bundle is rounded: bright down the middle, dark at the edges,
  dipping darker where it dives under the crossing tow
- brightness is set by tow DIRECTION vs. the light: horizontal tows are
  bright where vertical ones are dark and vice versa, flipping in soft zones
  across the panel like a curved part
- a broad clear-coat sheen and a vignette
"""
import numpy as np
from PIL import Image, ImageFilter

W, H = 1290, 1020          # 3× of a 430×340pt card
CELL = 9                   # tow width, px (3pt); floats are 2 cells long

def field(cells, seed):
    r = np.random.default_rng(seed)
    small = (r.random((cells[1], cells[0])) * 255).astype(np.uint8)
    return np.array(Image.fromarray(small).resize((W, H), Image.BICUBIC)) / 255.0

def fractal(seed):
    f = (0.5 * (field((3, 3), seed) - 0.5) + 0.3 * (field((6, 5), seed + 1) - 0.5)
         + 0.2 * (field((12, 10), seed + 2) - 0.5))
    return f / 0.5

y, x = np.mgrid[0:H, 0:W].astype(np.float64)

# --- grid, very slightly warped (woven cloth is never dead straight) -----------------
xw = x + 2.5 * fractal(10)
yw = y + 2.5 * fractal(20)
ci = np.floor(xw / CELL).astype(int)
cj = np.floor(yw / CELL).astype(int)
fx = (xw - ci * CELL) / CELL           # 0..1 across the cell
fy = (yw - cj * CELL) / CELL
horizontal = ((ci + cj) % 4) < 2        # 2×2 twill: horizontal floats step diagonally

# position along the float (0..1 over its two-cell length) and across it
along_h = ((ci % 4) - (cj % 4 >= 2) * 2) % 2 + fx     # which of the float's two cells, plus fraction
along_h = (along_h % 2) / 2
along_v = ((cj % 4) - (ci % 4 >= 2) * 2) % 2 + fy
along_v = (along_v % 2) / 2
across = np.where(horizontal, fy, fx)
along = np.where(horizontal, along_h, along_v)

# rounded bundle: bright ridge in the middle, dark edges, dark ends where it dives under
ridge = 1.0 - (np.abs(across - 0.5) * 2) ** 1.6
ends = 1.0 - 0.55 * (np.abs(along - 0.5) * 2) ** 3
bundle = 0.35 + 0.65 * ridge * ends

# fibre striations along the tow (about 4 fibres per tow width)
fibre = 0.86 + 0.14 * np.cos(across * 4 * 2 * np.pi)

# --- lighting by direction: smooth zones where one direction shines --------------------
angle = fractal(30)                                   # -1..1 across the panel
light_h = np.clip(0.55 + 0.75 * angle, 0.12, 1.5)
light_v = np.clip(0.55 - 0.75 * angle, 0.12, 1.5)
tone = np.where(horizontal, light_h, light_v)
# specular clear coat: broad diagonal sheen plus one softer pool
d = (x / W) * 0.9 + (y / H) * 0.6
# clear-coat gloss: a broader, stronger diagonal sheen plus two soft specular pools
sheen = (0.8 + 0.95 * np.exp(-((d - 0.55) / 0.24) ** 2)
         + 0.5 * np.exp(-(((x / W - 0.75) ** 2 + (y / H - 0.25) ** 2) / 0.05))
         + 0.35 * np.exp(-(((x / W - 0.2) ** 2 + (y / H - 0.8) ** 2) / 0.04)))
cx, cy = x / W - 0.5, y / H - 0.5
vign = 1.0 - 0.45 * np.clip((cx * cx * 1.4 + cy * cy * 2.2) * 1.6, 0, 1)

lum = 0.085 * bundle * fibre * tone * sheen * vign
gap = (fx < 0.06) | (fy < 0.06)
lum = np.where(gap, lum * 0.55, lum)
lum = np.clip(lum, 0, 1)

tint = np.clip((lum - 0.04) * 4, 0, 1)
r = lum * (0.94 - 0.08 * tint)
g = lum * (0.97 + 0.02 * tint)
b = lum * (1.05 + 0.18 * tint) + 0.006
img = (np.clip(np.stack([r, g, b], axis=-1), 0, 1) * 255).astype(np.uint8)
out = Image.fromarray(img).filter(ImageFilter.GaussianBlur(0.4))
import os
out.save(os.path.join(os.path.dirname(__file__), "..", "..", "TeamRadio", "Assets.xcassets", "Carbon.imageset", "Carbon.jpg"), quality=92)
arr = np.asarray(out.convert("L")) / 255.0
print(out.size, "mean %.3f  p5 %.3f  p95 %.3f" % (arr.mean(), np.percentile(arr, 5), np.percentile(arr, 95)))
