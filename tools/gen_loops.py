#!/usr/bin/env python3
"""Synthesise the 20 loops for The Loop Room, the Yard's music game.

The whole point is that any subset of these can play at once and still sound like music,
so every loop is written to one grid: 80 BPM, 4/4, two bars, A minor pentatonic. Each
file is exactly LOOP seconds, every partial is snapped so a whole number of cycles fits,
and the game starts them all together - so they stay phase-locked however many are on.

Levels are kept low on purpose (-26 LUFS): twenty layers sum, and the player is the one
deciding how many. See [[audio-loudness-preference]] for why nothing here is bright.

Run:  python3 tools/gen_loops.py   -> writes sounds/gen/loop_*.wav
      (stdlib only; ffmpeg, if installed, is used to measure loudness)"""
import json, math, random, struct, subprocess, wave, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "sounds" / "gen"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
BPM = 80.0
BEAT = 60.0 / BPM          # 0.75 s
BAR = BEAT * 4             # 3.0 s
LOOP = BAR * 2             # 6.0 s - every file is exactly this long
N = int(SR * LOOP)
STEP = BEAT / 4            # a sixteenth
TARGET_LUFS = -26.0
CEILING = 0.85   # percussive loops are peak-limited before they reach the LUFS target

NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)
# A minor pentatonic, low to high. Anything drawn from this stacks without dissonance.
PENTA = [45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76, 79]


def lock(freq):
	"""Snap a frequency so a whole number of cycles fits the loop (no click at the seam)."""
	return max(1, round(freq * LOOP)) / LOOP


def buf():
	return [0.0] * N


def put(b, start, samples, gain=1.0):
	"""Add a one-shot at a beat position, wrapping past the end so tails stay seamless."""
	s0 = int(start * SR)
	for i, v in enumerate(samples):
		b[(s0 + i) % N] += v * gain


def env(i, n, attack, decay, curve=3.0):
	t = i / SR
	return (min(1.0, t / attack) if attack > 0 else 1.0) * math.exp(-curve * t / decay)


def pluck(freq, dur, amp, attack=0.004, curve=3.0, harm=((1, 1.0), (2, 0.3), (3, 0.1))):
	n = int(SR * dur)
	step = 2 * math.pi * freq / SR
	return [amp * env(i, n, attack, dur, curve) * sum(a * math.sin(step * i * h) for h, a in harm)
	        for i in range(n)]


def hit(dur, amp, lp, attack=0.001, curve=6.0, tone_f=0.0):
	"""Filtered noise, optionally with a pitched body under it - drums and shakers."""
	n = int(SR * dur)
	out, y, ph = [], 0.0, 0.0
	for i in range(n):
		y += lp * (random.uniform(-1, 1) - y)
		v = y
		if tone_f:
			ph += 2 * math.pi * tone_f * (1 + 0.6 * math.exp(-24 * i / SR)) / SR
			v = v * 0.4 + math.sin(ph) * 0.9
		out.append(amp * v * env(i, n, attack, dur, curve))
	return out


def drone(b, freq, amp, lfo_bars=2.0, depth=0.4, phase=0.0, harm=((1, 1.0),)):
	f = lock(freq)
	step = 2 * math.pi * f / SR
	w = 2 * math.pi / (lfo_bars * BAR)
	for i in range(N):
		s = sum(a * math.sin(step * i * h) for h, a in harm)
		b[i] += amp * s * (1 - depth * 0.5 * (1 + math.sin(w * i / SR + phase)))


def wash(b, amp, lp, lfo_bars=2.0, depth=0.5, phase=0.0, xfade=0.75):
	"""Loop-safe filtered noise: generated long, then wrap-crossfaded onto its own tail."""
	m = int(xfade * SR)
	raw, y = [0.0] * (N + m), 0.0
	for i in range(N + m):
		y += lp * (random.uniform(-1, 1) - y)
		raw[i] = y
	for i in range(m):
		k = i / m
		raw[i] = raw[i] * k + raw[N + i] * (1 - k)
	w = 2 * math.pi / (lfo_bars * BAR)
	for i in range(N):
		b[i] += amp * raw[i] * (1 - depth * 0.5 * (1 + math.sin(w * i / SR + phase)))


