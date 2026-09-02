#!/usr/bin/env python3
"""Generate the game's vector-style sprites as antialiased PNGs (Pillow).
Run:  python3 tools/gen_assets.py   -> writes graphics/gen/*.png
All sprites are white so Godot can tint them with `modulate`."""
import math, pathlib
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "graphics" / "gen"
OUT.mkdir(parents=True, exist_ok=True)
SS = 4  # supersampling factor for antialiasing

def canvas(w, h=None):
    h = h or w
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

def finish(img, w, h=None, name=""):
    h = h or w
    out = img.resize((w, h), Image.LANCZOS)
    out.save(OUT / f"{name}.png")
    print("wrote", name, out.size)

def star_points(cx, cy, r_out, r_in, n=4, rot=-math.pi / 2):
    pts = []
    for i in range(2 * n):
        a = rot + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def radial_shade(mask_img, size, center_bright=255, edge_bright=190):
    """RGB radial gradient (bright center) masked by mask_img's alpha."""
    S = size * SS
    grad = Image.radial_gradient("L").resize((S, S), Image.BILINEAR)
    grad = grad.point(lambda v: int(center_bright - (center_bright - edge_bright) * min(1.0, v / 255.0)))
    rgb = Image.merge("RGB", [grad, grad, grad])
    return Image.merge("RGBA", [*rgb.split(), mask_img.split()[3]])

# ---------- shuriken (match tile) ----------
def shuriken(size=192):
    img = canvas(size); d = ImageDraw.Draw(img)
    c = size * SS / 2
    # Four curved blades: build a polygon with concave sides via intermediate points
    pts = []
    n = 4; r_tip = c * 0.94; r_base = c * 0.30
    for i in range(n):
        a0 = -math.pi / 2 + i * math.pi / 2
        # tip
        pts.append((c + r_tip * math.cos(a0), c + r_tip * math.sin(a0)))
        # concave return towards the next base, sampled along a curve
        a1 = a0 + math.pi / 4
        for t in (0.25, 0.5, 0.75):
            ang = a0 + (a1 - a0) * t
            rad = r_tip + (r_base - r_tip) * (t ** 0.55)
            pts.append((c + rad * math.cos(ang), c + rad * math.sin(ang)))
        pts.append((c + r_base * math.cos(a1), c + r_base * math.sin(a1)))
        for t in (0.25, 0.5, 0.75):
            ang = a1 + (a1 - a0) * t
            rad = r_base + (r_tip - r_base) * (1 - (1 - t) ** 0.55)
            pts.append((c + rad * math.cos(ang), c + rad * math.sin(ang)))
    d.polygon(pts, fill=(255, 255, 255, 255))
    hole = c * 0.11
    d.ellipse([c - hole, c - hole, c + hole, c + hole], fill=(0, 0, 0, 0))
    shaded = radial_shade(img, size, 255, 175)
    finish(shaded, size, name="shuriken")
    # crisp inner highlight ring for a glassy look
    hl = canvas(size); dh = ImageDraw.Draw(hl)
    rr = c * 0.2
    dh.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(255, 255, 255, 160), width=int(3 * SS))
    finish(hl, size, name="shuriken_ring")

# ---------- knife dodge player star (a sharper 5-point star with glow core) ----------
def player_star(size=96):
    img = canvas(size); d = ImageDraw.Draw(img)
    c = size * SS / 2
    d.polygon(star_points(c, c, c * 0.92, c * 0.42, n=5), fill=(255, 255, 255, 255))
    shaded = radial_shade(img, size, 255, 200)
    finish(shaded, size, name="player_star")

# ---------- glow / particles ----------
def soft_disc(size, power, name):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2; steps = 160
    for i in range(steps):
        t = i / steps
        r = c * (1 - t)
        a = int(255 * (t ** power))
        d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, a))
    finish(img, size, name=name)

def ring(size=256, width=14, blur=6, name="ring"):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2; r = c * 0.86
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=width * SS)
    img = img.filter(ImageFilter.GaussianBlur(blur * SS / 2))
    finish(img, size, name=name)

def beam(w=256, h=32):
    img = canvas(w, h); d = ImageDraw.Draw(img)
    W, H = w * SS, h * SS
    for y in range(H):
        v = 1 - abs((y - H / 2) / (H / 2))
        for_x_alpha = int(255 * (v ** 1.6))
        d.line([(0, y), (W, y)], fill=(255, 255, 255, for_x_alpha))
    # fade the ends
    px = img.load()
    for x in range(W):
        e = min(x, W - 1 - x) / (W * 0.18)
        f = min(1.0, e)
        if f < 1.0:
            for y in range(H):
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, int(a * f))
    finish(img, w, h, name="beam")

