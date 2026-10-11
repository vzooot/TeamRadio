#!/usr/bin/env python3
""""TEAM RADIO" short, v2: the start lights come on one by one over the neon
car art and go out, Emily calls the AI Strategist's pick on the radio (punch-in
cuts, the waveform box), the picks slam in one at a time, a beat of the real
app, then a comment prompt and the App Store search line. The last frame
crackles back into the first, so it loops.

One text block per shot, always over a clean dark area: nothing overlaps.

    scripts/video/teamradio_ai.py singapore-ai

Inputs: Emily clip from Google Flow (Marketing/videos/ai) with Whisper word
timings next to it (<clip>.words.json), the art in Marketing/videos/ai/art and a
Simulator recording (scripts/video/capture.sh).
Output: Marketing/videos/out/<name>.mp4 (1080×1920, 30 fps)
"""
import json, os, random, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R

W, H, FPS = R.W, R.H, R.FPS
AI = os.path.join(R.ROOT, 'Marketing/videos/ai')
CYAN = (64, 214, 255)
RED = (253, 75, 40)
CX = 500                     # safe-zone centre, clear of TikTok's right-hand buttons
TEAM = {'mercedes': (0, 209, 191), 'ferrari': (232, 13, 13), 'mclaren': (255, 135, 0),
        'red_bull': (60, 60, 230), 'rb': (107, 145, 255)}
# the five start lights in art/car-vertical.jpg (centre x, y)
LIGHTS = [(230, 114), (350, 119), (468, 126), (580, 132), (689, 137)]

VIDEOS = {
    'singapore-ai': {
        'clip': 'clip_singapore_ai.mp4', 'clip_span': (0.45, 7.15),
        'punch': [(1.85, 1.12), (4.25, 1.28), (5.80, 1.08)],     # clip second → zoom
        'raw': 'countdown-2026-10-09.mov', 'app_from': 28.2,
        'hook': ('OUR AI CALLED', 'THE SINGAPORE GP'),
        'phrases': ['Radio check.', 'Our AI just predicted Singapore.', 'Antonelli to win.', 'Think you can beat it?'],
        'picks': [('POLE', 'ANTONELLI', 'mercedes'), ('WINNER', 'ANTONELLI', 'mercedes'),
                  ('P2', 'RUSSELL', 'mercedes'), ('P3', 'HAMILTON', 'ferrari'),
                  ('FASTEST LAP', 'RUSSELL', 'mercedes')],
        'end': ('YOUR PODIUM?', 'Comment it below. Results after the race.',
                'Prediction game coming for Austin', 'Search "teamradio" on the App Store'),
    },
}

HOOK, EMILY = 0.0, 1.35          # lights on at 0.15 + 0.2 s each, out at 1.15
PICK_LEN = 0.52
APP_LEN, END_LEN = 1.2, 2.0


def decode(path, start, dur, vf):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-t', str(dur), '-i', path,
           '-vf', f'{vf},fps={FPS},format=rgb24', '-f', 'rawvideo', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)


def tf(size, weight='Heavy'):
    return R.font(size, weight)


def ease(x):
    x = max(0.0, min(1.0, x))
    return 1 - (1 - x) ** 3


def glow_text(layer, xy, text, f, fill, glow=None, strength=0.8, blur=22, anchor='mm'):
    if glow:
        g = Image.new('L', layer.size, 0)
        ImageDraw.Draw(g).text(xy, text, font=f, anchor=anchor, fill=255)
        g = g.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * strength))
        layer.alpha_composite(Image.merge('RGBA', (*[Image.new('L', layer.size, c) for c in glow], g)))
    ImageDraw.Draw(layer).text(xy, text, font=f, anchor=anchor, fill=fill)


def zoom(frame, z, cy=0.42):
    """Punch-in around a point (default: the face / upper third)."""
    if z <= 1.001:
        return frame
    im = Image.fromarray(frame)
    w, h = int(W / z), int(H / z)
    x0, y0 = (W - w) // 2, int(H * cy - h * cy)
    return np.asarray(im.crop((x0, y0, x0 + w, y0 + h)).resize((W, H), Image.LANCZOS))


def dark(frame, k):
    return (frame.astype(np.float32) * k).astype(np.uint8)