# ------------------------------------------------------------------ output

def _lufs(path):
	try:
		p = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
		                    "-af", "loudnorm=print_format=summary", "-f", "null", "-"],
		                   capture_output=True, text=True, timeout=120)
	except (OSError, subprocess.SubprocessError):
		return None
	for line in p.stderr.splitlines():
		if "Input Integrated" in line:
			return float(line.split(":")[1].strip().split()[0])
	return None


def _save(path, samples, gain):
	with wave.open(str(path), "wb") as w:
		w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
		w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
		                       for s in samples))


def write(name, samples):
	path = OUT / f"loop_{name}.wav"
	peak = max(1e-6, max(abs(s) for s in samples))
	gain = CEILING / peak
	_save(path, samples, gain)
	m = _lufs(path)
	if m is None:
		print(f"wrote loop_{name}  (ffmpeg missing - loudness NOT matched)")
		return
	_save(path, samples, min(gain * 10 ** ((TARGET_LUFS - m) / 20.0), CEILING / peak))
	print(f"wrote loop_{name:<10} {LOOP:.1f}s  {m:+.1f} -> {_lufs(path):+.1f} LUFS")


# ------------------------------------------------------------------ the 20 loops
# Each returns a full-length buffer. Positions are in seconds on the shared grid, so
# `2 * BEAT` is beat three of bar one and `BAR + BEAT` is beat two of bar two.

def steps(pattern):
	"""'x..x' style sixteenth grid -> the beat positions of each hit."""
	return [i * STEP for i, c in enumerate(pattern) if c == "x"]


def L_heart():          # 1 - slow kick on the pulse
	b = buf()
	for t in steps("x.......x.......x.......x......."):
		put(b, t, hit(0.45, 1.0, 0.06, curve=4.0, tone_f=52))
	return b

def L_taiko():          # 2 - soft taiko backbeat
	b = buf()
	for t in steps("....x.......x.......x.......x..."):
		put(b, t, hit(0.30, 0.75, 0.22, curve=5.0, tone_f=96))
	return b

def L_shaker():         # 3 - sixteenth shaker
	b = buf()
	for i, t in enumerate(steps("x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.")):
		put(b, t, hit(0.07, 0.30 if i % 2 else 0.45, 0.55, curve=9.0))
	return b

def L_rim():            # 4 - offbeat rim tick
	b = buf()
	for t in steps("..x...x...x...x...x...x...x...x."):
		put(b, t, hit(0.05, 0.5, 0.7, curve=12.0, tone_f=900))
	return b

def L_frame():          # 5 - hand-drum triplet feel
	b = buf()
	for t in steps("x..x..x...x..x..x..x...x..x.x..."):
		put(b, t, hit(0.16, 0.55, 0.30, curve=7.0, tone_f=150))
	return b

def L_sub():            # 6 - root sub bass
	b = buf()
	drone(b, NOTE(33), 0.55, 2.0, 0.25)
	return b

def L_bass():           # 7 - moving bass line
	b = buf()
	for t, n in [(0, 33), (1.5 * BEAT, 40), (3 * BEAT, 36), (BAR, 33), (BAR + 2 * BEAT, 38), (BAR + 3 * BEAT, 40)]:
		put(b, t, pluck(NOTE(n), 0.7, 0.7, 0.01, 2.4, ((1, 1.0), (2, 0.18))))
	return b

def L_fifth():          # 8 - pulsing fifth under everything
	b = buf()
	drone(b, NOTE(40), 0.38, 1.0, 0.75)
	return b

def L_pad_warm():       # 9
	b = buf()
	drone(b, NOTE(45), 0.30, 2.0, 0.35)
	drone(b, NOTE(52), 0.20, 2.0, 0.45, 1.2)
	drone(b, NOTE(57), 0.13, 1.0, 0.55, 2.4)
	return b

def L_pad_air():        # 10
	b = buf()
	drone(b, NOTE(64), 0.10, 1.0, 0.7, 0.5, ((1, 1.0), (2, 0.15)))
	drone(b, NOTE(67), 0.07, 2.0, 0.8, 1.7)
	wash(b, 0.05, 0.10, 2.0, 0.6)
	return b

