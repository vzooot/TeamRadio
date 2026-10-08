#!/usr/bin/env python3
"""Emily videos: AI clips of the race engineer (made in PAI, saved in
Marketing/videos/ai) and the real app, cut to the music.

    scripts/video/emily.py emily-1            # the finished video
    scripts/video/emily.py emily-1 --fcp      # also a Final Cut Pro project to fine-tune

Every frame is built here and piped to ffmpeg:
- talking shots: the clip scaled to cover 1080×1920, optional punch-in,
  word-by-word captions of what she says (timings from Whisper, ai/words.json);
- phone shots: the chroma-green screen is tracked (greentrack.py) and the real
  app recording is fitted into it, matched to the footage; the over-the-shoulder
  shot ends zooming into the phone and cuts to the same recording full screen;
- app shots: the recording full screen with captions on a soft dark band.
Cuts land on the song's beat, and the song's own ending closes the video.
Text stays inside TikTok's safe zone (UI covers top ~15%, bottom ~25%, right ~12%).
Every clip keeps its own sound; the music ducks under her voice.

Output: Marketing/videos/out/<name>.mp4 (+ <name>-fcp/ with --fcp)
"""
import json, os, shutil, subprocess, sys, tempfile
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R
import greentrack as G

AI = os.path.join(R.ROOT, 'Marketing/videos/ai')
W, H, FPS = R.W, R.H, R.FPS
SAFE_CX = 500            # centre of the safe zone, clear of the right-hand buttons
CAPTION_Y = 1230         # captions: lower middle, above the caption/music area
CYAN = (64, 214, 255)

EMILY = {
    'emily-1': {
        'shots': [
            # talking shots: clip seconds; captions from what she says
            {'clip': 'clip_radio_check.mp4', 't': (1.42, 2.60)},
            # the whole intro, with a punch-in when she changes subject
            {'clip': 'clip_intro_emily.mp4', 't': (0.32, 10.05), 'punch': [(4.85, 1.14), (7.75, 1.0)]},
            # over the shoulder: the app plays in her phone from demo second `app`, then we zoom in
            {'clip': 'clip_ots_candid_reaction.mp4', 't': (0.55, 5.05), 'app': 20.9, 'zoom': 0.5, 'cap_y': 560},
            # app full screen, demo seconds (the first continues straight on from the phone);
            # text: caption groups split by |, *words* in cyan
            {'app': (25.4, 30.2), 'text': 'Pin the *countdown* | to your *Lock Screen*'},
            {'app': (30.6, 35.0), 'text': 'The whole *weekend* | in *your* time zone'},
            {'app': (38.6, 42.6), 'text': 'A heads-up | *15 minutes* before | every session'},
            # back to Emily holding the phone up, the app on it
            {'clip': 'clip_team_radio_tap.mp4', 't': (2.80, 5.00), 'app': 45.0},
            {'app': (47.4, 50.8), 'text': 'Free on the | *App Store*', 'small': 'Search “Team Radio” · unofficial fan app',
             'end': True},
        ],
        # Whisper's words, spelled the way they should read on screen
        'spelling': {'box': 'Box', 'box,': 'box.', "fp1's": "FP1's", 'FP': "FP1's", 'ones': '',
                     'night': 'night…', 'again': 'again.', 'team': 'Team', 'radio': 'Radio.', 'radio.': 'Radio.',
                     'Emily': 'Emily,', 'worry.': 'worry,', 'you': 'you.'},
        'music_end': 59.3,    # where the song's ending finishes
    },
}


# ---------- sources ----------

def clip_frames(path, t0, t1):
    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    frames, i = [], 0
    while True:
        ok, f = cap.read()
        if not ok:
            break
        if t0 - 1 / fps < i / fps <= t1 + 1 / fps:
            frames.append(f)
        i += 1
    return frames, fps, int(round(t0 * fps))


def clip_len(path):
    return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                          '-of', 'csv=p=0', path], text=True))


