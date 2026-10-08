#!/usr/bin/env python3
"""Cuts a demo recording into a finished 9:16 video.

    scripts/video/render.py malaysia-1 [raw/countdown-YYYY-MM-DD.mov]

Layout: the whole app screen in an iPhone-style frame, a big headline above
it that changes per scene (words in *stars* in the app's cyan), and the app's
own radio sounds — a key click on every cut, the radio call on the end card.

Videos are defined in VIDEOS: scenes of (demo start, duration, headline).
Times are demo-timeline seconds from the app's step log
(scripts/video/capture.sh), so they're right however long the app took to load.

Output: Marketing/videos/out/<name>.mp4 (1080×1920, 30 fps).
"""
import glob, json, os, shutil, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'Marketing/videos/raw')
OUT = os.path.join(ROOT, 'Marketing/videos/out')
SOUNDS = os.path.join(ROOT, 'TeamRadio/Resources')
MUSIC = os.path.join(ROOT, 'Marketing/videos/music')   # newest track here is mixed under every video
FONT = '/System/Library/Fonts/SFNSRounded.ttf'
W, H, FPS = 1080, 1920, 30

# the phone: screen height and top edge; width follows the recording's aspect
SCREEN_H, SCREEN_Y, RADIUS = 1420, 455, 62
CYAN = (64, 214, 255)

# end card: headline + small line under it
CTA = ('Free on the *App Store*', 'Search "Team Radio" · unofficial fan app')

VIDEOS = {
    # Script 1 — "The lights are coming on"
    'malaysia-1': {
        'source': 'countdown',
        'scenes': [
            (1.0, 2.6, 'They moved *Bahrain* to *Malaysia*?!'),
            (20.6, 5.0, 'A countdown to *every* session'),
            (12.6, 4.4, 'Session info on a real *LED board*'),
            (27.2, 2.6, 'Pin it to your *Lock Screen*'),
            (45.2, 3.6, CTA),
        ],
    },
    # The app half of emily-1 (scripts/video/emily.py puts Emily in front of it)
    'emily-1-app': {
        'source': 'countdown',
        'scenes': [
            (38.9, 3.0, 'A heads-up *15 minutes* before'),
            (27.2, 2.6, 'Pin it to your *Lock Screen*'),
            (45.2, 3.6, CTA),
        ],
    },
    # Script 2 — "Your time, not theirs"
    'malaysia-2': {
        'source': 'countdown',
        'scenes': [
            (32.8, 2.4, 'FP1 at a *ridiculous* hour again?'),
            (35.0, 4.2, 'Every session in *your* time zone'),
            (38.9, 3.0, 'A heads-up *15 minutes* before'),
            (27.2, 2.6, 'Pin it to your *Lock Screen*'),
            (45.2, 3.6, CTA),
        ],
    },
}


def font(size, weight='Black'):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def words(text):
    """'Pin it to your *Lock Screen*' → [(word, highlighted), …]. A run of
    punctuation right after a highlight ('*Malaysia*?!') sticks to it."""
    out, parts = [], text.split('*')
    for i, part in enumerate(parts):
        touching = i > 0 and parts[i - 1][-1:].strip() and part[:1].strip()
        for j, w in enumerate(part.split()):
            if j == 0 and out and touching:
                out.append(('\u2060' + w, i % 2 == 1))   # glued: no space before
            else:
                out.append((w, i % 2 == 1))
    return out


def headline_png(path, text, sub=None):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font(78)
    space = f.getlength(' ')
    glued = lambda w: w.startswith('\u2060')
    width = lambda ln: sum(f.getlength(w.lstrip('\u2060')) + (0 if glued(w) or k == 0 else space)
                           for k, (w, _) in enumerate(ln))
    lines, line = [], []
    for word in words(text):
        if line and width(line + [word]) > 900:
            lines.append(line); line = [word]
        else:
            line.append(word)
    lines.append(line)
    y = 290 - len(lines) * 48 - (30 if sub else 0)
    for ln in lines:
        x = (W - width(ln)) / 2
        for k, (w, hl) in enumerate(ln):
            if k and not glued(w):
                x += space
            w = w.lstrip('\u2060')
            d.text((x, y), w, font=f, fill=CYAN if hl else 'white')
            x += f.getlength(w)
        y += 96
    if sub:
        d.text((W / 2, y + 26), sub, font=font(38, 'Bold'), fill=(190, 196, 210), anchor='mm')
    # soft dark shadow so the words hold up over bright footage (floodlights in the Emily shots)
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    shadow.putalpha(im.getchannel('A').filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(14))
                    .point(lambda a: min(255, int(a * 0.85))))
    Image.alpha_composite(shadow, im).save(path)


