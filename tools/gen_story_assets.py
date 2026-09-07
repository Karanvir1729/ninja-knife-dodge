#!/usr/bin/env python3
"""Props and glyphs for the Four Trials story: dojo platform, torii gate, lanterns,
seal ring, trial glyphs and a mist blob. White where Godot should tint.
Run: python3 tools/gen_story_assets.py -> graphics/gen/story/*.png"""
import math, pathlib
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "graphics" / "gen" / "story"
OUT.mkdir(parents=True, exist_ok=True)
SS = 4
INK = (12, 13, 24, 255)
def S(v): return v * SS
def canvas(w, h): return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
def save(img, w, h, name):
    img.resize((w, h), Image.LANCZOS).save(OUT / f"{name}.png", optimize=True); print("wrote", name)

def torii(w=512, h=384):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    red = (150, 34, 52, 255); dark = (70, 14, 28, 255)
    # pillars
    for x in (120, 392):
        d.rounded_rectangle([S(x - 18), S(120), S(x + 18), S(384)], radius=S(6), fill=red, outline=INK, width=S(5))
        d.rectangle([S(x - 26), S(360), S(x + 26), S(384)], fill=dark, outline=INK, width=S(4))
    # lower beam (nuki)
    d.rounded_rectangle([S(80), S(150), S(432), S(176)], radius=S(4), fill=red, outline=INK, width=S(5))
    # upper beam (kasagi) with upturned ends
    pts = [(40, 110), (472, 110), (486, 84), (26, 84)]
    d.polygon([(S(x), S(y)) for x, y in pts], fill=dark, outline=INK)
    d.line([(S(x), S(y)) for x, y in pts + [pts[0]]], fill=INK, width=S(5), joint="curve")
    d.rounded_rectangle([S(60), S(110), S(452), S(132)], radius=S(4), fill=red, outline=INK, width=S(5))
    # gakuzuka (centre tablet)
    d.rounded_rectangle([S(236), S(132), S(276), S(152)], radius=S(3), fill=dark, outline=INK, width=S(4))
    save(img, w, h, "torii")

def platform(w=640, h=180):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    top = (42, 48, 80, 255); side = (24, 27, 46, 255); edge = (86, 240, 255, 255)
    d.polygon([(S(20), S(40)), (S(620), S(40)), (S(560), S(120)), (S(80), S(120))], fill=side, outline=INK)
    d.line([(S(20), S(40)), (S(620), S(40)), (S(560), S(120)), (S(80), S(120)), (S(20), S(40))], fill=INK, width=S(5), joint="curve")
    d.polygon([(S(20), S(40)), (S(620), S(40)), (S(600), S(56)), (S(40), S(56))], fill=top)
    d.line([(S(24), S(40)), (S(616), S(40))], fill=edge, width=S(3))
    # floor tiles hint
    for x in range(80, 580, 60):
        d.line([(S(x), S(42)), (S(x - 6), S(54))], fill=(60, 68, 110, 255), width=S(2))
    # floating rocks
    for cx, cy, r in ((110, 150, 14), (330, 165, 10), (540, 152, 12)):
        d.ellipse([S(cx - r), S(cy - r * 0.7), S(cx + r), S(cy + r * 0.7)], fill=side, outline=INK, width=S(4))
    save(img, w, h, "platform")

def lantern(w=64, h=96):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    body = (255, 179, 71, 255); rib = (210, 120, 40, 255)
    d.rounded_rectangle([S(10), S(16), S(54), S(80)], radius=S(16), fill=body, outline=INK, width=S(4))
    for y in (30, 44, 58, 72):
        d.line([(S(12), S(y)), (S(52), S(y))], fill=rib, width=S(2))
    d.rounded_rectangle([S(20), S(6), S(44), S(18)], radius=S(3), fill=INK)
    d.rounded_rectangle([S(20), S(78), S(44), S(90)], radius=S(3), fill=INK)
    d.line([(S(32), S(0)), (S(32), S(6))], fill=INK, width=S(3))
    save(img, w, h, "lantern")