def static(frame, amount):
    """Radio crackle: coarse noise, scanlines, a cyan tint."""
    if amount <= 0:
        return frame
    noise = np.random.randint(0, 255, (H // 4, W // 4, 1), np.uint8).repeat(3, 2)
    noise = np.array(Image.fromarray(noise).resize((W, H), Image.NEAREST), np.float32)
    out = frame.astype(np.float32) * (1 - amount) + noise * amount * 0.7 + np.array(CYAN) * amount * 0.25
    out[::6] *= 0.75
    return out.clip(0, 255).astype(np.uint8)


def flash(frame, amount):
    if amount <= 0:
        return frame
    return (frame.astype(np.float32) * (1 - amount) + 255 * amount).astype(np.uint8)


def bottom_shade(frame, start=0.48):
    """Darken the lower part of the art so text sits on a calm area."""
    ramp = np.clip((np.arange(H) / H - start) / 0.18, 0, 1)[:, None, None] * 0.6
    return (frame.astype(np.float32) * (1 - ramp)).astype(np.uint8)


def lights(frame, lit):
    """Start lights: `lit` of 5 on, the rest dark (painted over the art)."""
    im = Image.fromarray(frame).convert('RGBA')
    over = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for i, (x, y) in enumerate(LIGHTS):
        if i >= lit:
            d.ellipse([x - 38, y - 38, x + 38, y + 38], fill=(14, 10, 12, 255))
            d.ellipse([x - 30, y - 30, x + 30, y + 30], fill=(40, 22, 22, 255))
    if lit:
        glow = Image.new('L', im.size, 0)
        gd = ImageDraw.Draw(glow)
        for x, y in LIGHTS[:lit]:
            gd.ellipse([x - 70, y - 70, x + 70, y + 70], fill=150)
        glow = glow.filter(ImageFilter.GaussianBlur(30))
        im.alpha_composite(Image.merge('RGBA', (*[Image.new('L', im.size, c) for c in RED], glow)))
    im.alpha_composite(over)
    return np.asarray(im.convert('RGB'))


def waveform(layer, x, y, w, h, t, level=1.0):
    d = ImageDraw.Draw(layer)
    n = 22
    rnd = random.Random(int(t * 30))
    for i in range(n):
        a = (0.25 + 0.75 * abs(np.sin(t * 9 + i * 0.7)) * rnd.uniform(0.5, 1.0)) * level
        bh = max(4, h * a)
        bx = x + i * (w / n)
        d.rounded_rectangle([bx, y - bh / 2, bx + w / n * 0.55, y + bh / 2], 3, fill=CYAN + (230,))


def radio_box(layer, phrase, t, speaking, y=1300):
    """The team-radio box: speaker line + live waveform + the current phrase."""
    f = tf(62)
    lines, line = [], ''
    for wd in phrase.split():
        trial = (line + ' ' + wd).strip()
        if f.getlength(trial) > 780 and line:
            lines.append(line); line = wd
        else:
            line = trial
    if line:
        lines.append(line)
    h = 120 + 76 * max(1, len(lines))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([70, y, 930, y + h], 30, fill=(6, 10, 18, 225), outline=CYAN + (170,), width=3)
    d.ellipse([104, y + 36, 126, y + 58], fill=RED + ((255 if int(t * 3) % 2 == 0 else 110),))
    d.text((142, y + 47), 'EMILY · RACE ENGINEER', font=tf(32, 'Bold'), anchor='lm', fill=CYAN)
    waveform(layer, 650, y + 47, 250, 46, t, 1.0 if speaking else 0.2)
    hot = ('AI', 'Singapore', 'Antonelli', 'beat')
    for k, ln in enumerate(lines):
        x, yy = 104, y + 126 + k * 76
        for wd in ln.split():
            d.text((x, yy), wd, font=f, anchor='lm', fill=CYAN if wd.strip('.?,') in hot else 'white')
            x += f.getlength(wd + ' ')


def current_phrase(phrases, words, t):
    said = sum(1 for _, s, _ in words if s <= t)
    count = 0
    for p in phrases:
        n = len(p.split())
        if said <= count + n:
            return ' '.join(p.split()[:max(0, said - count)])
        count += n
    return phrases[-1]


def hook_text(layer, hook, t):
    a, b = hook
    e1, e2 = ease(t / 0.18), ease((t - 0.15) / 0.18)
    s1 = 1.25 - 0.25 * e1
    glow_text(layer, (CX, 1180), a, tf(round(96 * s1)), (255, 255, 255, int(255 * e1)))
    s2 = 1.25 - 0.25 * e2
    glow_text(layer, (CX, 1295), b, tf(round(96 * s2)), CYAN + (int(255 * e2),), CYAN, 0.7 * e2)


def pick_text(layer, label, name, team, t):
    """One pick, full width: 'THE AI SAYS · POLE' then the name slams in."""
    e = ease(t / 0.12)
    s = 1.35 - 0.35 * e
    d = ImageDraw.Draw(layer)
    d.text((CX, 1120), f'THE AI SAYS  ·  {label}', font=tf(46, 'Bold'), anchor='mm', fill=CYAN + (int(255 * e),))
    f = tf(round(132 * s))
    if f.getlength(name) > 880:
        f = tf(round(132 * s * 880 / f.getlength(name)))
    glow_text(layer, (CX, 1270), name, f, (255, 255, 255, int(255 * e)), TEAM[team], 0.9 * e, 28)
    w = 360 * e
    d.rounded_rectangle([CX - w / 2, 1370, CX + w / 2, 1384], 7, fill=TEAM[team] + (255,))


def phone(frame_bg, app, label_alpha):
    """The app in a phone screen over the darkened art."""
    bg = Image.fromarray(dark(frame_bg, 0.35)).convert('RGBA')
    sw, sh = 600, 1300
    scr = Image.fromarray(app).resize((sw, int(sw * H / W))).crop((0, 0, sw, sh))
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], 60, fill=255)
    x0, y0 = CX - sw // 2, 470
    rim = Image.new('RGBA', bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle([x0 - 14, y0 - 14, x0 + sw + 14, y0 + sh + 14], 72,
                                          fill=(10, 12, 18, 255), outline=CYAN + (200,), width=3)
    glow = rim.getchannel('A').filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * 0.5))
    bg.alpha_composite(Image.merge('RGBA', (*[Image.new('L', bg.size, c) for c in CYAN], glow)))
    bg.alpha_composite(rim)
    bg.paste(scr, (x0, y0), mask)
    d = ImageDraw.Draw(bg)
    d.text((CX, 330), 'FREE APP', font=tf(44, 'Bold'), anchor='mm', fill=CYAN + (int(255 * label_alpha),))
    glow_text(bg, (CX, 400), 'TEAM RADIO', tf(84), (255, 255, 255, int(255 * label_alpha)), CYAN, 0.6 * label_alpha)
    return np.asarray(bg.convert('RGB'))