# ---------- special overlays for match tiles ----------
def special_line(size=128):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2; hw = S * 0.44; hh = S * 0.055
    d.rounded_rectangle([c - hw, c - hh, c + hw, c + hh], radius=hh, fill=(255, 255, 255, 255))
    ah = S * 0.12
    d.polygon([(c - hw - ah * 0.2, c), (c - hw + ah * 0.9, c - ah), (c - hw + ah * 0.9, c + ah)], fill=(255, 255, 255, 255))
    d.polygon([(c + hw + ah * 0.2, c), (c + hw - ah * 0.9, c - ah), (c + hw - ah * 0.9, c + ah)], fill=(255, 255, 255, 255))
    finish(img, size, name="special_line_h")
    finish(img.rotate(90), size, name="special_line_v")

def special_burst(size=128):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2; r = S * 0.36
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=int(S * 0.05))
    finish(img, size, name="special_burst")

def special_prism(size=128):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2
    d.polygon(star_points(c, c, S * 0.42, S * 0.06, n=4), fill=(255, 255, 255, 230))
    d.polygon(star_points(c, c, S * 0.22, S * 0.04, n=4, rot=-math.pi / 4), fill=(255, 255, 255, 200))
    finish(img, size, name="special_prism")

# ---------- UI icons (96px, white) ----------
def icon(name, draw_fn, size=96):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS
    draw_fn(d, S)
    finish(img, size, name=f"icon_{name}")

def stroke_poly(d, pts, width, closed=False):
    d.line(pts + ([pts[0]] if closed else []), fill=(255, 255, 255, 255), width=width, joint="curve")
    for p in pts:
        d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=(255, 255, 255, 255))

def ic_pause(d, S):
    w = S * 0.16; h = S * 0.6; g = S * 0.14; c = S / 2; r = S * 0.04
    d.rounded_rectangle([c - g / 2 - w, c - h / 2, c - g / 2, c + h / 2], radius=r, fill=(255,) * 4)
    d.rounded_rectangle([c + g / 2, c - h / 2, c + g / 2 + w, c + h / 2], radius=r, fill=(255,) * 4)

def ic_play(d, S):
    c = S / 2; h = S * 0.62; w = S * 0.54
    d.polygon([(c - w / 2 + S * 0.04, c - h / 2), (c + w / 2 + S * 0.04, c), (c - w / 2 + S * 0.04, c + h / 2)], fill=(255,) * 4)

def ic_back(d, S):
    w = int(S * 0.1)
    stroke_poly(d, [(S * 0.62, S * 0.2), (S * 0.34, S * 0.5), (S * 0.62, S * 0.8)], w)

def ic_close(d, S):
    w = int(S * 0.1)
    stroke_poly(d, [(S * 0.25, S * 0.25), (S * 0.75, S * 0.75)], w)
    stroke_poly(d, [(S * 0.75, S * 0.25), (S * 0.25, S * 0.75)], w)

def ic_check(d, S):
    w = int(S * 0.11)
    stroke_poly(d, [(S * 0.2, S * 0.52), (S * 0.42, S * 0.74), (S * 0.8, S * 0.3)], w)

def ic_star(d, S):
    c = S / 2
    d.polygon(star_points(c, c * 1.04, S * 0.46, S * 0.2, n=5), fill=(255,) * 4)

def ic_gear(d, S):
    c = S / 2; teeth = 8; r_out = S * 0.46; r_in = S * 0.34
    pts = []
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        step = 2 * math.pi / teeth
        for frac, rad in ((0.0, r_in), (0.18, r_in), (0.3, r_out), (0.7, r_out), (0.82, r_in)):
            ang = a + step * frac
            pts.append((c + rad * math.cos(ang), c + rad * math.sin(ang)))
    d.polygon(pts, fill=(255,) * 4)
    h = S * 0.14
    d.ellipse([c - h, c - h, c + h, c + h], fill=(0, 0, 0, 0))

def ic_trophy(d, S):
    c = S / 2
    top = S * 0.16; cup_h = S * 0.4; cup_w = S * 0.46
    # cup body: rectangle top + elliptical bottom
    d.rectangle([c - cup_w / 2, top, c + cup_w / 2, top + cup_h * 0.6], fill=(255,) * 4)
    d.ellipse([c - cup_w / 2, top + cup_h * 0.2, c + cup_w / 2, top + cup_h], fill=(255,) * 4)
    # handles
    hw = int(S * 0.07)
    d.arc([c - cup_w / 2 - S * 0.2, top + S * 0.02, c - cup_w / 2 + S * 0.08, top + S * 0.3], 90, 270, fill=(255,) * 4, width=hw)
    d.arc([c + cup_w / 2 - S * 0.08, top + S * 0.02, c + cup_w / 2 + S * 0.2, top + S * 0.3], 270, 90, fill=(255,) * 4, width=hw)
    # stem + base
    d.rectangle([c - S * 0.06, top + cup_h - S * 0.02, c + S * 0.06, S * 0.76], fill=(255,) * 4)
    d.rounded_rectangle([c - S * 0.2, S * 0.74, c + S * 0.2, S * 0.84], radius=S * 0.03, fill=(255,) * 4)