def stage_png(path, sw):
    """Dark backdrop with the app's cyan/red glow and the phone bezel."""
    bg = Image.new('RGB', (W, H), (5, 7, 12))
    glow = Image.new('RGB', (W, H), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([140, 700, 940, 1500], fill=(20, 70, 110))
    g.ellipse([420, 900, 1100, 1600], fill=(90, 25, 20))
    bg = Image.blend(bg, glow.filter(ImageFilter.GaussianBlur(160)), 0.55)
    x0 = (W - sw) // 2
    ImageDraw.Draw(bg).rounded_rectangle([x0 - 10, SCREEN_Y - 10, x0 + sw + 9, SCREEN_Y + SCREEN_H + 9],
                                         RADIUS + 10, fill=(22, 24, 30), outline=(70, 74, 86), width=3)
    bg.save(path)


def mask_png(path, sw):
    m = Image.new('L', (sw, SCREEN_H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, sw - 1, SCREEN_H - 1], RADIUS, fill=255)
    m.save(path)


def render(name, raw=None, out=None, music=True):
    v = VIDEOS[name]
    raw = raw or sorted(glob.glob(os.path.join(RAW, v['source'] + '-*.mov')))[-1]
    offset = json.load(open(raw[:-4] + '.json'))['offset']
    rw, rh = map(int, subprocess.check_output(
        ['ffprobe', '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height',
         '-of', 'csv=p=0', raw], text=True).strip().split(','))
    sw = round(rw * SCREEN_H / rh / 2) * 2
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix='teamradio-video-')
    stage, mask = os.path.join(tmp, 'stage.png'), os.path.join(tmp, 'mask.png')
    stage_png(stage, sw)
    mask_png(mask, sw)

    scenes = v['scenes']
    n, total = len(scenes), sum(s[1] for s in scenes)
    args, chains = ['ffmpeg', '-y', '-loglevel', 'error'], []

    # the app footage, scene by scene, into the rounded screen on the stage
    for i, (start, dur, _) in enumerate(scenes):
        args += ['-ss', f'{start + offset:.3f}', '-t', f'{dur:.3f}', '-i', raw]
        chains.append(f'[{i}:v]fps={FPS},scale={sw}:{SCREEN_H}:flags=lanczos,setsar=1[s{i}]')
    chains.append(''.join(f'[s{i}]' for i in range(n)) + f'concat=n={n}:v=1:a=0,format=rgba[scr]')
    k = n
    args += ['-loop', '1', '-t', f'{total:.3f}', '-i', stage, '-loop', '1', '-t', f'{total:.3f}', '-i', mask]
    chains.append(f'[{k + 1}:v]format=gray[m]')
    chains.append('[scr][m]alphamerge[phone]')
    chains.append(f'[{k}:v][phone]overlay={(W - sw) // 2}:{SCREEN_Y}:shortest=1[v0]')
    k += 2

    # one headline per scene, with a quick fade
    last, t = 'v0', 0.0
    for j, (_, dur, text) in enumerate(scenes):
        png = os.path.join(tmp, f'h{j}.png')
        headline_png(png, *(text if isinstance(text, tuple) else (text,)))
        args += ['-loop', '1', '-t', f'{total:.3f}', '-i', png]
        fade_in = f'fade=t=in:st={t:.2f}:d=0.15:alpha=1,' if j else ''   # frame 0 (the cover) shows it fully
        chains.append(f'[{k}:v]format=rgba,{fade_in}'
                      f'fade=t=out:st={t + dur - 0.15:.2f}:d=0.15:alpha=1[h{j}]')
        chains.append(f"[{last}][h{j}]overlay=0:0:enable='between(t,{t:.2f},{t + dur:.2f})'[v{j + 1}]")
        last, t, k = f'v{j + 1}', t + dur, k + 1

    # sound: the radio key click on the open and every cut, the radio call on the end card
    starts = [sum(s[1] for s in scenes[:j]) for j in range(n)]
    sfx = [(at, 'radio-key.caf') for at in starts[:-1]] + [(starts[-1], 'radio-call.caf')]
    labels = []
    for j, (at, f) in enumerate(sfx):
        args += ['-i', os.path.join(SOUNDS, f)]
        ms = int(at * 1000)
        chains.append(f'[{k}:a]aresample=48000,aformat=channel_layouts=stereo,adelay={ms}|{ms}[a{j}]')
        labels.append(f'[a{j}]')
        k += 1
    tracks = sorted((f for f in glob.glob(os.path.join(MUSIC, '*')) if f.lower().endswith(('.mp3', '.wav', '.m4a'))),
                    key=os.path.getmtime)
    if tracks and music:
        args += ['-stream_loop', '-1', '-i', tracks[-1]]
        chains.append(f'[{k}:a]aresample=48000,aformat=channel_layouts=stereo,atrim=0:{total:.3f},'
                      f'volume=0.45,afade=t=in:d=0.3,afade=t=out:st={total - 0.8:.2f}:d=0.8[music]')
        labels.append('[music]')
        k += 1
        print('♪', os.path.basename(tracks[-1]))
    args += ['-f', 'lavfi', '-t', f'{total:.3f}', '-i', 'anullsrc=r=48000:cl=stereo']
    labels.append(f'[{k}:a]')
    chains.append(''.join(labels) + f'amix=inputs={len(labels)}:duration=longest:normalize=0,'
                  f'loudnorm=I=-14:TP=-1.5:LRA=11[aud]')   # social-video loudness

    out = out or os.path.join(OUT, name + '.mp4')
    args += ['-filter_complex', ';'.join(chains), '-map', f'[{last}]', '-map', '[aud]', '-t', f'{total:.3f}',
             '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-r', str(FPS),
             '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', out]
    subprocess.run(args, check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print('✓', out, f'({total:.1f}s)')


if __name__ == '__main__':
    render(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