def app_frames(raw, offset, t0, t1):
    """The demo recording between two demo seconds, at the output frame rate, 1080 wide."""
    tmp = tempfile.mktemp(suffix='.mp4')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t0 + offset:.3f}', '-t', f'{t1 - t0 + 0.2:.3f}', '-i', raw,
                    '-an', '-vf', f'fps={FPS},scale={W}:-2:flags=lanczos', '-c:v', 'libx264', '-crf', '12', tmp],
                   check=True)
    cap, out = cv2.VideoCapture(tmp), []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        out.append(f)
    os.remove(tmp)
    return out


def cover(frame):
    h, w = frame.shape[:2]
    s = max(W / w, H / h)
    frame = cv2.resize(frame, (round(w * s), round(h * s)), interpolation=cv2.INTER_LANCZOS4)
    y, x = (frame.shape[0] - H) // 2, (frame.shape[1] - W) // 2
    return frame[y:y + H, x:x + W], s, x, y


def sharpen(f):
    blur = cv2.GaussianBlur(f, (0, 0), 1.6)
    return cv2.addWeighted(f, 1.45, blur, -0.45, 0)


def punch(f, z, cy=760):
    """Scale about the face (a jump zoom between sentences)."""
    if z == 1:
        return f
    M = np.float32([[z, 0, W / 2 * (1 - z)], [0, z, cy * (1 - z)]])
    return cv2.warpAffine(f, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def full_screen(app):
    """App frame (1080 wide, taller than 1920) cropped to fill the screen."""
    y = min(app.shape[0] - H, 90)
    return app[y:y + H]


APP_CX, APP_TOP, APP_H = SAFE_CX, 530, 1340   # the whole phone, below the caption card
CARD_Y = 400                                    # the caption card, just inside the top safe line


def rounded_mask(w, h, r):
    m = np.zeros((h, w), np.uint8)
    cv2.rectangle(m, (r, 0), (w - r, h), 255, -1)
    cv2.rectangle(m, (0, r), (w, h - r), 255, -1)
    for px, py in ((r, r), (w - r - 1, r), (r, h - r - 1), (w - r - 1, h - r - 1)):
        cv2.circle(m, (px, py), r, 255, -1, cv2.LINE_AA)
    return m


def paste(out, img, mask, x0, y0):
    """Alpha-paste img (h×w) at x0,y0 into out (float), clipped to the frame."""
    h, w = mask.shape
    ys, xs = max(0, y0), max(0, x0)
    ye, xe = min(H, y0 + h), min(W, x0 + w)
    if ye <= ys or xe <= xs:
        return
    m = (mask[ys - y0:ye - y0, xs - x0:xe - x0] / 255.0)[..., None]
    region = out[ys:ye, xs:xe]
    region[:] = img[ys - y0:ye - y0, xs - x0:xe - x0].astype(np.float32) * m + region * (1 - m)


def app_layout(app, e):
    """The whole iPhone screen (status bar to home indicator) in a slim black frame below
    the caption, on a blurred dark copy of itself. e 0→1 shrinks it from filling the
    screen into place, so the zoom out of her phone lands softly."""
    small = cv2.resize(full_screen(app), None, fx=0.125, fy=0.125, interpolation=cv2.INTER_AREA)
    bg = cv2.resize(cv2.GaussianBlur(small, (0, 0), 6), (W, H), interpolation=cv2.INTER_LINEAR)
    out = bg.astype(np.float32) * 0.32
    ah, aw = app.shape[:2]
    sc = 1 + (APP_H / ah - 1) * e
    cx = W / 2 + (APP_CX - W / 2) * e
    cy = (ah / 2 - 90) + (APP_TOP + APP_H / 2 - (ah / 2 - 90)) * e      # starts where the full-screen crop left it
    w, h = round(aw * sc), round(ah * sc)
    x0, y0 = round(cx - w / 2), round(cy - h / 2)
    scr = cv2.resize(app, (w, h), interpolation=cv2.INTER_AREA)
    r = round(w * 0.135)
    bez = round(14 * e)
    if bez:
        # glow, then the black frame with a faint rim, then the screen inside it
        glow = np.zeros((H, W), np.float32)
        cv2.rectangle(glow, (x0 - bez, y0 - bez), (x0 + w + bez, y0 + h + bez), 1.0, 6)
        out += (cv2.GaussianBlur(glow, (0, 0), 20) * 0.85 * e)[..., None] * np.float32(CYAN[::-1])
        fw, fh = w + 2 * bez, h + 2 * bez
        frame = np.full((fh, fw, 3), 12, np.uint8)
        rim = rounded_mask(fw, fh, r + bez)
        inner = rounded_mask(fw - 4, fh - 4, r + bez - 2)
        frame[rim > 0] = (70, 72, 78)
        frame[2:-2, 2:-2][inner > 0] = (12, 12, 14)
        paste(out, frame, rim, x0 - bez, y0 - bez)
    paste(out, scr, rounded_mask(w, h, r), x0, y0)
    return np.clip(out, 0, 255).astype(np.uint8)


# ---------- the phone composite ----------

def composite(frame, q, app, rng):
    """frame: clip frame at native size; q: its screen corners; app: 1080-wide app frame.
    Returns the 1080×1920 frame with the app on the phone, and the corners at that size."""
    big, s, ox, oy = cover(frame)
    m = cv2.resize(G.matte(frame), (round(frame.shape[1] * s), round(frame.shape[0] * s)),
                   interpolation=cv2.INTER_CUBIC)
    m = np.clip(m[oy:oy + H, ox:ox + W], 0, 1)
    qq = (q * s - [ox, oy]).astype(np.float32)
    h, w = app.shape[:2]
    Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [w, 0], [w, h], [0, h]]), qq)
    scr = cv2.warpPerspective(app, Hm, (W, H), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE).astype(np.float32)
    # match the footage: slight softness, a lit screen at night, glass, fine grain
    scr = cv2.GaussianBlur(scr, (0, 0), 0.6)
    scr = scr * 0.9 + 8
    gx = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    gy = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    scr += (np.clip(1 - np.abs((gx - gy * 0.55) - 0.2) * 3.2, 0, 1) * 12)[..., None]
    scr += rng.normal(0, 2.0, scr.shape[:2]).astype(np.float32)[..., None]
    fg = big.astype(np.float32)
    near = cv2.dilate((m > 0.02).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
    cap = np.maximum(fg[..., 0], fg[..., 2]) + 6
    fg[..., 1] = np.where(near, np.minimum(fg[..., 1], cap), fg[..., 1])      # despill thumb and bezel
    m = cv2.GaussianBlur(m, (0, 0), 0.7)[..., None]
    return np.clip(scr * m + fg * (1 - m), 0, 255).astype(np.uint8), qq


def zoom(frame, qq, e):
    """Push into the phone screen; e 0→1."""
    c = qq.mean(0)
    height = (np.linalg.norm(qq[3] - qq[0]) + np.linalg.norm(qq[2] - qq[1])) / 2
    z = 1 + (H * 1.05 / height - 1) * e
    left = qq[3] - qq[0]
    theta = np.arctan2(left[0], left[1]) * e            # straighten the phone's tilt on the way in
    to = c + (np.array([W / 2, H / 2]) - c) * e         # the screen's centre travels to the frame's centre
    cs, sn = np.cos(theta) * z, np.sin(theta) * z
    A = np.float32([[cs, -sn], [sn, cs]])
    M = np.hstack([A, (to - A @ c)[:, None]]).astype(np.float32)
    return cv2.warpAffine(frame, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


# ---------- text (drawn on a transparent layer, so it can also go to Final Cut on its own) ----------

def font(size, weight):
    f = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', size)
    f.set_variation_by_name(weight)
    return f


CAP_FONT = font(84, 'Heavy')
SMALL_FONT = font(36, 'Semibold')


def caption(layer, words, cyan, shown, pop, y=CAPTION_Y, band=False):
    """Word-by-word caption: white heavy type, thick black outline, cyan words.
    Laid out for all words (nothing shifts) but only the first `shown` are drawn;
    the newest pops in. `band`: a soft dark band behind it, for busy app screens."""
    size = 84
    width = sum(CAP_FONT.getlength(w) for w in words) + CAP_FONT.getlength(' ') * (len(words) - 1)
    if width > 840:
        size = int(84 * 840 / width)
    f0 = font(size, 'Heavy') if size != 84 else CAP_FONT
    space = f0.getlength(' ')
    width = sum(f0.getlength(w) for w in words) + space * (len(words) - 1)
    if band:
        m = Image.new('L', layer.size, 0)
        # full width, feathered top and bottom: hides the app's own text behind the words
        ImageDraw.Draw(m).rectangle([-100, y - 95, W + 100, y + 95], fill=215)
        m = m.filter(ImageFilter.GaussianBlur(34))
        layer.alpha_composite(Image.merge('RGBA', (*[Image.new('L', layer.size, 0)] * 3, m)))
    d = ImageDraw.Draw(layer)
    x = SAFE_CX - width / 2
    for i, w in enumerate(words[:shown]):
        f = f0
        if i == shown - 1 and pop < 1:
            f = font(round(size * (0.86 + 0.14 * pop)), 'Heavy')
        d.text((x + f0.getlength(w) / 2, y), w, font=f, anchor='mm',
               fill=CYAN if cyan[i] else 'white', stroke_width=9, stroke_fill='black')
        x += f0.getlength(w) + space


CARD_FONT = font(92, 'Heavy')


def glow_box(layer, box, radius, fill, border, glow, a=1.0):
    """A rounded card like the app's own: dark glass, a thin coloured edge and a soft glow."""
    x0, y0, x1, y1 = box
    g = Image.new('L', layer.size, 0)
    ImageDraw.Draw(g).rounded_rectangle(box, radius, outline=255, width=10)
    g = g.filter(ImageFilter.GaussianBlur(22)).point(lambda v: int(v * 0.9 * a))
    layer.alpha_composite(Image.merge('RGBA', (*[Image.new('L', layer.size, c) for c in glow], g)))
    card = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle(box, radius, fill=fill[:3] + (int(fill[3] * a),))
    if border:
        d.rounded_rectangle(box, radius, outline=border + (int(255 * a),), width=4)
    layer.alpha_composite(card)


def card(layer, words, cyan, shown, age, y=CAPTION_Y):
    """App shots: the caption on a dark glass card with a cyan glow; the card
    slides up and fades in, then the words type in."""
    space = CARD_FONT.getlength(' ')
    width = sum(CARD_FONT.getlength(w) for w in words) + space * (len(words) - 1)
    f0, size = CARD_FONT, 92
    if width > 780:
        size = int(92 * 780 / width)
        f0 = font(size, 'Heavy')
        space = f0.getlength(' ')
        width = sum(f0.getlength(w) for w in words) + space * (len(words) - 1)
    e = min(1, age / 0.18)
    e = 1 - (1 - e) ** 3                           # ease out
    y = y + (1 - e) * 40
    glow_box(layer, [SAFE_CX - width / 2 - 48, y - size * 0.78, SAFE_CX + width / 2 + 48, y + size * 0.78], 38,
             (8, 12, 22, 235), CYAN, CYAN, e)
    d = ImageDraw.Draw(layer)
    x = SAFE_CX - width / 2
    for i, w in enumerate(words[:shown]):
        d.text((x + f0.getlength(w) / 2, y), w, font=f0, anchor='mm', fill=CYAN if cyan[i] else 'white')
        x += f0.getlength(w) + space


def end_card(layer, t, small):
    """The last shot: 'Team Radio' big, then a cyan App Store button, then the small line."""
    big = font(128, 'Heavy')
    e1 = 1 - (1 - min(1, t / 0.25)) ** 3
    if t > 0:
        d = ImageDraw.Draw(layer)
        glow = Image.new('L', layer.size, 0)
        ImageDraw.Draw(glow).text((SAFE_CX, 840), 'Team Radio', font=big, anchor='mm', fill=255)
        glow = glow.filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.8 * e1))
        layer.alpha_composite(Image.merge('RGBA', (*[Image.new('L', layer.size, c) for c in CYAN], glow)))
        d.text((SAFE_CX, 840 + (1 - e1) * 30), 'Team Radio', font=big, anchor='mm',
               fill=(255, 255, 255, int(255 * e1)))
    t2 = t - 0.45
    if t2 > 0:
        e2 = 1 - (1 - min(1, t2 / 0.2)) ** 3
        bf = font(62, 'Heavy')
        label = 'Free on the App Store'
        w = bf.getlength(label)
        sc = 0.9 + 0.1 * e2
        hw, hh = (w / 2 + 52) * sc, 58 * sc
        glow_box(layer, [SAFE_CX - hw, 1010 - hh, SAFE_CX + hw, 1010 + hh], int(hh), CYAN + (255,), None, CYAN, e2)
        ImageDraw.Draw(layer).text((SAFE_CX, 1010), label, font=font(round(62 * sc), 'Heavy'), anchor='mm',
                                   fill=(6, 10, 18, int(255 * e2)))
    if t > 0.9:
        small_line(layer, small, 1115)


