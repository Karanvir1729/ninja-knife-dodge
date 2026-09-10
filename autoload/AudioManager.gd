extends Node
## Music with crossfade, a pooled SFX player set and haptics, all gated by settings.

## Music vibes. Each one supplies the three ambient beds; the cinematic story score is
## shared. Every bed is loudness-matched near -24 LUFS with little energy above 1 kHz,
## so switching vibe never jumps in level and none of them tire the ears on a long loop.
##
## KOTO, GARDEN and DUSK are Tozan's CC0 Japanese ambient pieces, made seamless and
## levelled by tools/prep_music.py. CLASSIC is the game's original pair. YOURS is
## whatever the player layered together in The Loop Room.
const VIBES := {
	"classic": {
		"label": "CLASSIC",
		"desc": "The original music box and knife theme, softened.",
		"menu": "res://sounds/music_box_soft.mp3",
		"knife": "res://sounds/Mysterious.mp3",
		"match": "res://sounds/gen/match_loop.wav",
	},
	"koto": {
		"label": "KOTO",
		"desc": "A koto turning over slowly in the dark.",
		"menu": "res://sounds/oga_koto.mp3",
		"knife": "res://sounds/oga_koto.mp3",
		"match": "res://sounds/oga_koto.mp3",
	},
	"garden": {
		"label": "GARDEN",
		"desc": "A still garden at night.",
		"menu": "res://sounds/oga_garden.mp3",
		"knife": "res://sounds/oga_garden.mp3",
		"match": "res://sounds/oga_garden.mp3",
	},
	"dusk": {
		"label": "DUSK",
		"desc": "The long, low hour after sundown.",
		"menu": "res://sounds/oga_dusk.mp3",
		"knife": "res://sounds/oga_dusk.mp3",
		"match": "res://sounds/oga_dusk.mp3",
	},
	"yours": {
		"label": "YOURS",
		"desc": "The mix you built in The Loop Room.",
		"menu": "", "knife": "", "match": "",
	},
}
## Per-bed trim in dB. The synthesised beds are rendered to a common target, but the
## licensed CLASSIC tracks and the older match ambience are not - left alone they span
## 7 dB, so picking CLASSIC jumped out at you in Shuriken Match and vanished in Knife
## Dodge. These come from `-- --audio=<dir>` captures of the running game rather than
## from the files: Mysterious is 87 s long, so its gated whole-file loudness describes
## a stretch the player rarely reaches, while a round only ever hears its quieter
## opening. They aim at roughly -23.5 LUFS, the level the calm beds already sit at, so
## the set is levelled by pulling the loud ones down rather than pushing the quiet one
## up. Re-measure with that mode after touching any bed.
const TRIM := {
	"res://sounds/oga_koto.mp3": 3.7,          # captured -27.7 LUFS in game
	"res://sounds/oga_garden.mp3": 2.1,        # captured -26.1
	"res://sounds/oga_dusk.mp3": 2.5,          # captured -26.5
	"res://sounds/music_box_soft.mp3": 0.3,    # captured -23.5, the loudest, eased down
	"res://sounds/Mysterious.mp3": 5.3,        # -28.8: its opening, not its -25.8 whole-file figure
	"res://sounds/gen/match_loop.wav": -4.0,   # -19.5: the loudest bed, pulled down to match
}
const VIBE_ORDER := ["koto", "garden", "dusk", "classic", "yours"]
const DEFAULT_VIBE := "koto"
const STORY_TRACK := "res://sounds/gen/story_theme.wav"
## The Loop Room's 20 tunes. The order is the save format, so only ever append.
const LOOPS := ["heart", "taiko", "shaker", "rim", "frame", "sub", "bass", "fifth",
	"padwarm", "padair", "dronelow", "choir", "koto", "bell", "box", "marimba",
	"harp", "rain", "wind", "shimmer"]
const LOOP_PATH := "res://sounds/gen/loop_%s.wav"
const LOOP_FADE := 0.35
## One tune alone sits here; _mix_db pulls the set down as more are added.
const MIX_BASE_DB := 2.0
const SFX_DIR := "res://sounds/gen/"
const LEGACY_SFX := {"jump": "res://sounds/160756__cosmicembers__fast-swing-air-woosh.wav"}
const POOL_SIZE := 10
const FADE := 0.7

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track := ""
var _current_path := ""
var _vibe := DEFAULT_VIBE
var _loop_players: Array[AudioStreamPlayer] = []
var _loop_tweens: Array[Tween] = []
var _mix: Array = []
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_active = _music_a
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	SaveData.settings_changed.connect(_apply_settings)
	_apply_settings()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80
	add_child(p)
	return p

func _apply_settings() -> void:
	var vibe := current_vibe()
	if vibe != _vibe:
		_vibe = vibe
		if _current_track != "":
			var again := _current_track
			_current_track = ""        # force a real re-resolve, mix or file
			play_music(again)
	var music_on := bool(SaveData.setting("music"))
	var music_vol := float(SaveData.setting("music_volume"))
	var sfx_on := bool(SaveData.setting("sfx"))
	var sfx_vol := float(SaveData.setting("sfx_volume"))
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(mi, not music_on)
	AudioServer.set_bus_volume_db(mi, linear_to_db(clampf(music_vol, 0.0001, 1.0)))
	AudioServer.set_bus_mute(si, not sfx_on)
	AudioServer.set_bus_volume_db(si, linear_to_db(clampf(sfx_vol, 0.0001, 1.0)))

