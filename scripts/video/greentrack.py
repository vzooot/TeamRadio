"""Tracks a chroma-green phone screen in AI footage, frame by frame.

The screen's outline is found per frame (no smoothing across frames, so it
never lags behind the hand): the convex hull of the green area bridges
whatever the thumb covers, a line is fitted to each of the 4 sides (ignoring
the rounded corners), and the corners are where those lines meet. That keeps
the perspective of a tilted phone, which a rotated box can't.
"""
import cv2
import numpy as np


def matte(frame):
    """Soft 0..1 matte of the chroma green."""
    f = frame.astype(np.int16)
    g = f[..., 1] - np.maximum(f[..., 0], f[..., 2])
    return np.clip((g - 35) / 55, 0, 1).astype(np.float32)


def _order(box):
    """4 points → TL, TR, BR, BL of an upright-ish phone."""
    c = box.mean(0)
    e1, e2 = box[1] - box[0], box[2] - box[1]
    up = e1 if np.linalg.norm(e1) > np.linalg.norm(e2) else e2
    up = up / np.linalg.norm(up)
    if up[1] > 0:
        up = -up
    right = np.array([-up[1], up[0]])
    if right[0] < 0:
        right = -right
    pick = lambda sx, sy: box[np.argmax([(p - c) @ (sx * right + sy * up) for p in box])]
    return np.array([pick(-1, 1), pick(1, 1), pick(1, -1), pick(-1, -1)], np.float32)


def _intersect(l1, l2):
    (vx1, vy1, x1, y1), (vx2, vy2, x2, y2) = l1, l2
    a = np.array([[vx1, -vx2], [vy1, -vy2]])
    t = np.linalg.solve(a, np.array([x2 - x1, y2 - y1]))
    return np.array([x1 + t[0] * vx1, y1 + t[0] * vy1], np.float32)


def quad(m):
    """TL, TR, BR, BL corners (sub-pixel) of the green screen in matte m, or None."""
    mask = (m > 0.5).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    if not cs:
        return None
    c = max(cs, key=cv2.contourArea)
    if cv2.contourArea(c) < 400:
        return None
    hull = cv2.convexHull(c)[:, 0, :].astype(np.float32)
    # dense points along the hull outline (the bridged thumb notch becomes a straight edge)
    pts = []
    for a, b in zip(hull, np.roll(hull, -1, 0)):
        n = max(2, int(np.linalg.norm(b - a)))
        pts.append(a + (b - a) * np.linspace(0, 1, n, endpoint=False)[:, None])
    pts = np.concatenate(pts)
    # keep only real edge: where the hull bridges a covered stretch (thumb), it's off the contour
    on_edge = np.array([abs(cv2.pointPolygonTest(c, (float(x), float(y)), True)) < 1.5 for x, y in pts])
    pts = pts[on_edge]
    rough = _order(cv2.boxPoints(cv2.minAreaRect(hull)))
    lines = []
    for i in range(4):
        a, b = rough[i], rough[(i + 1) % 4]
        d = b - a
        L = np.linalg.norm(d)
        u = d / L
        nrm = np.array([-u[1], u[0]])
        rel = pts - a
        along, off = rel @ u, rel @ nrm
        # points near this side, away from the rounded corners
        sel = (along > 0.18 * L) & (along < 0.82 * L) & (np.abs(off) < 0.12 * L)
        if sel.sum() < 8:
            return rough
        lines.append(cv2.fitLine(pts[sel], cv2.DIST_HUBER, 0, 0.01, 0.01).ravel())
    # corner i sits between side i-1 and side i (sides: top, right, bottom, left)
    return np.array([_intersect(lines[i - 1], lines[i]) for i in range(4)], np.float32)


def track(frames):
    """Corners per frame; frames where detection fails borrow the nearest good one.
    Per-frame edge noise (≈1 px at 480p, 2+ px once upscaled) is removed with a
    Savitzky–Golay filter run over the whole shot: it's centred, so it follows the
    hand without lag, and fits local curves, so quick moves aren't flattened."""
    from scipy.signal import savgol_filter
    qs = [quad(matte(f)) for f in frames]
    good = [i for i, q in enumerate(qs) if q is not None]
    qs = np.array([qs[min(good, key=lambda g: abs(g - i))] for i in range(len(qs))])
    win = min(len(qs) - (1 - len(qs) % 2), 11)
    return savgol_filter(qs, win, 2, axis=0, mode='interp').astype(np.float32) if win >= 5 else qs
