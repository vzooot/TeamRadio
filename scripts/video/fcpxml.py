"""Writes a Final Cut Pro project (FCPXML 1.11) for an Emily video, to fine-tune by hand.

Timeline: the shots in order on the main storyline (clean pictures, no text),
each with its original sound as a connected clip below; every caption as an
editable Basic Title above (text, font, colour, size, position all editable);
the rendered animated captions as one more clip, switched off, in case the
word-by-word look is wanted as it was; the song below, starting where the
rendered video starts it. Open by double-clicking <name>.fcpxml.
"""
import os
from urllib.parse import quote
from xml.sax.saxutils import quoteattr

FPS = 30


def t(seconds):
    return f'{round(seconds * FPS)}/{FPS}s'


def url(path):
    return 'file://' + quote(os.path.abspath(path))


TITLE_UID = '.../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti'


def esc(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def title_xml(n, ti, offset, geom):
    """One caption as a Basic Title: Avenir Next Heavy, white with a black outline, cyan words."""
    cx, w, h = geom
    size = ti.get('size', 84)
    styles, runs = [], []
    for i, (word, cyan) in enumerate(ti['words']):
        sid = f'ts{n}_{i}'
        color = '0.251 0.839 1 1' if cyan else '1 1 1 1'
        runs.append(f'<text-style ref="{sid}">{esc(word)}{" " if i < len(ti["words"]) - 1 else ""}</text-style>')
        styles.append(f'<text-style-def id="{sid}"><text-style font="Avenir Next" fontSize="{size}" fontFace="Heavy" '
                      f'fontColor="{color}" strokeColor="0 0 0 1" strokeWidth="{-6 if size > 50 else -3}" '
                      f'alignment="center"/></text-style-def>')
    pos = f'{cx - w / 2:.0f} {h / 2 - ti["y"]:.0f}'
    return (f'<title ref="basic" lane="2" offset="{offset}" name={quoteattr(" ".join(x for x, _ in ti["words"]))} '
            f'start="3600s" duration="{t(ti["end"] - ti["start"])}">'
            f'<param name="Position" key="9999/999166631/999166633/1/100/101" value="{pos}"/>'
            f'<text>{"".join(runs)}</text>{"".join(styles)}</title>')


def write(outdir, name, pieces, song, music_start, total, titles=(), geom=(500, 1080, 1920)):
    res, spine = [], []
    res.append(f'<effect id="basic" name="Basic Title" uid="{TITLE_UID}"/>')
    res.append(f'<format id="fmt" name="Vertical 1080x1920 30p" frameDuration="1/{FPS}s" width="1080" height="1920" '
               f'colorSpace="1-1-1 (Rec. 709)"/>')
    sources = {}
    for idx, _, dur, (kind, src, a, b) in pieces:
        res.append(f'<asset id="v{idx}" name="Shot {idx:02d}" start="0s" duration="{t(dur)}" hasVideo="1" '
                   f'format="fmt" videoSources="1"><media-rep kind="original-media" '
                   f'src={quoteattr(url(os.path.join(outdir, f"{idx:02d}.mov")))}/></asset>')
        if kind == 'clip' and src not in sources:
            sid = f's{len(sources) + 1}'
            sources[src] = sid
            res.append(f'<asset id="{sid}" name={quoteattr(os.path.basename(src))} start="0s" duration="{t(20)}" '
                       f'hasAudio="1" audioSources="1" audioChannels="2" audioRate="48000">'
                       f'<media-rep kind="original-media" src={quoteattr(url(src))}/></asset>')
    res.append(f'<asset id="cap" name="Captions" start="0s" duration="{t(total)}" hasVideo="1" format="fmt" '
               f'videoSources="1"><media-rep kind="original-media" src={quoteattr(url(os.path.join(outdir, "captions.mov")))}/></asset>')
    res.append(f'<asset id="song" name={quoteattr(os.path.basename(song))} start="0s" duration="{t(120)}" hasAudio="1" '
               f'audioSources="1" audioChannels="2" audioRate="48000"><media-rep kind="original-media" '
               f'src={quoteattr(url(song))}/></asset>')

    for i, (idx, at, dur, (kind, src, a, b)) in enumerate(pieces):
        inner = []
        if kind == 'clip':
            inner.append(f'<asset-clip ref="{sources[src]}" lane="-1" offset="0s" name="Voice {idx:02d}" start="{t(a)}" '
                         f'duration="{t(dur)}" srcEnable="audio" audioRole="dialogue"/>')
        # each title hangs off the shot it starts in (offsets are in that shot's own time)
        for n, ti in enumerate(titles):
            if at - 1e-6 <= ti['start'] < at + dur - 1e-6:
                inner.append(title_xml(n, ti, t(ti['start'] - at), geom))
        if i == 0:
            inner.append(f'<asset-clip ref="cap" lane="1" offset="0s" name="Animated captions (off)" start="0s" '
                         f'duration="{t(total)}" enabled="0"/>')
            inner.append(f'<asset-clip ref="song" lane="-2" offset="0s" name="Music" start="{t(music_start)}" '
                         f'duration="{t(total)}" audioRole="music"/>')
        spine.append(f'<asset-clip ref="v{idx}" offset="{t(at)}" name="Shot {idx:02d}" start="0s" duration="{t(dur)}">'
                     + ''.join(inner) + '</asset-clip>')

    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE fcpxml>\n<fcpxml version="1.11">\n'
           '<resources>\n' + '\n'.join(res) + '\n</resources>\n'
           f'<library><event name="Team Radio"><project name={quoteattr(name)}>'
           f'<sequence format="fmt" duration="{t(total)}" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">'
           '<spine>\n' + '\n'.join(spine) + '\n</spine></sequence></project></event></library>\n</fcpxml>\n')
    path = os.path.join(outdir, name + '.fcpxml')
    open(path, 'w').write(xml)
    return path
