#!/usr/bin/env python3
"""Generate the guide characters (Sensei Kuro and Pip) as layered PNG parts.
Every part of a character is drawn on the same canvas, so in Godot each part is
a centred Sprite2D at (0,0) and they line up automatically.
Run:  python3 tools/gen_mascots.py  -> graphics/gen/mascot/*.png"""
import math, pathlib
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "graphics" / "gen" / "mascot"
OUT.mkdir(parents=True, exist_ok=True)
SS = 4
INK = (12, 13, 24, 255)

def canvas(size): return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
def save(img, size, name):
    img.resize((size, size), Image.LANCZOS).save(OUT / f"{name}.png"); print("wrote", name)
def S(v): return v * SS

def outlined_ellipse(d, box, fill, width=7, outline=INK):
    d.ellipse([S(b) for b in box], fill=fill, outline=outline, width=S(width))

def rounded_poly(d, pts, fill, width=7, outline=INK):
    pts = [(S(x), S(y)) for x, y in pts]
    d.polygon(pts, fill=outline)
    d.line(pts + [pts[0]], fill=outline, width=S(width) * 2, joint="curve")
    for p in pts:
        d.ellipse([p[0] - S(width), p[1] - S(width), p[0] + S(width), p[1] + S(width)], fill=outline)
    # inner fill: shrink polygon toward centroid by width
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    inner = []
    for x, y in pts:
        vx, vy = x - cx, y - cy; L = math.hypot(vx, vy) or 1
        inner.append((x - vx / L * S(width) * 1.4, y - vy / L * S(width) * 1.4))
    d.polygon(inner, fill=fill)
    d.line(inner + [inner[0]], fill=fill, width=int(S(width) * 0.9), joint="curve")

def star_pts(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    out = []
    for i in range(2 * n):
        a = rot + math.pi * i / n; r = ro if i % 2 == 0 else ri
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out

def stroke(d, pts, width, color=INK):
    pts = [(S(x), S(y)) for x, y in pts]
    d.line(pts, fill=color, width=S(width), joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - S(width) / 2, p[1] - S(width) / 2, p[0] + S(width) / 2, p[1] + S(width) / 2], fill=color)

def arc_stroke(d, box, start, end, width, color=INK):
    d.arc([S(b) for b in box], start, end, fill=color, width=S(width))

# ------------------------------------------------------------------ Sensei Kuro (320 canvas)
SZ = 320
NAVY = (27, 31, 51, 255); NAVY2 = (42, 48, 80, 255); SKIN = (244, 201, 163, 255); RED = (226, 60, 90, 255)
WHITE = (250, 250, 255, 255); PINK = (255, 150, 150, 140)

BLUE = (59, 108, 255, 255)

def young_body():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    outlined_ellipse(d, (118, 272, 158, 296), NAVY); outlined_ellipse(d, (162, 272, 202, 296), NAVY)
    rounded_poly(d, [(112, 200), (208, 200), (226, 286), (94, 286)], NAVY)
    d.polygon([(S(160), S(206)), (S(132), S(262)), (S(160), S(250))], fill=NAVY2)
    d.polygon([(S(160), S(206)), (S(188), S(262)), (S(160), S(250))], fill=NAVY2)
    d.rounded_rectangle([S(102), S(246), S(218), S(262)], radius=S(6), fill=BLUE, outline=INK, width=S(4))
    d.rectangle([S(150), S(246), S(170), S(262)], fill=(40, 70, 190, 255))
    outlined_ellipse(d, (62, 36, 258, 236), NAVY)
    d.polygon([(S(150), S(48)), (S(160), S(14)), (S(178), S(50))], fill=NAVY, outline=INK)
    stroke(d, [(150, 48), (160, 14), (178, 50)], 6)
    outlined_ellipse(d, (84, 70, 236, 222), SKIN)
    d.rounded_rectangle([S(86), S(92), S(234), S(112)], radius=S(8), fill=BLUE, outline=INK, width=S(4))
    d.ellipse([S(104), S(158), S(128), S(176)], fill=PINK); d.ellipse([S(192), S(158), S(216), S(176)], fill=PINK)
    outlined_ellipse(d, (152, 162, 168, 176), SKIN, width=3)
    save(img, SZ, "young_body")

def young_brows():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    for cx, tilt in ((132, 6), (188, -6)):
        stroke(d, [(cx - 15, 116 + tilt * 0.4), (cx + 15, 116 - tilt * 0.4)], 8, INK)
    save(img, SZ, "young_brows")

def young_tails():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    for dy, amp in ((0, 10), (10, -8)):
        pts = [(90 + i * -9, 102 + dy + amp * math.sin(i * 0.9)) for i in range(9)]
        stroke(d, pts, 16); stroke(d, pts, 9, BLUE)
    save(img, SZ, "young_tails")