def pillar(w=160, h=320):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    stone = (34, 38, 64, 255); stone2 = (52, 58, 92, 255)
    d.rounded_rectangle([S(40), S(60), S(120), S(300)], radius=S(8), fill=stone, outline=INK, width=S(5))
    d.rectangle([S(28), S(292), S(132), S(316)], fill=stone2, outline=INK, width=S(4))
    d.rectangle([S(30), S(48), S(130), S(66)], fill=stone2, outline=INK, width=S(4))
    d.ellipse([S(48), S(84), S(112), S(148)], fill=(14, 15, 26, 255), outline=(86, 92, 130, 255), width=S(4))
    save(img, w, h, "pillar")

def seal_ring(size=192):
    img = canvas(size, size); d = ImageDraw.Draw(img)
    c = S(size / 2); r = S(80)
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=S(8))
    r2 = S(64)
    d.ellipse([c - r2, c - r2, c + r2, c + r2], outline=(255, 255, 255, 200), width=S(3))
    for i in range(8):
        a = i * math.pi / 4
        x, y = c + r * math.cos(a), c + r * math.sin(a)
        d.ellipse([x - S(7), y - S(7), x + S(7), y + S(7)], fill=(255, 255, 255, 255))
    save(img, size, size, "seal_ring")

def glyph(name, draw_fn, size=128):
    img = canvas(size, size); d = ImageDraw.Draw(img)
    draw_fn(d, S(size)); save(img, size, size, f"glyph_{name}")

def g_blade(d, Z):
    c = Z / 2
    d.polygon([(c, Z * 0.06), (c + Z * 0.11, Z * 0.58), (c, Z * 0.66), (c - Z * 0.11, Z * 0.58)], fill=(255,) * 4)
    d.rounded_rectangle([c - Z * 0.2, Z * 0.62, c + Z * 0.2, Z * 0.7], radius=Z * 0.02, fill=(255,) * 4)
    d.rounded_rectangle([c - Z * 0.06, Z * 0.7, c + Z * 0.06, Z * 0.92], radius=Z * 0.02, fill=(255,) * 4)
    d.ellipse([c - Z * 0.075, Z * 0.88, c + Z * 0.075, Z * 0.97], fill=(255,) * 4)

def g_eye(d, Z):
    c = Z / 2
    d.polygon([(Z * 0.08, c), (c, Z * 0.26), (Z * 0.92, c), (c, Z * 0.74)], fill=(255,) * 4)
    d.ellipse([c - Z * 0.17, c - Z * 0.17, c + Z * 0.17, c + Z * 0.17], fill=(0, 0, 0, 0))
    d.ellipse([c - Z * 0.1, c - Z * 0.1, c + Z * 0.1, c + Z * 0.1], fill=(255,) * 4)

def g_mind(d, Z):
    c = Z / 2; pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4; r = Z * 0.44 if i % 2 == 0 else Z * 0.18
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=(255,) * 4)
    d.ellipse([c - Z * 0.07, c - Z * 0.07, c + Z * 0.07, c + Z * 0.07], fill=(0, 0, 0, 0))

def g_memory(d, Z):
    for i in range(3):
        for j in range(3):
            x = Z * (0.24 + i * 0.26); y = Z * (0.24 + j * 0.26); r = Z * 0.075
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255,) * 4)
    d.line([(Z * 0.24, Z * 0.24), (Z * 0.76, Z * 0.24), (Z * 0.76, Z * 0.5), (Z * 0.24, Z * 0.5), (Z * 0.24, Z * 0.76), (Z * 0.76, Z * 0.76)], fill=(255, 255, 255, 140), width=int(Z * 0.03), joint="curve")

def mist(w=512, h=256):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    for cx, cy, rx, ry in ((160, 140, 150, 60), (320, 150, 170, 70), (420, 130, 110, 50), (250, 170, 120, 45)):
        d.ellipse([S(cx - rx), S(cy - ry), S(cx + rx), S(cy + ry)], fill=(255, 255, 255, 120))
    img = img.filter(ImageFilter.GaussianBlur(S(28)))
    save(img, w, h, "mist")