def small_line(layer, text, y):
    ImageDraw.Draw(layer).text((SAFE_CX, y), text, font=SMALL_FONT, anchor='mm', fill='white',
                               stroke_width=5, stroke_fill='black')


def app_text(spec, dur, beats):
    """'Pin the *countdown* | to your *Lock Screen*' → caption groups; each group lands on a beat."""
    groups = [g.split() for g in spec.split('|')]
    step = (dur - 0.3) / len(groups)
    out = []
    for gi, g in enumerate(groups):
        want = 0.12 + gi * step
        start = min(beats, key=lambda b: abs(b - want)) if beats else want
        out.append([(w.replace('*', ''), '*' in w, start + i * 0.14) for i, w in enumerate(g)])
    return out


def chunks(words):
    """Spoken words → caption groups of up to 3, breaking after punctuation."""
    out, cur = [], []
    for w in words:
        cur.append(w)
        if len(cur) == 3 or w[0][-1] in '.,…?!':
            out.append(cur)
            cur = []
    return out + ([cur] if cur else [])


def blend(frame, layer):
    a = np.asarray(layer, dtype=np.float32)
    rgb, al = a[..., 2::-1], a[..., 3:] / 255      # RGBA → BGR + alpha
    return (frame.astype(np.float32) * (1 - al) + rgb * al).astype(np.uint8)


