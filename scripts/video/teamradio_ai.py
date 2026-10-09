#!/usr/bin/env python3
""""TEAM RADIO" short: Emily on the radio announces the AI Strategist's pick,
the picks slam in over the app, a quick look at the app, then a comment
prompt and the App Store search line. Built for TikTok's first test batch:
keyword in the first second, ~14 s so people finish it, a question that
invites comments, and an ending that crackles back into the start (loop).

    scripts/video/teamradio_ai.py singapore-ai

Inputs: an Emily clip made in Google Flow (Marketing/videos/ai), its word
timings (Whisper JSON next to it, <clip>.words.json) and a Simulator demo
recording (scripts/video/capture.sh). Output: Marketing/videos/out/<name>.mp4
"""
import json, os, random, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R

W, H, FPS = R.W, R.H, R.FPS
AI = os.path.join(R.ROOT, 'Marketing/videos/ai')
CYAN = (64, 214, 255)
CX = 500                     # safe-zone centre, clear of TikTok's right-hand buttons
TEAM = {'mercedes': (0, 209, 191), 'ferrari': (232, 13, 13), 'mclaren': (255, 135, 0),
        'red_bull': (36, 31, 153), 'rb': (107, 145, 255)}

VIDEOS = {
    'singapore-ai': {
        'clip': 'clip_singapore_ai.mp4', 'clip_from': 0.40,
        'raw': 'countdown-2026-10-09.mov', 'app_from': 28.2,
        'race': 'SINGAPORE GP',
        'phrases': ['Radio check.', 'Our AI just predicted Singapore.', 'Antonelli to win.', 'Think you can beat it?'],
        'picks': [('POLE', 'ANT', 'mercedes'), ('WINNER', 'ANT', 'mercedes'), ('P2', 'RUS', 'mercedes'),
                  ('P3', 'HAM', 'ferrari'), ('FASTEST LAP', 'RUS', 'mercedes')],
        'cta': ('YOUR PODIUM?', 'Comment it below. Results Sunday.',
                'Beat the AI: prediction game coming for Austin', 'Search "teamradio" on the App Store'),
    },
}

# timeline (seconds)
INTRO, EMILY, PICKS, APP, END = 0.0, 0.7, 7.7, 10.5, 12.1
TOTAL = 14.2


def decode(path, start, dur, vf):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-t', str(dur), '-i', path,
           '-vf', f'{vf},fps={FPS},format=rgb24', '-f', 'rawvideo', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)


def tf(size, weight='Heavy'):
    return R.font(size, weight)


def glow_text(layer, xy, text, f, fill, glow=None, anchor='mm', strength=0.8, blur=22):
    if glow:
        g = Image.new('L', layer.size, 0)
        ImageDraw.Draw(g).text(xy, text, font=f, anchor=anchor, fill=255)
        g = g.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * strength))
        layer.alpha_composite(Image.merge('RGBA', (*[Image.new('L', layer.size, c) for c in glow], g)))
    ImageDraw.Draw(layer).text(xy, text, font=f, anchor=anchor, fill=fill, stroke_width=3, stroke_fill=(0, 0, 0, 160))


def waveform(layer, x, y, w, h, t, level=1.0, color=CYAN):
    d = ImageDraw.Draw(layer)
    n = 22
    rnd = random.Random(int(t * 30))
    for i in range(n):
        a = (0.25 + 0.75 * abs(np.sin(t * 9 + i * 0.7)) * rnd.uniform(0.5, 1.0)) * level
        bh = max(4, h * a)
        bx = x + i * (w / n)
        d.rounded_rectangle([bx, y - bh / 2, bx + w / n * 0.55, y + bh / 2], 3, fill=color + (230,))


