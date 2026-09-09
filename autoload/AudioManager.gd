extends Node
## Music with crossfade, a pooled SFX player set and haptics, all gated by settings.

## Music vibes. Each one supplies the three ambient beds; the cinematic story score is
## shared. Every bed is loudness-matched near -24 LUFS with little energy above 1 kHz,
## so switching vibe never jumps in level and none of them tire the ears on a long loop.
const VIBES := {
	"classic": {
		"label": "CLASSIC",
		"desc": "The original music box and knife theme, softened.",
		"menu": "res://sounds/music_box_soft.mp3",
		"knife": "res://sounds/Mysterious.mp3",
		"match": "res://sounds/gen/match_loop.wav",
	},
	"drift": {
		"label": "DRIFT",
		"desc": "Weightless warm pads. The quietest one.",
		"menu": "res://sounds/gen/drift_calm.wav",
		"knife": "res://sounds/gen/drift_play.wav",
		"match": "res://sounds/gen/drift_play.wav",
	},
	"rain": {
		"label": "RAIN",
		"desc": "Dojo rain, wind and a far-off temple bell.",
		"menu": "res://sounds/gen/rain_calm.wav",
		"knife": "res://sounds/gen/rain_play.wav",
		"match": "res://sounds/gen/rain_play.wav",
	},
	"pulse": {
		"label": "PULSE",
		"desc": "A slow warm heartbeat under the void.",
		"menu": "res://sounds/gen/pulse_calm.wav",
		"knife": "res://sounds/gen/pulse_play.wav",
		"match": "res://sounds/gen/pulse_play.wav",
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
	"res://sounds/music_box_soft.mp3": 0.8,    # untrimmed it captures -24.3 LUFS in game
	"res://sounds/Mysterious.mp3": 5.3,        # -28.8: its opening, not its -25.8 whole-file figure
	"res://sounds/gen/match_loop.wav": -4.0,   # -19.5: the loudest bed, pulled down to match
}
const VIBE_ORDER := ["classic", "drift", "rain", "pulse"]
const DEFAULT_VIBE := "classic"
const STORY_TRACK := "res://sounds/gen/story_theme.wav"
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
			_swap_to(_track_path(_current_track), _current_track != "story")
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
	var path := _track_path(track)
	if track == _current_track and path == _current_path:
		return
	_current_track = track
	_swap_to(path, track != "story")

func _swap_to(path: String, loop: bool = true) -> void:
	if path == _current_path and _active.playing:
		return
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
