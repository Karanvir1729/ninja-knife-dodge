extends Node
## Music with crossfade, a pooled SFX player set and haptics, all gated by settings.

const MUSIC := {
	"menu": "res://sounds/Music Box Game Over 2.mp3",
	"knife": "res://sounds/Mysterious.mp3",
	"match": "res://sounds/gen/match_loop.wav",
	"story": "res://sounds/gen/story_theme.wav",
}
const SFX_DIR := "res://sounds/gen/"
const LEGACY_SFX := {"jump": "res://sounds/160756__cosmicembers__fast-swing-air-woosh.wav"}
const POOL_SIZE := 10
const FADE := 0.7

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track := ""
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

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing stream " + path)
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and path.ends_with("match_loop.wav"):
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	elif s is AudioStreamMP3:
		s = s.duplicate()
		s.loop = true
	_cache[path] = s
	return s

## Crossfade to a named track. Passing the current track is a no-op.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	var stream := _load(MUSIC.get(track, ""))
	var next := _music_b if _active == _music_a else _music_a
	var prev := _active
	_active = next
	if stream == null:
		_fade(prev, -80.0)
		return
	next.stream = stream
	next.volume_db = -80
	next.play()
	_fade(next, 0.0)
	_fade(prev, -80.0, true)

func stop_music() -> void:
	_current_track = ""
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

## Short haptic pulse on handhelds, honouring the setting.
func vibrate(ms: int = 30) -> void:
	if not bool(SaveData.setting("haptics")):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
