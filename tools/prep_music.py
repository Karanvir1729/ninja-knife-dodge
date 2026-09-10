#!/usr/bin/env python3
"""Turn the CC0 source tracks in sounds/raw into the game's looping music beds.

The sources are Tozan's public-domain Japanese ambient pieces from OpenGameArt (CC0, so
no attribution is required - the credits screen names them anyway). Two things have to
happen before they can sit behind a menu for an hour:

  * they are three-minute pieces, not loops, so the tail is crossfaded onto the head and
    the overlap trimmed - the join is then inaudible instead of a hard jump;
  * they arrive between -28 and -32 LUFS, so each is normalised onto the same target as
    every other bed in the game (see [[audio-loudness-preference]]).

Run:  python3 tools/prep_music.py   -> writes sounds/oga_*.mp3   (needs ffmpeg)"""
import json, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "sounds" / "raw"
OUT = ROOT / "sounds"
TARGET_LUFS = -24.0
XFADE = 6.0          # seconds of overlap at the loop point
# These pieces are dark - two of the three sources are 16 kHz, so there is nothing above
# 8 kHz to encode. 32 kHz output at 64k spends the bits where the music actually is.
BITRATE = "64k"
RATE = "32000"

TRACKS = ["koto", "garden", "dusk"]

# The CLASSIC vibe's music box needs a different treatment: it is not too long, it is too
# loud and too bright. It shipped at -14.9 LUFS with a -1.2 dBTP peak, about 10 dB hotter
# than every other track and heavy through 1-5 kHz, on a 23 s loop behind every menu. Two
# bells tame that band and a gentle compressor rounds off the strikes.
SOFT_CHAIN = ("equalizer=f=3200:t=q:w=1.1:g=-6,equalizer=f=5200:t=q:w=1.3:g=-4,"
              "lowpass=f=8000,acompressor=threshold=0.08:ratio=3:attack=20:release=400")


def probe(path, entries):
	out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", entries,
	                      "-of", "default=nw=1:nk=1", str(path)],
	                     capture_output=True, text=True).stdout.split()
	return out


def lufs(path):
	p = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
	                    "-af", "loudnorm=print_format=summary", "-f", "null", "-"],
	                   capture_output=True, text=True)
	for line in p.stderr.splitlines():
		if "Input Integrated" in line:
			return float(line.split(":")[1].strip().split()[0])
	return None


def loop_filter(length, gain_db):
	"""Reorder a track as crossfade(tail, head) + middle, so the end meets the start.

	Playing that back to back is continuous at both joins: the middle ends exactly where
	the tail began, and the crossfade lands exactly where the middle starts."""
	x, end = XFADE, length - XFADE
	return (
		f"[0]atrim=0:{x},asetpts=PTS-STARTPTS,afade=t=in:st=0:d={x}[head];"
		f"[0]atrim={end}:{length},asetpts=PTS-STARTPTS,afade=t=out:st=0:d={x}[tail];"
		f"[tail][head]amix=inputs=2:normalize=0[join];"
		f"[0]atrim={x}:{end},asetpts=PTS-STARTPTS[mid];"
		f"[join][mid]concat=n=2:v=0:a=1,volume={gain_db:.2f}dB[out]"
	)


def soften(src_name, dest_name, target=TARGET_LUFS):
	"""Re-render a track that is loud and bright rather than long (the CLASSIC music box)."""
	src, dest = RAW / src_name, OUT / dest_name
	if not src.exists():
		print(f"skip {dest_name} - no {src}")
		return
	probe_out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), "-af",
	                            f"{SOFT_CHAIN},loudnorm=I={target}:TP=-3:LRA=6:print_format=json",
	                            "-f", "null", "-"], capture_output=True, text=True).stderr
	m = json.loads(probe_out[probe_out.rindex("{"):probe_out.rindex("}") + 1])
	subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-af",
	                f"{SOFT_CHAIN},loudnorm=I={target}:TP=-3:LRA=6:linear=true"
	                f":measured_I={m['input_i']}:measured_TP={m['input_tp']}"
	                f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
	                f":offset={m['target_offset']}",
	                "-c:a", "libmp3lame", "-q:a", "5", "-ac", "1", "-ar", "44100", str(dest)],
	               check=True)
	print(f"wrote {dest.name:16s} {float(m['input_i']):+.1f} -> {lufs(dest):+.1f} LUFS  "
	      f"{dest.stat().st_size // 1024} KB")


def build():
	soften("Music Box Game Over 2.mp3", "music_box_soft.mp3")
	for name in TRACKS:
		src = next((RAW / f"oga_{name}{e}" for e in (".ogg", ".mp3", ".wav")
		            if (RAW / f"oga_{name}{e}").exists()), None)
		if src is None:
			print(f"skip {name} - no sounds/raw/oga_{name}.*")
			continue
		length = float(probe(src, "format=duration")[0])
		dest = OUT / f"oga_{name}.mp3"
		measured = lufs(src)
		gain = TARGET_LUFS - measured
		subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src),
		                "-filter_complex", loop_filter(length, gain),
		                "-map", "[out]",
		                "-c:a", "libmp3lame", "-b:a", BITRATE, "-ac", "2", "-ar", RATE,
		                str(dest)], check=True)
		print(f"wrote {dest.name:16s} {length:5.0f}s -> {float(probe(dest, 'format=duration')[0]):5.0f}s  "
		      f"{measured:+.1f} -> {lufs(dest):+.1f} LUFS  {dest.stat().st_size // 1024} KB")


if __name__ == "__main__":
	build()