# ------------------------------------------------------------------ the Yard (Star Cricket films)

def steps(w=320, h=260):
    """Stone steps climbing from bottom-left to top-right (the thousand steps)."""
    img = canvas(w, h); d = ImageDraw.Draw(img)
    stone = (34, 38, 64, 255); stone2 = (52, 58, 92, 255); edge = (86, 240, 255, 255)
    n = 8
    for i in range(n):
        x0 = 8 + i * 36; y0 = 240 - i * 28
        d.rounded_rectangle([S(x0), S(y0), S(x0 + 90), S(y0 + 36)], radius=S(4), fill=stone, outline=INK, width=S(4))
        d.rectangle([S(x0 + 2), S(y0), S(x0 + 88), S(y0 + 8)], fill=stone2)
        d.line([(S(x0 + 4), S(y0 + 1)), (S(x0 + 86), S(y0 + 1))], fill=edge, width=S(2))
    save(img, w, h, "steps")

def cricketer(w=96, h=128):
    """A chibi cricketer in whites with a blue cap, facing right, feet at the bottom."""
    img = canvas(w, h); d = ImageDraw.Draw(img)
    white = (246, 247, 252, 255); shade = (208, 214, 236, 255); blue = (48, 92, 220, 255); skin = (244, 201, 163, 255); dark = (28, 30, 48, 255)
    # shoes
    for cx in (36, 60):
        d.ellipse([S(cx - 14), S(108), S(cx + 14), S(124)], fill=dark, outline=INK, width=S(3))
    # legs
    d.rounded_rectangle([S(28), S(76), S(68), S(114)], radius=S(8), fill=white, outline=INK, width=S(4))
    d.line([(S(48), S(80)), (S(48), S(110))], fill=shade, width=S(3))
    # body (shirt) and arms
    d.rounded_rectangle([S(22), S(50), S(74), S(86)], radius=S(12), fill=white, outline=INK, width=S(4))
    d.polygon([(S(48), S(52)), (S(38), S(66)), (S(58), S(66))], fill=blue)
    d.rectangle([S(24), S(70), S(72), S(76)], fill=blue)
    for cx in (20, 76):
        d.ellipse([S(cx - 9), S(56), S(cx + 9), S(82)], fill=white, outline=INK, width=S(4))
    # head and cap
    d.ellipse([S(26), S(12), S(70), S(56)], fill=skin, outline=INK, width=S(4))
    d.pieslice([S(24), S(8), S(72), S(52)], 180, 360, fill=blue, outline=INK, width=S(4))
    d.rounded_rectangle([S(46), S(26), S(82), S(34)], radius=S(3), fill=blue, outline=INK, width=S(3))
    d.line([(S(28), S(30)), (S(68), S(30))], fill=INK, width=S(3))
    # face (looking right)
    d.ellipse([S(50), S(36), S(56), S(42)], fill=INK); d.ellipse([S(62), S(36), S(68), S(42)], fill=INK)
    d.arc([S(52), S(40), S(66), S(50)], 20, 160, fill=INK, width=S(2))
    save(img, w, h, "cricketer")

def cricket_bat(w=40, h=120):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    wood = (226, 202, 150, 255); grip = (40, 40, 60, 255)
    d.rounded_rectangle([S(8), S(36), S(32), S(116)], radius=S(8), fill=wood, outline=INK, width=S(4))
    d.line([(S(20), S(44)), (S(20), S(108))], fill=(200, 176, 124, 255), width=S(2))
    d.rounded_rectangle([S(14), S(2), S(26), S(42)], radius=S(4), fill=grip, outline=INK, width=S(3))
    for y in (10, 18, 26, 34):
        d.line([(S(15), S(y)), (S(25), S(y))], fill=(80, 80, 110, 255), width=S(1))
    save(img, w, h, "cricket_bat")