def ic_restart(d, S):
    c = S / 2; r = S * 0.32; w = int(S * 0.1)
    d.arc([c - r, c - r, c + r, c + r], 20, 320, fill=(255,) * 4, width=w)
    # arrow head at the arc end (angle 20deg)
    a = math.radians(20)
    ex, ey = c + r * math.cos(a), c + r * math.sin(a)
    d.polygon([(ex + S * 0.02, ey - S * 0.16), (ex + S * 0.14, ey + S * 0.02), (ex - S * 0.12, ey + S * 0.04)], fill=(255,) * 4)

def ic_home(d, S):
    c = S / 2
    d.polygon([(c, S * 0.16), (S * 0.86, S * 0.5), (S * 0.74, S * 0.5), (S * 0.74, S * 0.84), (S * 0.26, S * 0.84), (S * 0.26, S * 0.5), (S * 0.14, S * 0.5)], fill=(255,) * 4)
    d.rectangle([c - S * 0.08, S * 0.6, c + S * 0.08, S * 0.84], fill=(0, 0, 0, 0))

def ic_lock(d, S):
    c = S / 2
    d.rounded_rectangle([c - S * 0.28, S * 0.44, c + S * 0.28, S * 0.84], radius=S * 0.06, fill=(255,) * 4)
    d.arc([c - S * 0.19, S * 0.14, c + S * 0.19, S * 0.56], 180, 360, fill=(255,) * 4, width=int(S * 0.08))
    d.rectangle([c - S * 0.19 - S * 0.04, S * 0.34, c - S * 0.19 + S * 0.04, S * 0.46], fill=(255,) * 4)
    d.rectangle([c + S * 0.19 - S * 0.04, S * 0.34, c + S * 0.19 + S * 0.04, S * 0.46], fill=(255,) * 4)
    d.ellipse([c - S * 0.06, S * 0.58, c + S * 0.06, S * 0.7], fill=(0, 0, 0, 0))

def ic_hint(d, S):
    # lightbulb
    c = S / 2
    d.ellipse([c - S * 0.24, S * 0.12, c + S * 0.24, S * 0.6], fill=(255,) * 4)
    d.rectangle([c - S * 0.14, S * 0.5, c + S * 0.14, S * 0.72], fill=(255,) * 4)
    d.rounded_rectangle([c - S * 0.12, S * 0.76, c + S * 0.12, S * 0.86], radius=S * 0.03, fill=(255,) * 4)

def ic_skip(d, S):
    c = S / 2; h = S * 0.5; w = S * 0.34
    d.polygon([(c - w, c - h / 2), (c + S * 0.02, c), (c - w, c + h / 2)], fill=(255,) * 4)
    d.rounded_rectangle([c + S * 0.08, c - h / 2, c + S * 0.2, c + h / 2], radius=S * 0.03, fill=(255,) * 4)

def ic_sound(d, S):
    c = S / 2
    d.polygon([(S * 0.18, S * 0.38), (S * 0.32, S * 0.38), (S * 0.5, S * 0.22), (S * 0.5, S * 0.78), (S * 0.32, S * 0.62), (S * 0.18, S * 0.62)], fill=(255,) * 4)
    w = int(S * 0.07)
    d.arc([S * 0.36, S * 0.3, S * 0.72, S * 0.7], 300, 60, fill=(255,) * 4, width=w)
    d.arc([S * 0.3, S * 0.18, S * 0.9, S * 0.82], 300, 60, fill=(255,) * 4, width=w)

def ic_moves(d, S):
    # two curved arrows (swap)
    w = int(S * 0.09); c = S / 2
    d.arc([S * 0.2, S * 0.2, S * 0.8, S * 0.8], 200, 340, fill=(255,) * 4, width=w)
    d.arc([S * 0.2, S * 0.2, S * 0.8, S * 0.8], 20, 160, fill=(255,) * 4, width=w)
    d.polygon([(S * 0.78, S * 0.28), (S * 0.86, S * 0.5), (S * 0.66, S * 0.44)], fill=(255,) * 4)
    d.polygon([(S * 0.22, S * 0.72), (S * 0.14, S * 0.5), (S * 0.34, S * 0.56)], fill=(255,) * 4)

def slider_grabber(size=40):
    img = canvas(size); d = ImageDraw.Draw(img)
    S = size * SS; c = S / 2; r = S * 0.42
    d.ellipse([c - r, c - r, c + r, c + r], fill=(255,) * 4)
    finish(img, size, name="slider_grabber")

def dagger_glow_tip(size=48):
    soft_disc(size, 1.4, "tip_glow")

if __name__ == "__main__":
    shuriken(); player_star()
    soft_disc(256, 2.2, "glow"); soft_disc(32, 1.2, "spark"); soft_disc(16, 0.6, "dot")
    ring(); beam(); special_line(); special_burst(); special_prism()
    for name, fn in [("pause", ic_pause), ("play", ic_play), ("back", ic_back), ("close", ic_close), ("check", ic_check),
                     ("star", ic_star), ("gear", ic_gear), ("trophy", ic_trophy), ("restart", ic_restart), ("home", ic_home),
                     ("lock", ic_lock), ("hint", ic_hint), ("skip", ic_skip), ("sound", ic_sound), ("moves", ic_moves)]:
        icon(name, fn)
    slider_grabber(); dagger_glow_tip()