## Load a stream, forcing a loop for music. The vibe beds already carry
## edit/loop_mode=1 from their .import; older tracks are looped here instead, so
## whatever a vibe points at is guaranteed to run on without a gap.
func _load(path: String, loop: bool = false) -> AudioStream:
	var key := path + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing stream " + path)
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	elif loop and s is AudioStreamMP3 and not s.loop:
		s = s.duplicate()
		s.loop = true
	_cache[key] = s
	return s

## The vibe the player picked in Settings, falling back if the save holds an old name.
func current_vibe() -> String:
	var key := str(SaveData.setting("music_vibe"))
	# YOURS only exists once the player has kept a mix; before that it is not a choice.
	if key == "yours" and SaveData.loop_mix().is_empty():
		return DEFAULT_VIBE
	return key if VIBES.has(key) else DEFAULT_VIBE

func _track_path(track: String) -> String:
	if track == "story":
		return STORY_TRACK
	return str(VIBES[current_vibe()].get(track, ""))

## The stream the current vibe would use for a slot, or null if it is missing. The
## ambient beds loop; the story score is scored to its film and plays once.
func music_stream(track: String) -> AudioStream:
	return _load(_track_path(track), track != "story")

## Crossfade to a named slot ("menu", "knife", "match", "story"). Asking for whatever is
## already playing is a no-op, including when two slots share a bed within a vibe.
func play_music(track: String) -> void:
	# The player's own mix stands in for all three ambient beds; the story score is
	# scored to its film and is never replaced.
	if track != "story" and current_vibe() == "yours":
		if _current_track == track and _current_path == "mix":
			return
		_current_track = track
		play_mix(SaveData.loop_mix())
		return
	var path := _track_path(track)
	if track == _current_track and path == _current_path:
		return
	_current_track = track
	_swap_to(path, track != "story")

func _swap_to(path: String, loop: bool = true) -> void:
	if path == _current_path and _active.playing:
		return
	if not _mix.is_empty():
		stop_mix()
	_current_path = path
	var stream := _load(path, loop)
	var next := _music_b if _active == _music_a else _music_a
	var prev := _active
	_active = next
	if stream == null:
		_fade(prev, -80.0)
		return
	next.stream = stream
	next.volume_db = -80
	next.play()
	_fade(next, float(TRIM.get(path, 0.0)))
	_fade(prev, -80.0, true)

func stop_music() -> void:
	_current_track = ""
	_current_path = ""
	_fade(_active, -80.0, true)

func _fade(p: AudioStreamPlayer, to_db: float, stop_after: bool = false) -> void:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(p, "volume_db", to_db, FADE)
	if stop_after:
		t.tween_callback(p.stop)

## Fire-and-forget sound effect from sounds/gen (or a legacy file).
func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var path: String = LEGACY_SFX.get(sfx_name, SFX_DIR + sfx_name + ".wav")
	var stream := _load(path)
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func click() -> void:
	play_sfx("ui_click")

func back() -> void:
	play_sfx("ui_back")

# ---------------------------------------------------------------- the loop mix

## Every tune is exactly 6.000 s at 80 BPM in A minor pentatonic, so any set of them
## lines up. They are all started together and never stopped - toggling one only moves
## its volume - because restarting a player would drop it out of phase with the rest.
func _ensure_loop_players() -> void:
	if not _loop_players.is_empty():
		return
	for name in LOOPS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		p.stream = _load(LOOP_PATH % name, true)
		add_child(p)
		_loop_players.append(p)
		_loop_tweens.append(null)

## Twenty layers sum to nearly 2.0 FS, so the mix is scaled by 1/sqrt(n): loud enough
## to hear one tune on its own, still clean with all twenty running.
func _mix_db(count: int) -> float:
	return MIX_BASE_DB + linear_to_db(1.0 / sqrt(maxf(1.0, float(count))))

## Play a set of tune names together, fading each layer in or out.
func play_mix(active: Array) -> void:
	_ensure_loop_players()
	_current_path = "mix"
	_fade(_active, -80.0, true)          # a mix replaces any single-file track
	_mix = active.duplicate()
	var db := _mix_db(_mix.size())
	for i in LOOPS.size():
		var p := _loop_players[i]
		if not p.playing:
			p.play()
		_fade_loop(i, db if _mix.has(LOOPS[i]) else -80.0)

## One tune's stream, for previews and the smoke checks.
func music_loop(name: String) -> AudioStream:
	return _load(LOOP_PATH % name, true)

## One tween per layer, replaced rather than stacked: a player jabbing at the pads can
## otherwise leave several fades racing on the same volume, and the loser wins last.
func _fade_loop(i: int, to_db: float) -> void:
	if _loop_tweens[i] and _loop_tweens[i].is_valid():
		_loop_tweens[i].kill()
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(_loop_players[i], "volume_db", to_db, LOOP_FADE)
	_loop_tweens[i] = t

func stop_mix() -> void:
	_mix = []
	for i in _loop_players.size():
		_fade_loop(i, -80.0)

func mix_active() -> Array:
	return _mix.duplicate()

## Preview a single tune at the level it would sit at inside `count` layers.
func loop_preview(name: String) -> void:
	play_sfx_stream(_load(LOOP_PATH % name, false), _mix_db(1))

func play_sfx_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = volume_db
	p.play()

## Lower the music while something else (a rewarded video) has the speakers.
func duck(on: bool) -> void:
	var mi := AudioServer.get_bus_index("Music")
	var vol := float(SaveData.setting("music_volume"))
	var target := linear_to_db(clampf(vol * (0.15 if on else 1.0), 0.0001, 1.0))
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_method(func(v: float): AudioServer.set_bus_volume_db(mi, v), AudioServer.get_bus_volume_db(mi), target, 0.4)

## Short haptic pulse on handhelds, honouring the setting.
func vibrate(ms: int = 30) -> void:
	if not bool(SaveData.setting("haptics")):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