def end_text(layer, end, t):
    big, sub, game, search = end
    d = ImageDraw.Draw(layer)
    e0 = ease(t / 0.2)
    glow_text(layer, (CX, 1130 + (1 - e0) * 30), big, tf(118), (255, 255, 255, int(255 * e0)), CYAN, 0.8 * e0)
    d.text((CX, 1240), sub, font=tf(40, 'Bold'), anchor='mm', fill=(225, 230, 240, int(255 * ease((t - 0.2) / 0.2))))
    d.text((CX, 1330), game, font=tf(40, 'Bold'), anchor='mm', fill=CYAN + (int(255 * ease((t - 0.4) / 0.2)),))
    k = ease((t - 0.6) / 0.2)
    f = tf(46)
    w = f.getlength(search)
    d.rounded_rectangle([CX - w / 2 - 44, 1420, CX + w / 2 + 44, 1510], 45, fill=CYAN + (int(255 * k),))
    d.text((CX, 1465), search, font=f, anchor='mm', fill=(6, 10, 18, int(255 * k)))


def main(name):
    v = VIDEOS[name]
    clip = os.path.join(AI, v['clip'])
    c0, c1 = v['clip_span']
    words = [(w, s - c0 + EMILY, e - c0 + EMILY) for w, s, e in json.load(open(clip.replace('.mp4', '.words.json')))]
    cover = f'scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H}'
    emily = decode(clip, c0, c1 - c0 + 0.1, cover)
    app = decode(os.path.join(R.RAW, v['raw']), v['app_from'], APP_LEN + 0.1, f'scale={W}:-2,crop={W}:{H}:0:120')
    art = np.asarray(Image.open(os.path.join(AI, 'art', 'car-vertical.jpg')).convert('RGB'))
    art_shaded = bottom_shade(art)

    PICKS = EMILY + (c1 - c0)
    APP = PICKS + PICK_LEN * len(v['picks'])
    END = APP + APP_LEN
    TOTAL = END + END_LEN
    timing = {'emily': EMILY, 'picks': PICKS, 'app': APP, 'end': END, 'total': TOTAL}

    out = os.path.join(R.OUT, f'{name}.mp4')
    silent = out.replace('.mp4', '-video.mp4')
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17',
                            '-preset', 'medium', silent], stdin=subprocess.PIPE)
    for n in range(int(TOTAL * FPS)):
        t = n / FPS
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        if t < EMILY:
            # lights on one by one, then out; slow push-in on the car
            lit = 0 if t >= 1.15 else min(5, int((t - 0.15) / 0.2) + 1) if t >= 0.15 else 0
            frame = lights(zoom(art_shaded, 1.0 + 0.06 * t / EMILY, 0.2), lit)
            hook_text(layer, v['hook'], t - 0.05)
            frame = static(frame, max(0, 0.5 - t * 2.5) + (max(0, (t - 1.15) / 0.2) * 0.5 if t > 1.15 else 0))
        elif t < PICKS:
            ct = t - EMILY + c0
            z = 1.0
            for at, zz in v['punch']:
                if ct >= at:
                    z = zz
            frame = zoom(emily[min(len(emily) - 1, int((t - EMILY) * FPS))], z)
            cut = min([abs(ct - at) for at, _ in v['punch']] + [t - EMILY])
            frame = flash(frame, max(0, 0.35 - cut * 3))
            speaking = any(s - 0.05 <= t <= e + 0.15 for _, s, e in words)
            radio_box(layer, current_phrase(v['phrases'], words, t), t, speaking)
        elif t < APP:
            i = min(len(v['picks']) - 1, int((t - PICKS) / PICK_LEN))
            pt = t - PICKS - i * PICK_LEN
            shake = int(14 * max(0, 1 - pt / 0.12)) * (1 if i % 2 else -1)
            frame = np.roll(lights(zoom(art_shaded, 1.04 + 0.01 * i, 0.2), 5), shake, axis=1)
            frame = flash(frame, max(0, 0.45 - pt * 4))
            pick_text(layer, *v['picks'][i], pt)
        elif t < END:
            frame = phone(art, app[min(len(app) - 1, int((t - APP) * FPS))], ease((t - APP) / 0.2))
        else:
            et = t - END
            frame = lights(art_shaded, 5 if int(et * 4) % 2 == 0 or et < 1.2 else 0)
            end_text(layer, v['end'], et)
            if t > TOTAL - 0.3:   # crackle back into the start: the loop
                frame = static(frame, (t - (TOTAL - 0.3)) / 0.3 * 0.6)
        img = Image.fromarray(frame).convert('RGBA')
        img.alpha_composite(layer)
        enc.stdin.write(np.asarray(img.convert('RGB')).tobytes())
    enc.stdin.close(); enc.wait()
    mix_audio(v, clip, silent, out, words, timing)
    os.remove(silent)
    print('✓', out, f'{TOTAL:.1f}s')


