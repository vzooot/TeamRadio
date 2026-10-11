#!/usr/bin/env python3
"""Post-race "did our AI get it right?" short: the AI Strategist's picks
appear one by one over the neon car art, each stamped with the real result
(green tick or red cross), then the score and the prediction-game hook.
Ends crackling back into the start so it loops.

    scripts/video/verdict.py singapore

Results go in VERDICTS (fill them in after the race). Output:
Marketing/videos/out/<name>-verdict.mp4 (1080×1920, 30 fps)
"""
import os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R
import teamradio_ai as T

W, H, FPS = R.W, R.H, R.FPS
CX = T.CX
GREEN, RED = (52, 211, 120), (253, 75, 40)

VERDICTS = {
    'singapore': {
        'race': 'SINGAPORE GP',
        'hook': ('OUR AI PREDICTED', 'THE SINGAPORE GP'),
        # (label, AI pick, actual, team colour of the actual)
        'rows': [
            ('POLE', 'ANTONELLI', 'VERSTAPPEN', 'red_bull'),
            ('WINNER', 'ANTONELLI', 'VERSTAPPEN', 'red_bull'),
            ('P2', 'RUSSELL', 'LECLERC', 'ferrari'),
            ('P3', 'HAMILTON', 'ANTONELLI', 'mercedes'),
            ('FASTEST LAP', 'RUSSELL', 'LECLERC', 'ferrari'),
            ('RETIREMENTS', '2-3', '2-3', 'rb'),
        ],
        'end': ('THINK YOU CAN BEAT IT?', 'Prediction game drops for Austin', 'Search "teamradio" on the App Store'),
    },
}

HOOK_LEN, ROW_LEN, SCORE_LEN, DOTD_LEN, END_LEN = 1.6, 1.25, 1.6, 1.8, 2.4


def row_card(layer, label, ai, actual, team, t):
    """The AI's pick slams in, then the verdict stamp and the real result."""
    d = ImageDraw.Draw(layer)
    hit = ai == actual
    e = T.ease(t / 0.15)
    d.text((CX, 1060), f'THE AI SAID  ·  {label}', font=T.tf(46, 'Bold'), anchor='mm', fill=T.CYAN + (int(255 * e),))
    f = T.tf(round(120 * (1.3 - 0.3 * e)))
    if f.getlength(ai) > 860:
        f = T.tf(round(f.size * 860 / f.getlength(ai)))
    T.glow_text(layer, (CX, 1190), ai, f, (255, 255, 255, int(255 * e)))
    s = t - 0.45
    if s > 0:
        k = T.ease(s / 0.12)
        col = GREEN if hit else RED
        mark = '✓' if hit else '✗'
        # stamp over the name
        sf = T.tf(round(150 * (1.6 - 0.6 * k)), 'Heavy')
        mx = min(W - 90, CX + f.getlength(ai) / 2 + 85)
        T.glow_text(layer, (mx, 1180), mark, sf, col + (int(255 * k),), col, 0.9 * k, 30)
        if not hit:
            w = f.getlength(ai)
            d.line([CX - w / 2 - 10, 1195, CX - w / 2 - 10 + (w + 20) * k, 1195], fill=RED + (230,), width=12)
        d.text((CX, 1330), 'CORRECT' if hit else f'ACTUALLY: {actual}', font=T.tf(58), anchor='mm',
               fill=(GREEN if hit else (255, 255, 255)) + (int(255 * k),))
        bar = 340 * k
        d.rounded_rectangle([CX - bar / 2, 1395, CX + bar / 2, 1409], 7, fill=T.TEAM.get(team, (200, 200, 200)) + (255,))


def score_card(layer, hits, total, t):
    e = T.ease(t / 0.2)
    T.glow_text(layer, (CX, 1130), f'{hits} / {total}', T.tf(220), (255, 255, 255, int(255 * e)), RED, 0.8 * e, 30)
    line = 'ROUGH NIGHT FOR THE AI' if hits <= total // 2 else 'NOT BAD, AI'
    ImageDraw.Draw(layer).text((CX, 1290), line, font=T.tf(64), anchor='mm', fill=T.CYAN + (int(255 * T.ease((t - 0.3) / 0.2)),))


def dotd_card(layer, t):
    e = T.ease(t / 0.2)
    T.glow_text(layer, (CX, 1090), 'YOUR DRIVER', T.tf(118), (255, 255, 255, int(255 * e)), T.CYAN, 0.7 * e)
    T.glow_text(layer, (CX, 1210), 'OF THE DAY?', T.tf(118), T.CYAN + (int(255 * e),), T.CYAN, 0.7 * e)
    ImageDraw.Draw(layer).text((CX, 1330), 'Kimi P3 with a leaking car? Comment yours', font=T.tf(44, 'Bold'),
                               anchor='mm', fill=(225, 230, 240, int(255 * T.ease((t - 0.3) / 0.2))))


