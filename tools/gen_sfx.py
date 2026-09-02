#!/usr/bin/env python3
"""Procedurally synthesise the game's sound effects and the Shuriken Match ambient loop.
Run:  python3 tools/gen_sfx.py   -> writes sounds/gen/*.wav   (stdlib only, no numpy)"""
import math, random, struct, wave, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "sounds" / "gen"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
random.seed(7)

def write(name, samples, peak=0.7):
    m = max(1e-6, max(abs(s) for s in samples))
    k = peak / m
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))
    print("wrote", name, f"{len(samples)/SR:.2f}s")

def silence(sec): return [0.0] * int(SR * sec)

def env(i, n, attack=0.005, decay=None, curve=3.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    if decay is None: decay = n / SR
    d = math.exp(-curve * t / decay)
    return a * d

def tone(freq_fn, sec, amp=1.0, attack=0.005, curve=3.0, harmonics=((1, 1.0),), decay=None):
    n = int(SR * sec); out = []; phase = 0.0
    for i in range(n):
        f = freq_fn(i / n) if callable(freq_fn) else freq_fn
        phase += 2 * math.pi * f / SR
        s = sum(a * math.sin(phase * h) for h, a in harmonics)
        out.append(amp * s * env(i, n, attack, decay, curve))
    return out

def noise(sec, amp=1.0, attack=0.002, curve=4.0, lp=0.3, decay=None):
    n = int(SR * sec); out = []; y = 0.0
    for i in range(n):
        x = random.uniform(-1, 1)
        y += lp * (x - y)
        out.append(amp * y * env(i, n, attack, decay, curve))
    return out

def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l): out[i] += s
    return out

def seq(*parts):
    out = []
    for p in parts: out += p
    return out

def offset(samples, sec):
    return silence(sec) + samples

def sweep(f0, f1, curve=1.0):
    return lambda t: f0 + (f1 - f0) * (t ** curve)

NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)