# ---------- timing ----------

def beat_grid(path):
    """Beat times of the song (spectral-flux onsets, tempo by autocorrelation)."""
    sr, hop, n = 22050, 512, 2048
    x = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(sr),
                                      '-f', 'f32le', '-'], capture_output=True).stdout, np.float32)
    S = np.log1p(np.abs(np.fft.rfft(np.lib.stride_tricks.sliding_window_view(x, n)[::hop] * np.hanning(n), axis=1)))
    flux = np.maximum(0, np.diff(S, axis=0)).sum(1)
    flux = (flux - flux.mean()) / flux.std()
    fps = sr / hop
    ac = np.correlate(flux, flux, 'full')[len(flux) - 1:]
    bpm = max((ac[int(round(60 / b * fps))], b) for b in np.arange(70, 181, 0.5))[1]
    period = 60 / bpm * fps
    phase = max(range(int(period)), key=lambda o: flux[np.arange(o, len(flux), period).astype(int)].sum())
    return np.arange(phase, len(flux), period) / fps, 60 / bpm


def fit_to_beats(v, song_beats, beat):
    """Nudges each shot's length so every cut lands on a half beat, with the video
    ending where the song ends. Talking shots grow or shrink at their tail (never
    cutting a word); app shots at their end."""
    shots = [dict(s) for s in v['shots']]
    lens = [(s['t'][1] - s['t'][0]) if 'clip' in s else (s['app'][1] - s['app'][0]) for s in shots]
    total = sum(lens)
    start = v['music_end'] - total
    half = beat / 2
    grid = np.concatenate([song_beats, song_beats + half]) - start
    t = 0.0
    for i, s in enumerate(shots[:-1]):
        want = t + lens[i]
        cut = min(grid, key=lambda g: abs(g - want) if g > t + 0.8 else 1e9)
        d = cut - want
        if 'clip' in s:
            t0, t1 = s['t']
            full = clip_len(os.path.join(AI, s['clip']))
            if t1 + d > full - 0.02:              # no footage left: start earlier instead
                s['t'] = (t0 - (t1 + d - (full - 0.02)), full - 0.02)
            else:
                s['t'] = (t0, t1 + d)
        else:
            s['app'] = (s['app'][0], s['app'][1] + d)
        t = cut
    last = shots[-1]
    rest = total - t
    if 'app' in last and 'clip' not in last:
        last['app'] = (last['app'][0], last['app'][0] + rest)
    return shots, start