def mix_audio(v, clip, silent, out, words, tm):
    """Light beeps, lights-out crackle, Emily (music ducked under her), a key
    click per pick, the radio call on the end card, crackle into the loop."""
    sfx = os.path.join(R.SOUNDS, 'radio-key.caf')
    call = os.path.join(R.SOUNDS, 'radio-call.caf')
    music = sorted((os.path.join(R.MUSIC, f) for f in os.listdir(R.MUSIC) if f.endswith(('.wav', '.mp3'))),
                   key=os.path.getmtime)[-1]
    c0, c1 = v['clip_span']
    T = tm['total']
    clicks = [tm['picks'] + i * PICK_LEN for i in range(len(v['picks']))]
    ms = lambda s: f'{int(s * 1000)}|{int(s * 1000)}'
    inputs = ['-i', silent, '-ss', str(c0), '-t', str(c1 - c0), '-i', clip, '-i', call, '-i', music]
    inputs += sum((['-i', sfx] for _ in clicks), [])
    filt = []
    beeps = []
    for i in range(5):   # one beep per light
        filt.append(f'sine=f=880:d=0.12,volume=0.35,afade=t=out:st=0.06:d=0.06,adelay={ms(0.15 + i * 0.2)}[b{i}]')
        beeps.append(f'[b{i}]')
    filt += [
        f'anoisesrc=d=0.35:c=white:a=0.4,bandpass=f=2200:w=1800,afade=t=out:st=0.1:d=0.25,adelay={ms(1.15)}[out1]',
        f'anoisesrc=d=0.3:c=white:a=0.35,bandpass=f=2200:w=1800,adelay={ms(T - 0.3)}[out2]',
        f'[1:a]adelay={ms(tm["emily"])},volume=2.4[vo]',
        f'[2:a]adelay={ms(tm["end"])},volume=0.8[call]',
        (f'[3:a]atrim=0:{T},volume=\'if(between(t,{tm["emily"]},{tm["picks"]}),0.10,0.42)\':eval=frame,'
         f'afade=t=out:st={T - 0.5}:d=0.5[bed]'),
    ]
    for i, c in enumerate(clicks):
        filt.append(f'[{4 + i}:a]adelay={ms(c)},volume=0.9[k{i}]')
    labels = ''.join(beeps) + '[out1][out2][vo][call][bed]' + ''.join(f'[k{i}]' for i in range(len(clicks)))
    count = 5 + 5 + len(clicks)
    filt.append(f'{labels}amix=inputs={count}:normalize=0,loudnorm=I=-14:TP=-1.5,atrim=0:{T}[a]')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(filt),
                    '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', out],
                   check=True)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'singapore-ai')