def L_drone_low():      # 11
	b = buf()
	drone(b, NOTE(28), 0.55, 2.0, 0.2)
	drone(b, NOTE(35), 0.22, 2.0, 0.4, 1.0)
	return b

def L_choir():          # 12 - breathy stacked fifths
	b = buf()
	for n, a, ph in ((57, 0.20, 0.0), (64, 0.14, 1.1), (69, 0.09, 2.2)):
		drone(b, NOTE(n), a, 2.0, 0.6, ph, ((1, 1.0), (2, 0.22), (3, 0.08)))
	wash(b, 0.04, 0.06, 2.0, 0.5, 1.0)
	return b

def L_koto():           # 13 - plucked pentatonic phrase
	b = buf()
	for t, n in [(0, 57), (BEAT, 60), (2 * BEAT, 64), (3.5 * BEAT, 62),
	             (BAR, 57), (BAR + 1.5 * BEAT, 55), (BAR + 3 * BEAT, 52)]:
		put(b, t, pluck(NOTE(n), 0.9, 0.45, 0.005, 3.2))
	return b

def L_bell():           # 14 - sparse high bell
	b = buf()
	for t, n in [(BEAT, 69), (2.5 * BEAT, 72), (BAR + BEAT, 76), (BAR + 3 * BEAT, 69)]:
		put(b, t, pluck(NOTE(n), 2.0, 0.30, 0.03, 2.0, ((1, 1.0), (2.7, 0.12))))
	return b

def L_box():            # 15 - music box figure
	b = buf()
	for i, n in enumerate([69, 72, 76, 72, 69, 67, 69, 72]):
		put(b, i * BEAT, pluck(NOTE(n), 0.8, 0.22, 0.003, 3.6, ((1, 1.0), (2, 0.35), (4, 0.08))))
	return b

def L_marimba():        # 16 - rolling eighths
	b = buf()
	for i, n in enumerate([57, 60, 64, 60, 62, 64, 67, 64, 57, 60, 64, 67, 69, 67, 64, 60]):
		put(b, i * BEAT / 2, pluck(NOTE(n), 0.45, 0.22, 0.003, 4.5, ((1, 1.0), (4, 0.2))))
	return b

def L_harp():           # 17 - rising arpeggio
	b = buf()
	for i, n in enumerate([45, 52, 57, 64, 69, 76, 69, 64, 57, 52, 57, 64, 69, 64, 57, 52]):
		put(b, i * BEAT / 2, pluck(NOTE(n), 0.7, 0.18, 0.004, 3.0))
	return b

def L_rain():           # 18
	b = buf()
	wash(b, 0.30, 0.05, 2.0, 0.4)
	wash(b, 0.12, 0.18, 1.0, 0.6, 1.0)
	return b

def L_wind():           # 19
	b = buf()
	wash(b, 0.40, 0.012, 2.0, 0.7)
	wash(b, 0.10, 0.04, 2.0, 0.5, 2.0)
	return b

def L_shimmer():        # 20
	b = buf()
	for n, a, ph in ((76, 0.06, 0.0), (79, 0.045, 1.4), (84, 0.03, 2.8)):
		drone(b, NOTE(n), a, 0.5, 0.9, ph)
	return b


LOOPS = [
	("heart", L_heart), ("taiko", L_taiko), ("shaker", L_shaker), ("rim", L_rim),
	("frame", L_frame), ("sub", L_sub), ("bass", L_bass), ("fifth", L_fifth),
	("padwarm", L_pad_warm), ("padair", L_pad_air), ("dronelow", L_drone_low),
	("choir", L_choir), ("koto", L_koto), ("bell", L_bell), ("box", L_box),
	("marimba", L_marimba), ("harp", L_harp), ("rain", L_rain), ("wind", L_wind),
	("shimmer", L_shimmer),
]


def build():
	print(f"{BPM:.0f} BPM, {LOOP:.1f} s loops ({N} samples at {SR} Hz), A minor pentatonic")
	for i, (name, fn) in enumerate(LOOPS):
		random.seed(1000 + i)
		write(name, fn())
	print(f"{len(LOOPS)} loops")


if __name__ == "__main__":
	build()