def scorebook(w=176, h=120):
    """An open scorebook: tally marks for the losses, a ring for the wins."""
    img = canvas(w, h); d = ImageDraw.Draw(img)
    page = (245, 238, 220, 255); line = (200, 190, 168, 255); red = (226, 60, 90, 255); spine = (120, 60, 50, 255)
    d.polygon([(S(6), S(20)), (S(86), S(12)), (S(88), S(110)), (S(10), S(116))], fill=page, outline=INK)
    d.polygon([(S(90), S(12)), (S(170), S(20)), (S(166), S(116)), (S(88), S(110))], fill=page, outline=INK)
    d.line([(S(6), S(20)), (S(86), S(12)), (S(88), S(110)), (S(10), S(116)), (S(6), S(20))], fill=INK, width=S(4), joint="curve")
    d.line([(S(90), S(12)), (S(170), S(20)), (S(166), S(116)), (S(88), S(110)), (S(90), S(12))], fill=INK, width=S(4), joint="curve")
    d.line([(S(88), S(10)), (S(88), S(112))], fill=spine, width=S(4))
    for y in range(34, 104, 12):
        d.line([(S(16), S(y)), (S(78), S(y - 1))], fill=line, width=S(1))
        d.line([(S(98), S(y - 1)), (S(160), S(y))], fill=line, width=S(1))
    d.rectangle([S(16), S(22), S(52), S(28)], fill=INK)
    d.rectangle([S(98), S(22), S(128), S(28)], fill=INK)
    # 27 losses as tally groups; the win column holds one empty ring
    x = 18; y = 36
    for g in range(6):
        strokes = 5 if g < 5 else 2
        for k in range(min(strokes, 4)):
            d.line([(S(x + k * 6), S(y)), (S(x + k * 6), S(y + 18))], fill=red, width=S(2))
        if strokes == 5:
            d.line([(S(x - 2), S(y + 16)), (S(x + 22), S(y + 2))], fill=red, width=S(2))
        x += 30
        if x > 62:
            x = 18; y += 26
    d.ellipse([S(112), S(46), S(148), S(92)], outline=red, width=S(4))
    save(img, w, h, "scorebook")

def g_bat(d, Z):
    c = Z / 2
    d.rounded_rectangle([c - Z * 0.11, Z * 0.3, c + Z * 0.11, Z * 0.94], radius=Z * 0.06, fill=(255,) * 4)
    d.rounded_rectangle([c - Z * 0.05, Z * 0.04, c + Z * 0.05, Z * 0.34], radius=Z * 0.02, fill=(255,) * 4)

def g_ball(d, Z):
    c = Z / 2; r = Z * 0.4
    d.ellipse([c - r, c - r, c + r, c + r], fill=(255,) * 4)
    d.arc([c - r * 0.55, c - r * 1.25, c + r * 0.55, c + r * 1.25], 250, 290, fill=(0, 0, 0, 0), width=int(Z * 0.035))
    d.arc([c - r * 1.6, c - r * 0.9, c - r * 0.1, c + r * 0.9], 300, 60, fill=(0, 0, 0, 0), width=int(Z * 0.035))
    d.arc([c + r * 0.1, c - r * 0.9, c + r * 1.6, c + r * 0.9], 120, 240, fill=(0, 0, 0, 0), width=int(Z * 0.035))

def g_stumps(d, Z):
    for i in range(3):
        x = Z * (0.3 + i * 0.2)
        d.rounded_rectangle([x - Z * 0.045, Z * 0.2, x + Z * 0.045, Z * 0.92], radius=Z * 0.03, fill=(255,) * 4)
    d.rounded_rectangle([Z * 0.22, Z * 0.1, Z * 0.78, Z * 0.17], radius=Z * 0.02, fill=(255,) * 4)

if __name__ == "__main__":
    torii(); platform(); lantern(); pillar(); seal_ring(); mist()
    for n, f in (("blade", g_blade), ("eye", g_eye), ("mind", g_mind), ("memory", g_memory)):
        glyph(n, f)
    steps(); cricketer(); cricket_bat(); scorebook()
    for n, f in (("bat", g_bat), ("ball", g_ball), ("stumps", g_stumps)):
        glyph(n, f)