def static(frame, amount):
    """Radio crackle: noise, scanlines and a cyan flash."""
    noise = np.random.randint(0, 255, (H // 4, W // 4, 1), np.uint8).repeat(3, 2)
    noise = np.array(Image.fromarray(noise).resize((W, H), Image.NEAREST), np.float32)
    out = frame.astype(np.float32) * (1 - amount) + noise * amount * 0.7 + np.array(CYAN) * amount * 0.25
    out[::6] *= 0.75
    return out.clip(0, 255).astype(np.uint8)


def darken(frame, k, blur=0):
    im = Image.fromarray(frame)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return (np.asarray(im).astype(np.float32) * k).astype(np.uint8)


def tag_pill(layer, race, t):
    """Top-left radio tag: keyword visible from the first second (TikTok search)."""
    f = tf(40)
    label = f'TEAM RADIO  ·  {race}'
    w = f.getlength(label)
    x0, y0 = CX - w / 2 - 70, 300
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([x0, y0, x0 + w + 120, y0 + 78], 39, fill=(6, 10, 18, 220), outline=CYAN + (255,), width=3)
    d.ellipse([x0 + 26, y0 + 27, x0 + 50, y0 + 51], fill=(253, 75, 40, 255 if int(t * 2) % 2 == 0 else 120))
    d.text((x0 + 70, y0 + 39), label, font=f, anchor='lm', fill='white')


def radio_caption(layer, phrases, words, t, speaking):
    """Broadcast-style team-radio box: speaker line, waveform, the current
    phrase appearing word by word."""
    y = 1150
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([60, y, 940, y + 250], 28, fill=(6, 10, 18, 210), outline=(64, 214, 255, 160), width=3)
    d.text((100, y + 46), 'EMILY  ·  RACE ENGINEER', font=tf(34, 'Bold'), anchor='lm', fill=CYAN)
    waveform(layer, 640, y + 46, 260, 44, t, 1.0 if speaking else 0.25)
    # which phrase are we in, and how many of its words are out
    said = [w for w in words if w[1] <= t]
    if not said:
        return
    idx, count = 0, 0
    for p_i, p in enumerate(phrases):
        n = len(p.split())
        if len(said) <= count + n:
            idx = p_i
            break
        count += n
    else:
        idx = len(phrases) - 1
        count = sum(len(p.split()) for p in phrases[:-1])
    shown = phrases[idx].split()[:len(said) - count]
    text = ' '.join(shown)
    f = tf(64)
    lines, line = [], ''
    for wd in text.split():
        trial = (line + ' ' + wd).strip()
        if f.getlength(trial) > 800 and line:
            lines.append(line); line = wd
        else:
            line = trial
    lines.append(line)
    for k, ln in enumerate(lines[-2:]):
        hot = any(x in ln for x in ('Antonelli', 'AI', 'Singapore'))
        d.text((100, y + 120 + k * 78), ln, font=f, anchor='lm', fill='white')
        if hot:
            # colour the keyword inside the line
            x = 100
            for wd in ln.split():
                ww = f.getlength(wd + ' ')
                if wd.strip('.?,') in ('Antonelli', 'AI', 'Singapore'):
                    d.text((x, y + 120 + k * 78), wd, font=f, anchor='lm', fill=CYAN)
                x += ww


def picks_card(layer, picks, t):
    d = ImageDraw.Draw(layer)
    glow_text(layer, (CX, 420), "THE AI'S PICKS", tf(96), 'white', CYAN, strength=0.7)
    d.text((CX, 505), 'AI Strategist · Singapore GP', font=tf(38, 'Bold'), anchor='mm', fill=(190, 196, 210))
    for i, (label, code, team) in enumerate(picks):
        ti = t - 0.2 - i * 0.32
        if ti < 0:
            continue
        e = 1 - (1 - min(1, ti / 0.18)) ** 3
        y = 610 + i * 150
        x0 = 90 + (1 - e) * 120
        a = int(255 * e)
        d.rounded_rectangle([x0, y, x0 + 820, y + 126], 26, fill=(14, 18, 28, int(230 * e)),
                            outline=CYAN + (int(110 * e),), width=2)
        d.rounded_rectangle([x0 + 28, y + 28, x0 + 40, y + 98], 6, fill=TEAM[team] + (a,))
        d.text((x0 + 70, y + 63), label, font=tf(40, 'Bold'), anchor='lm', fill=(170, 178, 196, a))
        d.text((x0 + 790, y + 63), code, font=tf(76), anchor='rm', fill=(255, 255, 255, a))


def fade_bottom(frame, start=1320, end=1600):
    ramp = np.clip((np.arange(H) - start) / (end - start), 0, 1)[:, None, None]
    return (frame.astype(np.float32) * (1 - ramp)).astype(np.uint8)


def app_caption(layer):
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([90, 1330, 910, 1480], 30, fill=(6, 10, 18, 215))
    d.text((CX, 1380), 'Free app: Team Radio', font=tf(56), anchor='mm', fill='white')
    d.text((CX, 1440), 'Live countdowns · results · fan chat', font=tf(36, 'Bold'), anchor='mm', fill=CYAN)


def end_card(layer, cta, t):
    big, sub, game, search = cta
    e = lambda d0, dur=0.22: 1 - (1 - max(0, min(1, (t - d0) / dur))) ** 3
    glow_text(layer, (CX, 640 + (1 - e(0)) * 40), big, tf(112), (255, 255, 255, int(255 * e(0))), CYAN, strength=0.8 * e(0))
    d = ImageDraw.Draw(layer)
    d.text((CX, 760), sub, font=tf(48, 'Bold'), anchor='mm', fill=(255, 255, 255, int(255 * e(0.25))))
    d.text((CX, 900), game, font=tf(40, 'Bold'), anchor='mm', fill=CYAN + (int(255 * e(0.5)),))
    k = e(0.75)
    f = tf(46)
    w = f.getlength(search)
    d.rounded_rectangle([CX - w / 2 - 44, 1000, CX + w / 2 + 44, 1090], 45, fill=CYAN + (int(255 * k),))
    d.text((CX, 1045), search, font=f, anchor='mm', fill=(6, 10, 18, int(255 * k)))


def main(name):
    v = VIDEOS[name]
    clip = os.path.join(AI, v['clip'])
    words = [(w[0], w[1], w[2]) for w in json.load(open(clip.replace('.mp4', '.words.json')))]
    words = [(w, s - v['clip_from'] + EMILY, e - v['clip_from'] + EMILY) for w, s, e in words]
    cover = f'scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H}'
    emily = decode(clip, v['clip_from'], PICKS - EMILY + 0.1, cover)
    raw = os.path.join(R.RAW, v['raw'])
    # zoomed in on the hero and countdown; the bottom fades out (TikTok's caption area)
    app = decode(raw, v['app_from'], END - PICKS + 0.1, f'scale={int(W * 1.12)}:-2,crop={W}:{H}:{int(W * 0.06)}:200')
    bg = np.asarray(Image.open(os.path.join(AI, 'stills', 'emily-reference.jpg')).convert('RGB').resize((W, H)))

    out = os.path.join(R.OUT, f'{name}.mp4')
    silent = out.replace('.mp4', '-video.mp4')
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18',
                            '-preset', 'medium', silent], stdin=subprocess.PIPE)
    for n in range(int(TOTAL * FPS)):
        t = n / FPS
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        if t < EMILY:
            frame = darken(bg, 0.45, 6)
            glow_text(layer, (CX, 820), 'TEAM RADIO', tf(150), 'white', CYAN)
            glow_text(layer, (CX, 960), v['race'], tf(84), CYAN, CYAN, strength=0.6)
            waveform(layer, CX - 230, 1080, 460, 80, t)
            frame = static(frame, max(0, 0.6 - t * 1.2))
        elif t < PICKS:
            frame = emily[min(len(emily) - 1, int((t - EMILY) * FPS))]
            speaking = any(s - 0.05 <= t <= e + 0.15 for _, s, e in words)
            tag_pill(layer, v['race'], t)
            radio_caption(layer, v['phrases'], words, t, speaking)
            if t < EMILY + 0.15:
                frame = static(frame, 0.4)
        elif t < APP:
            frame = darken(app[min(len(app) - 1, int((t - PICKS) * FPS))], 0.32, 14)
            picks_card(layer, v['picks'], t - PICKS)
        elif t < END:
            frame = fade_bottom(app[min(len(app) - 1, int((t - PICKS) * FPS))])
            app_caption(layer)
        else:
            frame = darken(bg, 0.28, 18)
            end_card(layer, v['cta'], t - END)
            if t > TOTAL - 0.3:   # crackle back into the start: the loop
                frame = static(frame, (t - (TOTAL - 0.3)) / 0.3 * 0.6)
        img = Image.fromarray(frame).convert('RGBA')
        img.alpha_composite(layer)
        enc.stdin.write(np.asarray(img.convert('RGB')).tobytes())
    enc.stdin.close(); enc.wait()

    # sound: crackle in and out, Emily, a key click per pick, the radio call on the end card, a quiet bed
    sfx = os.path.join(R.SOUNDS, 'radio-key.caf')
    call = os.path.join(R.SOUNDS, 'radio-call.caf')
    music = sorted((os.path.join(R.MUSIC, f) for f in os.listdir(R.MUSIC) if f.endswith(('.wav', '.mp3'))),
                   key=os.path.getmtime)[-1]
    clicks = [PICKS + 0.2 + i * 0.32 for i in range(len(v['picks']))]
    inputs = ['-i', silent, '-ss', str(v['clip_from']), '-t', str(PICKS - EMILY), '-i', clip,
              '-i', call, '-i', music]
    inputs += sum((['-i', sfx] for _ in clicks), [])
    filt = [
        'anoisesrc=d=0.6:c=white:a=0.35,bandpass=f=2200:w=1800,afade=t=out:st=0.2:d=0.4[c1]',
        f'anoisesrc=d=0.3:c=white:a=0.35,bandpass=f=2200:w=1800,adelay={int((TOTAL - 0.3) * 1000)}|{int((TOTAL - 0.3) * 1000)}[c2]',
        f'[1:a]adelay={int(EMILY * 1000)}|{int(EMILY * 1000)},volume=2.4[vo]',
        f'[2:a]adelay={int(END * 1000)}|{int(END * 1000)},volume=0.8[call]',
        f'[3:a]atrim=0:{TOTAL},volume=0.10,afade=t=out:st={TOTAL - 0.6}:d=0.6[bed]',
    ]
    for i, c in enumerate(clicks):
        filt.append(f'[{4 + i}:a]adelay={int(c * 1000)}|{int(c * 1000)},volume=0.7[k{i}]')
    mix = '[c1][c2][vo][call][bed]' + ''.join(f'[k{i}]' for i in range(len(clicks)))
    filt.append(f'{mix}amix=inputs={5 + len(clicks)}:normalize=0,loudnorm=I=-14:TP=-1.5,atrim=0:{TOTAL}[a]')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(filt),
                    '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', out],
                   check=True)
    os.remove(silent)
    print('✓', out)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'singapore-ai')