def build():
    # UI
    write("ui_click", mix(noise(0.03, 0.5, lp=0.6), tone(sweep(1400, 900), 0.07, 0.8, curve=6)))
    write("ui_back", tone(sweep(900, 500), 0.09, 0.8, curve=5))
    # Match game
    write("swap", tone(sweep(520, 880), 0.09, 0.8, curve=4))
    write("swap_fail", mix(tone(196, 0.16, 0.6, curve=3, harmonics=((1, 1), (2, 0.4))), tone(207, 0.16, 0.6, curve=3)))
    write("match", mix(tone(880, 0.28, 0.6, curve=4), tone(1320, 0.28, 0.35, curve=5), tone(1760, 0.22, 0.2, curve=6), noise(0.02, 0.3, lp=0.8)))
    write("combo", mix(*[offset(tone(NOTE(n), 0.35, 0.5, curve=3.5, harmonics=((1, 1), (2, 0.25))), k * 0.03) for k, n in enumerate((72, 76, 79, 84))]))
    write("special_create", mix(*[offset(tone(NOTE(n), 0.22, 0.5, curve=4), k * 0.055) for k, n in enumerate((76, 80, 83, 88, 92))], noise(0.05, 0.25, lp=0.9)))
    write("line_blast", mix(noise(0.38, 1.0, lp=0.12, curve=3), tone(sweep(220, 55), 0.35, 0.8, curve=3, harmonics=((1, 1), (2, 0.3)))))
    write("burst", mix(tone(sweep(120, 40), 0.45, 1.0, curve=3, harmonics=((1, 1), (2, 0.3), (3, 0.15))), noise(0.25, 0.8, lp=0.25, curve=5)))
    prism = []
    for k in range(9):
        f = random.choice([1568, 1760, 2093, 2349, 2637, 3136])
        prism = mix(prism, offset(tone(f, 0.3, 0.35, curve=4), k * 0.05))
    write("prism", mix(prism, noise(0.6, 0.2, lp=0.9, curve=2)))
    write("tile_land", mix(noise(0.05, 0.6, lp=0.15, curve=6), tone(150, 0.05, 0.5, curve=8)))
    write("star_ding", mix(tone(1568, 0.4, 0.6, curve=3), tone(2349, 0.4, 0.3, curve=4), tone(3136, 0.3, 0.15, curve=5)))
    write("level_win", mix(*[offset(tone(NOTE(n), 0.6, 0.5, curve=2.5, harmonics=((1, 1), (2, 0.3), (3, 0.1))), k * 0.13) for k, n in enumerate((72, 76, 79, 84, 88))],
                          offset(mix(tone(NOTE(72), 1.1, 0.4, curve=2), tone(NOTE(76), 1.1, 0.35, curve=2), tone(NOTE(79), 1.1, 0.3, curve=2)), 0.7)))
    write("level_fail", seq(tone(NOTE(64), 0.22, 0.6, curve=2, harmonics=((1, 1), (3, 0.2))), tone(NOTE(63), 0.22, 0.6, curve=2, harmonics=((1, 1), (3, 0.2))), tone(NOTE(60), 0.5, 0.6, curve=2, harmonics=((1, 1), (3, 0.2)))))
    write("shuffle", mix(*[offset(noise(0.06, 0.5, lp=0.5, curve=6), k * 0.045) for k in range(6)], tone(sweep(400, 700), 0.3, 0.3, curve=2)))
    # Knife dodge
    write("hit", mix(noise(0.55, 1.0, lp=0.2, curve=3), tone(sweep(140, 28), 0.5, 1.0, curve=2.5, harmonics=((1, 1), (2, 0.4), (3, 0.2)))))
    write("near_miss", mix(tone(sweep(2200, 600, 0.6), 0.13, 0.7, curve=4), noise(0.06, 0.3, lp=0.7)))
    write("wave_start", mix(tone(110, 0.5, 0.5, attack=0.08, curve=2, harmonics=((1, 1), (2, 0.5), (3, 0.25))), tone(165, 0.5, 0.35, attack=0.1, curve=2), offset(tone(1320, 0.25, 0.35, curve=4), 0.05)))
    write("record", mix(*[offset(tone(NOTE(n), 0.5, 0.5, curve=3), k * 0.1) for k, n in enumerate((79, 84, 88, 91))]))
    write("dodge_tick", tone(sweep(1800, 1200), 0.035, 0.5, curve=8))
    # Guide voices: Animal-Crossing-style blips. Sensei is low and woody, Pip is high and bright.
    for i in range(5):
        base = 150 + i * 22
        write(f"voice_sensei_{i+1}", mix(tone(lambda t, b=base: b * (1 + 0.08 * math.sin(t * 18)), 0.075, 0.9, attack=0.004, curve=5, harmonics=((1, 1), (2, 0.5), (3, 0.25))), noise(0.02, 0.15, lp=0.4)))
        hi = 620 + i * 90
        write(f"voice_pip_{i+1}", tone(lambda t, b=hi: b * (1 + 0.15 * t), 0.055, 0.8, attack=0.003, curve=6, harmonics=((1, 1), (2, 0.3))))
    write("guide_pop", mix(noise(0.12, 0.6, lp=0.5, curve=4), tone(sweep(300, 900), 0.16, 0.6, curve=4)))
    write("guide_hop", tone(sweep(400, 800), 0.12, 0.6, curve=4))
    # Sensei Says pads: nine soft pentatonic tones (A3 up)
    penta9 = [57, 60, 62, 64, 67, 69, 72, 74, 76]
    for i, n in enumerate(penta9):
        write(f"pad_{i+1}", tone(NOTE(n), 0.32, 0.7, attack=0.01, curve=3, harmonics=((1, 1), (2, 0.35), (3, 0.12))))
    write("simon_round", mix(*[offset(tone(NOTE(n), 0.3, 0.5, curve=3), k * 0.07) for k, n in enumerate((72, 76, 79))]))
    write("simon_fail", mix(tone(sweep(220, 110), 0.5, 0.8, curve=2, harmonics=((1, 1), (2, 0.5), (3, 0.3))), noise(0.2, 0.3, lp=0.3)))
    write("simon_watch", tone(sweep(660, 880), 0.18, 0.5, curve=3))
    # Quick Draw
    write("target_spawn", tone(sweep(900, 1400), 0.06, 0.5, curve=6))
    write("target_hit", mix(tone(sweep(1200, 600), 0.09, 0.8, curve=5), noise(0.04, 0.5, lp=0.8)))
    write("target_miss", mix(noise(0.18, 0.7, lp=0.15, curve=4), tone(sweep(160, 60), 0.2, 0.6, curve=3)))
    write("decoy_hit", mix(tone(110, 0.3, 0.7, curve=2, harmonics=((1, 1), (2, 0.6), (3, 0.4), (4, 0.2))), tone(117, 0.3, 0.5, curve=2)))
    write("combo_up", mix(*[offset(tone(NOTE(n), 0.14, 0.5, curve=5), k * 0.04) for k, n in enumerate((79, 84, 88))]))
    # Boosters and rewards
    write("booster", mix(*[offset(tone(NOTE(n), 0.25, 0.45, curve=4), k * 0.05) for k, n in enumerate((72, 79, 84, 91))], noise(0.08, 0.3, lp=0.9)))
    write("ad_reward", mix(*[offset(tone(NOTE(n), 0.5, 0.45, curve=3, harmonics=((1, 1), (2, 0.3))), k * 0.09) for k, n in enumerate((67, 72, 76, 79, 84))]))
    write("hammer", mix(noise(0.2, 1.0, lp=0.3, curve=4), tone(sweep(300, 80), 0.25, 0.8, curve=3)))
    write("unlock", mix(*[offset(tone(NOTE(n), 0.4, 0.5, curve=3), k * 0.08) for k, n in enumerate((64, 71, 76, 83))]))
    # Ambient loop for Shuriken Match (seamless: all LFO periods divide the length)
    L = 24.0; n = int(SR * L); out = [0.0] * n
    def add_sine(freq, amp, lfo_period, lfo_depth, phase=0.0):
        ph = 0.0
        for i in range(n):
            t = i / SR
            ph += 2 * math.pi * freq / SR
            lfo = 1 - lfo_depth * 0.5 * (1 + math.sin(2 * math.pi * t / lfo_period + phase))
            out[i] += amp * lfo * math.sin(ph)
    add_sine(55.0, 0.22, 12.0, 0.6); add_sine(82.4, 0.14, 8.0, 0.7, 1.0); add_sine(110.0, 0.08, 6.0, 0.8, 2.0)
    add_sine(220.0, 0.05, 4.0, 0.9, 0.5); add_sine(329.6, 0.035, 3.0, 0.9, 1.5); add_sine(440.0, 0.025, 2.4, 0.9, 2.5)
    # slow filtered noise wash
    y = 0.0
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1); y += 0.02 * (x - y)
        out[i] += 0.12 * y * (0.5 + 0.5 * math.sin(2 * math.pi * t / 12.0 + 3.0))
    # soft pentatonic plucks (never within the last 1.5s so the loop point stays clean)
    penta = [57, 60, 62, 64, 67, 69, 72]
    t = 0.4
    while t < L - 1.6:
        f = NOTE(random.choice(penta))
        pl = tone(f, 1.2, 0.09, attack=0.01, curve=3.5, harmonics=((1, 1), (2, 0.2), (3, 0.05)))
        start = int(t * SR)
        for i, s in enumerate(pl):
            if start + i < n: out[start + i] += s
        t += random.choice([1.0, 1.5, 2.0, 2.5])
    write("match_loop", out, peak=0.5)

if __name__ == "__main__":
    build()
