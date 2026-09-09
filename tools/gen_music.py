#!/usr/bin/env python3
"""Synthesise the calm background-music beds behind the Settings > Music vibe picker.

Every bed is a seamless 24 s loop: partials are snapped so a whole number of cycles
fits the loop, LFO periods divide it, and one-shot events wrap around the end.
Beds are deliberately dark - the energy sits under ~1 kHz, where long listening does
not fatigue - and each one is loudness-matched so switching vibe never jumps in level.

Run:  python3 tools/gen_music.py   -> writes sounds/gen/<vibe>_{calm,play}.wav
      (stdlib only; ffmpeg, if installed, is used to measure loudness)"""
import json, math, random, struct, subprocess, wave, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "sounds" / "gen"
OUT.mkdir(parents=True, exist_ok=True)
SR = 11025          # these beds carry nothing above ~4 kHz, so half rate costs nothing
L = 24.0            # loop length; 2/3/4/6/8/12 s LFOs all divide it
N = int(SR * L)
TARGET_LUFS = -24.0  # matches story_theme, ~9 dB below the old menu track
CEILING = 0.6

NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)


def lock(freq):
	"""Snap a frequency so an exact number of cycles fits the loop (no click at the seam)."""
	return max(1, round(freq * L)) / L


def buffer():
	return [0.0] * N


def pad(buf, freq, amp, lfo_period=12.0, lfo_depth=0.5, phase=0.0, harmonics=((1, 1.0),)):
	"""A breathing sine stack. Both the partials and the LFO are loop-locked."""
	f = lock(freq)
	step = 2 * math.pi * f / SR
	lfo_w = 2 * math.pi / lfo_period
	for i in range(N):
		t = i / SR
		ph = step * i
		s = sum(a * math.sin(ph * h) for h, a in harmonics)
		buf[i] += amp * s * (1 - lfo_depth * 0.5 * (1 + math.sin(lfo_w * t + phase)))


def wash(buf, amp, lp, lfo_period=12.0, lfo_depth=0.5, phase=0.0, xfade=2.0):
	"""One-pole low-passed noise, wrap-crossfaded so the loop point is inaudible."""
	m = int(xfade * SR)
	raw = [0.0] * (N + m)
	y = 0.0
	for i in range(N + m):
		y += lp * (random.uniform(-1, 1) - y)
		raw[i] = y
	for i in range(m):
		w = i / m
		raw[i] = raw[i] * w + raw[N + i] * (1 - w)
	lfo_w = 2 * math.pi / lfo_period
	for i in range(N):
		buf[i] += amp * raw[i] * (1 - lfo_depth * 0.5 * (1 + math.sin(lfo_w * i / SR + phase)))


def hit(buf, start, samples, gain=1.0):
	"""Add a one-shot, wrapping past the end so its tail lands back at the top."""
	s0 = int(start * SR)
	for i, v in enumerate(samples):
		buf[(s0 + i) % N] += v * gain


def bell(freq, dur, amp, attack=0.04, curve=2.6, harmonics=((1, 1.0), (2, 0.14))):
	"""A soft struck tone: slow attack, long exponential tail, almost no upper partials."""
	n = int(SR * dur)
	step = 2 * math.pi * freq / SR
	out = []
	for i in range(n):
		t = i / SR
		e = min(1.0, t / attack) * math.exp(-curve * t / dur)
		out.append(amp * e * sum(a * math.sin(step * i * h) for h, a in harmonics))
	return out


def thump(freq, dur, amp, curve=3.2):
	"""A rounded sub-bass pulse - felt more than heard."""
	n = int(SR * dur)
	out = []
	ph = 0.0
	for i in range(n):
		t = i / SR
		f = freq * (1 + 0.5 * math.exp(-18 * t))   # tiny downward bend, like a soft mallet
		ph += 2 * math.pi * f / SR
		out.append(amp * math.sin(ph) * min(1.0, t / 0.012) * math.exp(-curve * t / dur))
	return out


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


def write(name, samples, target=TARGET_LUFS):
	"""Write, measure, then rewrite at the shared target loudness."""
	path = OUT / f"{name}.wav"
	peak = max(1e-6, max(abs(s) for s in samples))
	gain = CEILING / peak
	_save(path, samples, gain)
	measured = _lufs(path)
	if measured is None:
		print(f"wrote {name}  (ffmpeg not available - loudness NOT matched)")
		return
	gain = min(gain * 10 ** ((target - measured) / 20.0), CEILING / peak)
	_save(path, samples, gain)
	print(f"wrote {name}  {L:.0f}s  {measured:+.1f} -> {_lufs(path):+.1f} LUFS")


# ------------------------------------------------------------------ the vibes

def drift(playing):
	"""DRIFT - weightless warm pads over a low A drone. The quietest of the three."""
	buf = buffer()
	pad(buf, NOTE(33), 0.22, 24.0, 0.35)                 # A1
	pad(buf, NOTE(40), 0.130, 12.0, 0.50, 1.0)           # E2
	pad(buf, NOTE(45), 0.085, 8.0, 0.60, 2.0)            # A2
	pad(buf, NOTE(52), 0.045, 6.0, 0.70, 0.5)            # E3
	pad(buf, NOTE(57), 0.030, 4.0, 0.80, 1.5, ((1, 1.0), (2, 0.12)))
	pad(buf, NOTE(64), 0.016, 3.0, 0.85, 2.5)            # E4, barely there
	wash(buf, 0.10, 0.02, 12.0, 0.6)
	wash(buf, 0.04, 0.08, 8.0, 0.7, 2.0)
	penta = [57, 60, 62, 64, 67]                          # A minor pentatonic
	t, gaps = 0.6, ([2.5, 3.0, 4.0] if playing else [3.5, 4.5, 6.0])
	while t < L:
		buf_note = NOTE(random.choice(penta))
		hit(buf, t, bell(buf_note, 4.0, 0.06 if playing else 0.055))
		t += random.choice(gaps)
	if playing:
		pad(buf, NOTE(47), 0.035, 6.0, 0.6, 3.0)          # a touch more mid to sit under play
		for k in range(6):
			hit(buf, k * 4.0, thump(52.0, 1.4, 0.22))
	return buf


