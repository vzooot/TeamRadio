from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np, sys
W = 780; BG = (8,10,14)
RB = '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
HN = '/System/Library/Fonts/HelveticaNeue.ttc'
def f(p, s, i=0): return ImageFont.truetype(p, s, index=i)
def trim(im): return im.crop(im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox())
def glow_bg(HH, tint, cx, cy):
    y = np.linspace(0,1,HH)[:,None]; x = np.linspace(0,1,W)[None,:]
    g = np.clip(1.25 - np.hypot(x-cx, y-cy)*1.35, 0, 1)[...,None]
    b = np.array(BG,float)
    return Image.fromarray(np.broadcast_to((b+(np.array(tint,float)-b)*0.6*g).clip(0,255).astype(np.uint8),(HH,W,3)).copy()).convert('RGBA')
def bottom_fade(img, start):
    HH = img.height
    m = Image.fromarray((np.clip((np.arange(HH)-HH*start)/(HH*(1-start)),0,1)*255).astype(np.uint8)[:,None].repeat(W,1))
    return Image.composite(Image.new('RGBA',(W,HH),BG+(255,)), img, m)
def fade_left(art, frac):
    a = np.array(art.getchannel('A'),float); w = a.shape[1]
    art.putalpha(Image.fromarray((a*np.clip(np.arange(w)/(w*frac),0,1)[None,:]).astype(np.uint8))); return art
def block(d, y, label, number, word, caption):
    d.text((36, y), label, font=f(HN,30), fill=(200,205,215))
    nf = f(RB,132); d.text((32,y+40), number, font=nf, fill=(250,252,255))
    d.text((32+d.textlength(number,font=nf)+18, y+62), word, font=f(HN,104,7), fill=(250,252,255))
    d.text((36, y+196), caption, font=f(HN,30), fill=(200,205,215))
    d.line([(24,y+262),(W-24,y+262)], fill=(40,44,52), width=2)

def team(out):
    H = 1500; c = Image.new('RGBA',(W,H),BG+(255,)); tint=(0,210,190); HH=560
    hdr = glow_bg(HH, tint, 0.72, 0.3)
    car = trim(Image.open('Marketing/raw/art/Silver graphite open-wheel with turquoise accents.png').convert('RGBA'))
    car = car.resize((600, int(car.height*600/car.width)), Image.LANCZOS)
    # straight down from the top, on the right like the driver: the front half enters the sheet
    car = car.resize((700, int(car.height*700/car.width)), Image.LANCZOS)
    x0, y0 = W - car.width + 150, -car.height + 460
    car = fade_left(car, 0.3)
    sh = Image.new('RGBA', car.size, (0,0,0,0)); sh.putalpha(car.getchannel('A').point(lambda a: int(a*0.5)))
    hdr.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)), (x0+10, y0+24))
    hdr.alpha_composite(car, (x0, y0))
    hdr = bottom_fade(hdr, 0.5); c.alpha_composite(hdr,(0,0)); d = ImageDraw.Draw(c)
    d.text((36,330), 'Mercedes', font=f(RB,88), fill=(245,248,255))
    d.text((38,432), 'W17  ·  Brackley, United Kingdom', font=f(HN,30), fill=tint)
    block(d, 600, "Constructors' championship", '01', 'POS', '538 points · leader by 42')
    block(d, 880, 'Season', '11', 'WINS', '22 podiums · 9 poles')
    block(d, 1160,'Top scorer', '302', 'PTS', 'Andrea Kimi Antonelli')
    c.convert('RGB').save(out)

def driver(out):
    H = 1500; c = Image.new('RGBA',(W,H),BG+(255,)); tint=(0,210,190); HH=640
    hdr = glow_bg(HH, tint, 0.72, 0.3)
    suit = trim(Image.open('Marketing/raw/art/Silver-turquoise helmeted racer.png').convert('RGBA'))
    suit = suit.resize((int(suit.width*880/suit.height), 880), Image.LANCZOS)
    hdr.alpha_composite(fade_left(suit, 0.15), (W-suit.width-10, 30))
    hdr = bottom_fade(hdr, 0.55); c.alpha_composite(hdr,(0,0)); d = ImageDraw.Draw(c)
    d.text((36,70), '12', font=f(RB,64), fill=tint)
    d.text((36,300), 'Kimi', font=f(RB,96), fill=(245,248,255))
    d.text((36,400), 'Antonelli', font=f(HN,84,7), fill=(245,248,255))
    d.text((38,510), 'ANT  ·  Mercedes  ·  Italy', font=f(HN,30), fill=tint)
    block(d, 670, 'Drivers\' championship', '01', 'POS', '302 points · leader by 66')
    block(d, 950, 'Season', '08', 'WINS', '12 podiums · 6 poles · 1 DNF')
    block(d, 1230,'Career', '2025', '', 'First entry Australian GP · first win Chinese GP')
    c.convert('RGB').save(out)
team('Marketing/raw/design/team-sheet-mock.png'); driver('Marketing/raw/design/driver-sheet-mock.png')
a=Image.open('Marketing/raw/design/team-sheet-mock.png'); b=Image.open('Marketing/raw/design/driver-sheet-mock.png')
s=Image.new('RGB',(W*2+30,1500),(0,0,0)); s.paste(a,(0,0)); s.paste(b,(W+30,0)); s.save('Marketing/raw/design/sheets-mock.png')