def end_card(layer, end, t):
    big, sub, search = end
    d = ImageDraw.Draw(layer)
    e0 = T.ease(t / 0.2)
    f = T.tf(100)
    if f.getlength(big) > 900:
        f = T.tf(round(100 * 900 / f.getlength(big)))
    T.glow_text(layer, (CX, 1140), big, f, (255, 255, 255, int(255 * e0)), T.CYAN, 0.8 * e0)
    d.text((CX, 1260), sub, font=T.tf(46, 'Bold'), anchor='mm', fill=T.CYAN + (int(255 * T.ease((t - 0.3) / 0.2)),))
    k = T.ease((t - 0.6) / 0.2)
    sf = T.tf(46)
    w = sf.getlength(search)
    d.rounded_rectangle([CX - w / 2 - 44, 1360, CX + w / 2 + 44, 1450], 45, fill=T.CYAN + (int(255 * k),))
    d.text((CX, 1405), search, font=sf, anchor='mm', fill=(6, 10, 18, int(255 * k)))


def main(name):
    v = VERDICTS[name]
    art = np.asarray(Image.open(os.path.join(T.AI, 'art', 'car-vertical.jpg')).convert('RGB'))
    shaded = T.bottom_shade(art)
    rows = v['rows']
    hits = sum(1 for _, a, b, _ in rows if a == b)
    ROWS = HOOK_LEN
    SCORE = ROWS + ROW_LEN * len(rows)
    DOTD = SCORE + SCORE_LEN
    END = DOTD + DOTD_LEN
    TOTAL = END + END_LEN

    out = os.path.join(R.OUT, f'{name}-verdict.mp4')
    silent = out.replace('.mp4', '-video.mp4')
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17',
                            '-preset', 'medium', silent], stdin=subprocess.PIPE)
    for n in range(int(TOTAL * FPS)):
        t = n / FPS
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        if t < ROWS:
            frame = T.zoom(shaded, 1.0 + 0.06 * t / TOTAL, 0.15)
            T.hook_text(layer, v['hook'], t - 0.05)
        elif t < SCORE:
            i = min(len(rows) - 1, int((t - ROWS) / ROW_LEN))
            rt = t - ROWS - i * ROW_LEN
            label, ai, actual, team = rows[i]
            frame = T.zoom(shaded, 1.0 + 0.06 * t / TOTAL, 0.15)
            row_card(layer, label, ai, actual, team, rt)
        elif t < DOTD:
            frame = T.dark(T.zoom(shaded, 1.0 + 0.06 * t / TOTAL, 0.15), 0.75)
            score_card(layer, hits, len(rows), t - SCORE)
        elif t < END:
            frame = T.zoom(shaded, 1.0 + 0.06 * t / TOTAL, 0.15)
            dotd_card(layer, t - DOTD)
        else:
            frame = T.zoom(shaded, 1.0 + 0.06 * t / TOTAL, 0.15)
            end_card(layer, v['end'], t - END)
        img = Image.fromarray(frame).convert('RGBA')
        img.alpha_composite(layer)
        enc.stdin.write(np.asarray(img.convert('RGB')).tobytes())
    enc.stdin.close(); enc.wait()

    # beeps on the lights, a key click per pick, a buzzer/ding per verdict, music bed, crackle loop
    sfx = os.path.join(R.SOUNDS, 'radio-key.caf')
    call = os.path.join(R.SOUNDS, 'radio-call.caf')
    music = sorted((os.path.join(R.MUSIC, f) for f in os.listdir(R.MUSIC) if f.endswith(('.wav', '.mp3'))),
                   key=os.path.getmtime)[-1]
    ms = lambda s: f'{int(s * 1000)}|{int(s * 1000)}'
    inputs = ['-i', silent, '-i', music, '-i', call] + sum((['-i', sfx] for _ in rows), [])
    filt = [f'sine=f=880:d=0.12,volume=0.35,afade=t=out:st=0.06:d=0.06,adelay={ms(0.15 + i * 0.2)}[b{i}]' for i in range(5)]
    for i, (_, a, b, _) in enumerate(rows):
        at = ROWS + i * ROW_LEN
        filt.append(f'[{3 + i}:a]adelay={ms(at)},volume=0.9[k{i}]')
        if a == b:
            filt.append(f'sine=f=1320:d=0.18,volume=0.4,afade=t=out:st=0.08:d=0.1,adelay={ms(at + 0.45)}[v{i}]')
        else:
            filt.append(f'sine=f=150:d=0.3,volume=0.6,afade=t=out:st=0.15:d=0.15,adelay={ms(at + 0.45)}[v{i}]')
    filt += [f'[1:a]atrim=0:{TOTAL},volume=0.4,afade=t=out:st={TOTAL - 0.5}:d=0.5[bed]',
             f'[2:a]adelay={ms(END)},volume=0.8[call]',
             f'anoisesrc=d=0.3:c=white:a=0.35,bandpass=f=2200:w=1800,adelay={ms(TOTAL - 0.3)}[out2]']
    labels = ''.join(f'[b{i}]' for i in range(5)) + ''.join(f'[k{i}][v{i}]' for i in range(len(rows))) + '[bed][call][out2]'
    count = 5 + 2 * len(rows) + 3
    filt.append(f'{labels}amix=inputs={count}:normalize=0,loudnorm=I=-14:TP=-1.5,atrim=0:{TOTAL}[a]')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(filt),
                    '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', out],
                   check=True)
    os.remove(silent)
    print('✓', out, f'{TOTAL:.1f}s', f'{hits}/{len(rows)}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'singapore')