def sensei_body():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    # feet
    outlined_ellipse(d, (118, 272, 158, 296), NAVY); outlined_ellipse(d, (162, 272, 202, 296), NAVY)
    # body (gi)
    rounded_poly(d, [(112, 200), (208, 200), (226, 286), (94, 286)], NAVY)
    # gi lapels
    d.polygon([(S(160), S(206)), (S(132), S(262)), (S(160), S(250))], fill=NAVY2)
    d.polygon([(S(160), S(206)), (S(188), S(262)), (S(160), S(250))], fill=NAVY2)
    # belt
    d.rounded_rectangle([S(102), S(246), S(218), S(262)], radius=S(6), fill=RED, outline=INK, width=S(4))
    d.rectangle([S(150), S(246), S(170), S(262)], fill=(180, 40, 70, 255))
    # hood
    outlined_ellipse(d, (62, 36, 258, 236), NAVY)
    d.polygon([(S(150), S(48)), (S(160), S(14)), (S(178), S(50))], fill=NAVY, outline=INK)
    stroke(d, [(150, 48), (160, 14), (178, 50)], 6)
    # face
    outlined_ellipse(d, (84, 70, 236, 222), SKIN)
    # headband
    d.rounded_rectangle([S(86), S(92), S(234), S(112)], radius=S(8), fill=RED, outline=INK, width=S(4))
    # cheeks
    d.ellipse([S(104), S(158), S(128), S(176)], fill=PINK); d.ellipse([S(192), S(158), S(216), S(176)], fill=PINK)
    # moustache + beard
    arc_stroke(d, (118, 164, 160, 192), 200, 340, 7, WHITE); arc_stroke(d, (160, 164, 202, 192), 200, 340, 7, WHITE)
    rounded_poly(d, [(134, 216), (186, 216), (160, 258)], WHITE, width=4)
    # nose
    outlined_ellipse(d, (152, 162, 168, 176), SKIN, width=3)
    save(img, SZ, "sensei_body")

def sensei_eyes(state):
    img = canvas(SZ); d = ImageDraw.Draw(img)
    for cx in (132, 188):
        if state == "open":
            outlined_ellipse(d, (cx - 12, 124, cx + 12, 154), INK, width=1)
            d.ellipse([S(cx - 7), S(129), S(cx - 1), S(135)], fill=WHITE)
        elif state == "closed":
            arc_stroke(d, (cx - 13, 128, cx + 13, 150), 200, 340, 5)
        elif state == "happy":
            arc_stroke(d, (cx - 13, 132, cx + 13, 154), 200, 340, 6)
    save(img, SZ, f"sensei_eyes_{state}")

def sensei_brows():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    for cx, tilt in ((132, 8), (188, -8)):
        pts = [(cx - 16, 118 + tilt * 0.4), (cx + 16, 118 - tilt * 0.4)]
        stroke(d, pts, 12, WHITE); stroke(d, pts, 12, WHITE)
    save(img, SZ, "sensei_brows")

def sensei_mouth(state):
    img = canvas(SZ); d = ImageDraw.Draw(img)
    if state == "closed":
        arc_stroke(d, (147, 190, 173, 208), 10, 170, 5)
    elif state == "open":
        outlined_ellipse(d, (151, 194, 169, 212), (90, 30, 40, 255), width=3)
    elif state == "wide":
        d.chord([S(142), S(188), S(178), S(216)], 0, 180, fill=(90, 30, 40, 255), outline=INK, width=S(3))
        d.rectangle([S(148), S(200), S(172), S(204)], fill=WHITE)
    save(img, SZ, f"sensei_mouth_{state}")

def sensei_tails():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    for dy, amp in ((0, 10), (10, -8)):
        pts = [(90 + i * -9, 102 + dy + amp * math.sin(i * 0.9)) for i in range(9)]
        stroke(d, pts, 16); stroke(d, pts, 9, RED)
    save(img, SZ, "sensei_tails")

def sensei_arm():
    img = canvas(SZ); d = ImageDraw.Draw(img)
    # drawn pointing right from the shoulder at (214, 224)
    stroke(d, [(214, 224), (276, 224)], 30); stroke(d, [(214, 224), (276, 224)], 20, NAVY)
    outlined_ellipse(d, (268, 208, 300, 240), SKIN, width=4)
    stroke(d, [(292, 224), (314, 224)], 12); stroke(d, [(292, 224), (314, 224)], 6, SKIN)
    save(img, SZ, "sensei_arm")

# ------------------------------------------------------------------ Pip (240 canvas)
PZ = 240
GOLD = (255, 216, 77, 255); GOLD2 = (255, 240, 170, 255); AMBER = (122, 74, 0, 255)