# ---------- main ----------

def main(name, fcp=False):
    v = EMILY[name]
    raw = sorted(p for p in (os.path.join(R.RAW, f) for f in os.listdir(R.RAW))
                 if p.endswith('.mov') and os.path.exists(p[:-4] + '.json'))[-1]
    offset = json.load(open(raw[:-4] + '.json'))['offset']
    words_all = json.load(open(os.path.join(AI, 'words.json')))
    song = sorted((os.path.join(R.MUSIC, f) for f in os.listdir(R.MUSIC)
                   if f.lower().endswith(('.mp3', '.wav', '.m4a'))), key=os.path.getmtime)[-1]
    song_beats, beat = beat_grid(song)
    shots, music_start = fit_to_beats(v, song_beats, beat)
    print(f'♪ {os.path.basename(song)}  {60 / beat:.1f} bpm, from {music_start:.2f}s')

    tmp = tempfile.mkdtemp(prefix='teamradio-emily-')
    outdir = os.path.join(R.OUT, name + '-fcp') if fcp else None
    if outdir:
        os.makedirs(outdir, exist_ok=True)

    def encoder(path, alpha=False):
        # Final Cut files stay small: HEVC with alpha for the captions, high-quality H.264 for the shots
        codec = (['-c:v', 'hevc_videotoolbox', '-alpha_quality', '0.9', '-q:v', '70', '-tag:v', 'hvc1'] if alpha else
                 ['-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p'])
        return subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'bgra' if alpha else 'bgr24',
                                 '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', *codec, path], stdin=subprocess.PIPE)

    video = os.path.join(tmp, 'video.mp4')
    enc = encoder(video)
    enc_text = encoder(os.path.join(outdir, 'captions.mov'), alpha=True) if outdir else None
    rng = np.random.default_rng(7)
    audio, t_out, cuts, talk, pieces, titles = [], 0.0, [], [], [], []

    for si, shot in enumerate(shots):
        enc_shot = encoder(os.path.join(outdir, f'{si + 1:02d}.mov')) if outdir else None
        in_beats = lambda a, b: [x - t_out for x in np.concatenate([song_beats, song_beats + beat / 2]) - music_start
                                 if t_out + a <= x <= t_out + b]
        if 'clip' in shot:
            t0, t1 = shot['t']
            src = os.path.join(AI, shot['clip'])
            frames, sfps, first = clip_frames(src, t0, t1)
            n = round((t1 - t0) * FPS)
            words = []
            for w, a, b in words_all[shot['clip']]:
                w = v['spelling'].get(w, w)
                if w and a < t1 - 0.05 and b > t0 + 0.05:
                    words.append((w, max(a, t0), b))
            groups = chunks(words)
            if 'app' in shot:
                qs = G.track(frames)
                app = app_frames(raw, offset, shot['app'], shot['app'] + (t1 - t0))
            z0 = t1 - shot.get('zoom', 0)
            for gi, g in enumerate(groups):
                end = min(groups[gi + 1][0][1] if gi + 1 < len(groups) else t1, g[-1][2] + 0.6, z0 if 'zoom' in shot else t1)
                titles.append({'start': t_out + g[0][1] - t0, 'end': t_out + end - t0,
                               'words': [(w[0], False) for w in g], 'y': shot.get('cap_y', CAPTION_Y)})
            for k in range(n):
                t = t0 + k / FPS
                fi = min(len(frames) - 1, max(0, int(round(t * sfps)) - first))
                if 'app' in shot:
                    f, qq = composite(frames[fi], qs[fi], app[min(k, len(app) - 1)], rng)
                    if 'zoom' in shot and t > z0:
                        e = ((t - z0) / shot['zoom']) ** 2.2          # ease in: the push accelerates
                        f = np.mean([zoom(f, qq, min(1, e * s)) for s in (0.94, 1.0, 1.06)], 0).astype(np.uint8)
                else:
                    f = sharpen(cover(frames[fi])[0])
                    z = 1.0
                    for at, zz in shot.get('punch', []):
                        if t >= at:
                            z = zz
                    f = punch(f, z)
                layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                g = next((g for gi, g in enumerate(groups)
                          if g[0][1] <= t and (gi + 1 == len(groups) or groups[gi + 1][0][1] > t)), None)
                if g and t < g[-1][2] + 0.6 and not ('zoom' in shot and t > z0):
                    act = max(i for i, w in enumerate(g) if w[1] <= t)
                    caption(layer, [w[0] for w in g], [i == act for i in range(len(g))], len(g),
                            min(1, (t - g[act][1]) / 0.08), shot.get('cap_y', CAPTION_Y))
                enc.stdin.write(blend(f, layer).tobytes())
                if outdir:
                    enc_shot.stdin.write(f.tobytes())
                    enc_text.stdin.write(np.asarray(layer)[..., [2, 1, 0, 3]].tobytes())
            audio.append(('clip', src, t0, t0 + n / FPS))
            talk.append((t_out, t_out + n / FPS))
        else:
            a0, a1 = shot['app']
            frames = app_frames(raw, offset, a0, a1)
            n = round((a1 - a0) * FPS)
            groups = app_text(shot['text'], a1 - a0, in_beats(0.05, a1 - a0 - 0.4))
            if shot.get('end'):
                s0 = t_out + groups[0][0][2]
                titles += [{'start': s0, 'end': t_out + a1 - a0, 'words': [('Team Radio', False)], 'y': 840, 'size': 128},
                           {'start': s0 + 0.45, 'end': t_out + a1 - a0, 'words': [('Free on the App Store', True)],
                            'y': 1010, 'size': 62},
                           {'start': s0 + 0.9, 'end': t_out + a1 - a0, 'words': [(shot['small'], False)], 'y': 1115,
                            'size': 36}]
            else:
                for gi, g in enumerate(groups):
                    end = a1 - a0 if gi + 1 == len(groups) else groups[gi + 1][0][2]
                    titles.append({'start': t_out + g[0][2], 'end': t_out + end, 'words': [(w[0], w[1]) for w in g],
                                   'y': CARD_Y, 'size': 92})
            for k in range(n):
                t = k / FPS
                if shot.get('end'):
                    f = full_screen(frames[min(k, len(frames) - 1)])
                else:
                    after_zoom = si and 'zoom' in shots[si - 1]
                    e = 1 - (1 - min(1, t / 0.4)) ** 3 if after_zoom else 1
                    f = app_layout(frames[min(k, len(frames) - 1)], e)
                if shot.get('end'):
                    f = (f.astype(np.float32) * max(0.3, 1 - k / 12 * 0.7)).astype(np.uint8)
                layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                live = [g for g in groups if g[0][2] <= t]
                if shot.get('end'):
                    end_card(layer, t - groups[0][0][2], shot['small'])
                elif live:
                    g = live[-1]
                    shown = sum(1 for w in g if w[2] <= t)
                    card(layer, [w[0] for w in g], [w[1] for w in g], shown, t - g[0][2], CARD_Y)
                enc.stdin.write(blend(f, layer).tobytes())
                if outdir:
                    enc_shot.stdin.write(f.tobytes())
                    enc_text.stdin.write(np.asarray(layer)[..., [2, 1, 0, 3]].tobytes())
            audio.append(('silence', None, a0, a0 + n / FPS))
        dur = n / FPS
        if enc_shot:
            enc_shot.stdin.close()
            enc_shot.wait()
        pieces.append((si + 1, t_out, dur, audio[-1]))
        cuts.append((t_out, 'zoom' if si and 'zoom' in shots[si - 1] else 'cut'))
        t_out += dur
        print(f'✓ shot {si + 1} ({dur:.2f}s, ends {t_out:.2f}s)')
    for e in [enc] + ([enc_text] if enc_text else []):
        e.stdin.close()
        e.wait()

    # ---- sound: each clip's own sound; music from music_start ducking under her voice;
    # a key click on cuts, a whoosh into the phone
    args, chains = ['ffmpeg', '-v', 'error', '-y', '-i', video], []
    k = 1
    for i, (kind, src, a, b) in enumerate(audio):
        if kind == 'clip':
            args += ['-ss', f'{a:.3f}', '-t', f'{b - a:.3f}', '-i', src]
        else:
            args += ['-f', 'lavfi', '-t', f'{b - a:.3f}', '-i', 'anullsrc=r=48000:cl=stereo']
        chains.append(f'[{k}:a]aresample=48000,aformat=channel_layouts=stereo,apad=whole_dur={b - a:.3f},'
                      f'atrim=0:{b - a:.3f},afade=t=in:d=0.02,afade=t=out:st={b - a - 0.03:.3f}:d=0.03[p{i}]')
        k += 1
    chains.append(''.join(f'[p{i}]' for i in range(len(audio))) + f'concat=n={len(audio)}:v=0:a=1,asplit=2[voice][key]')
    fx = []
    for j, (at, kind) in enumerate(cuts[1:]):
        if kind == 'zoom':
            args += ['-f', 'lavfi', '-t', '0.6', '-i', 'anoisesrc=color=pink:amplitude=0.5:r=48000']
            st = max(0, at - 0.5)
            chains.append(f'[{k}:a]aformat=channel_layouts=stereo,highpass=f=300,lowpass=f=5000,'
                          f"volume='0.8*pow(t/0.5,2)*if(lt(t,0.5),1,max(0,1-(t-0.5)*10))':eval=frame,"
                          f'adelay={int(st * 1000)}|{int(st * 1000)}[x{j}]')
        else:
            args += ['-i', os.path.join(R.SOUNDS, 'radio-key.caf')]
            chains.append(f'[{k}:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.6,'
                          f'adelay={int(at * 1000)}|{int(at * 1000)}[x{j}]')
        fx.append(f'[x{j}]')
        k += 1
    args += ['-ss', f'{music_start:.3f}', '-t', f'{t_out:.3f}', '-i', song]
    chains.append(f'[{k}:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.85,afade=t=in:d=0.15[mus]')
    chains.append('[mus][key]sidechaincompress=threshold=0.02:ratio=8:attack=15:release=350:makeup=1[duck]')
    chains.append('[voice][duck]' + ''.join(fx) + f'amix=inputs={2 + len(fx)}:duration=first:normalize=0,'
                  'loudnorm=I=-14:TP=-1.5:LRA=11[aud]')
    out = os.path.join(R.OUT, name + '.mp4')
    subprocess.run(args + ['-filter_complex', ';'.join(chains), '-map', '0:v', '-map', '[aud]', '-c:v', 'copy',
                           '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', out], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print('✓', out, f'({t_out:.1f}s)')

    if outdir:
        import fcpxml
        path = fcpxml.write(outdir, name, pieces, song, music_start, t_out, titles, (SAFE_CX, W, H))
        print('✓', path)


if __name__ == '__main__':
    main(sys.argv[1], '--fcp' in sys.argv)