def rain(playing):
	"""RAIN - dojo rain and wind, with a distant temple bell. No melody at all."""
	buf = buffer()
	wash(buf, 0.130, 0.008, 24.0, 0.4)                    # rumble
	wash(buf, 0.200, 0.05, 12.0, 0.5, 0.0)                # body of the rain
	wash(buf, 0.090, 0.16, 8.0, 0.7, 1.0)                 # patter
	wash(buf, 0.035, 0.40, 6.0, 0.8, 2.0)                 # fine hiss, kept low on purpose
	pad(buf, NOTE(33), 0.10, 24.0, 0.4)
	pad(buf, NOTE(40), 0.05, 12.0, 0.6, 1.5)
	for k in range(3):
		hit(buf, 1.5 + k * 8.0, bell(NOTE(45 if k % 2 == 0 else 52), 6.0, 0.05, attack=0.08, curve=2.2))
	if playing:
		wash(buf, 0.06, 0.10, 4.0, 0.8, 0.5)
		pad(buf, NOTE(45), 0.045, 8.0, 0.6, 2.5)
		for k in range(8):
			hit(buf, k * 3.0, thump(48.0, 1.6, 0.20))
	return buf


def pulse(playing):
	"""PULSE - a slow warm heartbeat on a low B. Keeps momentum without any bright mids."""
	buf = buffer()
	pad(buf, NOTE(28), 0.20, 24.0, 0.35)                  # E1
	pad(buf, NOTE(35), 0.110, 12.0, 0.50, 1.0)            # B1
	pad(buf, NOTE(47), 0.050, 8.0, 0.65, 2.0)             # B2
	pad(buf, NOTE(54), 0.028, 6.0, 0.75, 0.5)             # F#3
	wash(buf, 0.07, 0.04, 12.0, 0.6)
	beat = 1.2 if playing else 1.5
	amp = 0.55 if playing else 0.45
	for k in range(int(L / beat)):
		hit(buf, k * beat, thump(58.0, beat * 0.75, amp * (1.0 if k % 4 == 0 else 0.72)))
	for k in range(4):
		hit(buf, 2.0 + k * 6.0, bell(NOTE(59), 5.0, 0.032, attack=0.12, curve=2.0))
	if playing:
		pad(buf, NOTE(59), 0.018, 3.0, 0.85, 1.5)         # faint shimmer
	return buf


RAW = OUT.parent / "raw"          # originals, hidden from the engine by raw/.gdignore
SOFT_CHAIN = ("equalizer=f=3200:t=q:w=1.1:g=-6,equalizer=f=5200:t=q:w=1.3:g=-4,"
              "lowpass=f=8000,acompressor=threshold=0.08:ratio=3:attack=20:release=400")


def soften(src, dest, target=TARGET_LUFS):
	"""Re-render a licensed track for the CLASSIC vibe.

	The music box shipped at -14.9 LUFS with a -1.2 dBTP peak - about 10 dB hotter than
	every other track and heavy through 1-5 kHz, on a 23 s loop behind every menu. Two
	bells tame that band, a gentle compressor rounds off the strikes, and a two-pass
	loudnorm lands it on the same target as the synthesised beds."""
	src, dest = RAW / src, OUT.parent / dest
	if not src.exists():
		print(f"skip {dest.name} - no {src}")
		return
	probe = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), "-af",
	                        f"{SOFT_CHAIN},loudnorm=I={target}:TP=-3:LRA=6:print_format=json",
	                        "-f", "null", "-"], capture_output=True, text=True)
	m = json.loads(probe.stderr[probe.stderr.rindex("{"):probe.stderr.rindex("}") + 1])
	subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-af",
	                f"{SOFT_CHAIN},loudnorm=I={target}:TP=-3:LRA=6:linear=true"
	                f":measured_I={m['input_i']}:measured_TP={m['input_tp']}"
	                f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
	                f":offset={m['target_offset']}",
	                "-c:a", "libmp3lame", "-q:a", "5", "-ac", "1", "-ar", "44100", str(dest)],
	               check=True)
	print(f"wrote {dest.name}  {float(m['input_i']):+.1f} -> {_lufs(dest):+.1f} LUFS")


def build():
	soften("Music Box Game Over 2.mp3", "music_box_soft.mp3")
	# Fixed seeds, not hash(name): Python salts string hashing per process, so that would
	# quietly re-roll every pluck and noise wash on each run.
	for name, fn, seed in (("drift", drift, 11), ("rain", rain, 23), ("pulse", pulse, 37)):
		random.seed(seed)
		write(f"{name}_calm", fn(False))
		write(f"{name}_play", fn(True), TARGET_LUFS + 2.0)  # play beds sit under SFX, so a hair louder


if __name__ == "__main__":
	build()