def pip_body():
    img = canvas(PZ); d = ImageDraw.Draw(img)
    pts = star_pts(120, 128, 104, 50)
    rounded_poly(d, pts, GOLD, width=6, outline=AMBER)
    # soft highlight
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0)); hd = ImageDraw.Draw(hl)
    hd.ellipse([S(80), S(80), S(160), S(150)], fill=(255, 245, 200, 110))
    hl = hl.filter(ImageFilter.GaussianBlur(S(6)))
    mask = Image.new("L", img.size, 0); ImageDraw.Draw(mask).polygon([(S(x), S(y)) for x, y in pts], fill=255)
    img.paste(Image.alpha_composite(img, hl), (0, 0), mask)
    # cheeks
    d = ImageDraw.Draw(img)
    d.ellipse([S(84), S(138), S(106), S(154)], fill=(255, 130, 120, 150)); d.ellipse([S(134), S(138), S(156), S(154)], fill=(255, 130, 120, 150))
    save(img, PZ, "pip_body")

def pip_eyes(state):
    img = canvas(PZ); d = ImageDraw.Draw(img)
    for cx in (100, 140):
        if state == "open":
            outlined_ellipse(d, (cx - 11, 104, cx + 11, 134), INK, width=1)
            d.ellipse([S(cx - 6), S(109), S(cx), S(115)], fill=WHITE)
            d.ellipse([S(cx + 2), S(124), S(cx + 5), S(127)], fill=WHITE)
        elif state == "closed":
            arc_stroke(d, (cx - 12, 110, cx + 12, 130), 200, 340, 5)
        elif state == "happy":
            arc_stroke(d, (cx - 12, 114, cx + 12, 136), 200, 340, 6)
    save(img, PZ, f"pip_eyes_{state}")

def pip_mouth(state):
    img = canvas(PZ); d = ImageDraw.Draw(img)
    if state == "closed":
        arc_stroke(d, (108, 140, 132, 158), 10, 170, 5)
    elif state == "open":
        outlined_ellipse(d, (112, 146, 128, 162), (120, 40, 50, 255), width=3)
    elif state == "wide":
        d.chord([S(100), S(136), S(140), S(170)], 0, 180, fill=(120, 40, 50, 255), outline=INK, width=S(3))
        d.chord([S(108), S(152), S(132), S(170)], 180, 360, fill=(255, 120, 130, 255))
    save(img, PZ, f"pip_mouth_{state}")

def pip_sparkle():
    img = canvas(PZ); d = ImageDraw.Draw(img)
    d.polygon([(S(x), S(y)) for x, y in star_pts(196, 62, 26, 7, n=4)], fill=WHITE)
    d.polygon([(S(x), S(y)) for x, y in star_pts(40, 96, 14, 4, n=4)], fill=WHITE)
    save(img, PZ, "pip_sparkle")

def shadow():
    img = canvas(PZ); d = ImageDraw.Draw(img)
    d.ellipse([S(30), S(100), S(210), S(140)], fill=(0, 0, 0, 120))
    img = img.filter(ImageFilter.GaussianBlur(S(6)))
    save(img, PZ, "mascot_shadow")

if __name__ == "__main__":
    sensei_body(); sensei_brows(); sensei_tails(); sensei_arm()
    young_body(); young_brows(); young_tails()
    for st in ("open", "closed", "happy"): sensei_eyes(st); pip_eyes(st)
    for st in ("closed", "open", "wide"): sensei_mouth(st); pip_mouth(st)
    pip_body(); pip_sparkle(); shadow()
    # preview sheet: composed characters on the void
    sheet = Image.new("RGBA", (1100, 420), (7, 8, 13, 255))
    def compose(names, size, at):
        base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        for n in names:
            base.alpha_composite(Image.open(OUT / f"{n}.png"))
        sheet.alpha_composite(base, at)
    compose(["sensei_tails", "sensei_body", "sensei_arm", "sensei_brows", "sensei_eyes_open", "sensei_mouth_closed"], 320, (20, 40))
    compose(["sensei_tails", "sensei_body", "sensei_brows", "sensei_eyes_happy", "sensei_mouth_wide"], 320, (330, 40))
    compose(["pip_body", "pip_eyes_open", "pip_mouth_closed"], 240, (660, 80))
    compose(["pip_body", "pip_eyes_happy", "pip_mouth_wide", "pip_sparkle"], 240, (880, 80))
    prev = pathlib.Path("/private/tmp/claude-501/-Users-karanvirkhanna-game-ninja/202e7b2e-05e8-4257-954b-aed21144acb5/scratchpad/mascots_preview.png")
    sheet.save(prev); print(prev)
