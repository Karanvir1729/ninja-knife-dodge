extends CanvasLayer
## The Loop Room, level one: twenty tunes the player layers into their own music.
##
## Every tune is a 6.000 s loop written to one grid - 80 BPM, A minor pentatonic - and
## AudioManager starts them all together and only moves their volume, so any set of them
## plays in time. That is the whole design: there is no wrong combination, so a player
## who cannot read music still cannot make a mess. What they build can be kept as the
## background music for the rest of the game.

## The pads, in grid order: five families of four, each with its own colour.
const FAMILIES := [
	{"name": "DRUMS", "color": Globals.RED,
	 "tunes": [["heart", "HEARTBEAT"], ["taiko", "TAIKO"], ["frame", "HAND DRUM"], ["rim", "RIM TICK"]]},
	{"name": "LOW", "color": Globals.ORANGE,
	 "tunes": [["sub", "SUB"], ["bass", "BASS LINE"], ["fifth", "FIFTH"], ["dronelow", "DEEP DRONE"]]},
	{"name": "PADS", "color": Globals.VIOLET,
	 "tunes": [["padwarm", "WARM PAD"], ["padair", "AIR PAD"], ["choir", "CHOIR"], ["shimmer", "SHIMMER"]]},
	{"name": "TUNES", "color": Globals.CYAN,
	 "tunes": [["koto", "KOTO"], ["box", "MUSIC BOX"], ["marimba", "MARIMBA"], ["harp", "HARP"]]},
	{"name": "AIR", "color": Globals.GREEN,
	 "tunes": [["bell", "BELL"], ["rain", "RAIN"], ["wind", "WIND"], ["shaker", "SHAKER"]]},
]
const LOOP_SECONDS := 6.0

var _pads := {}
var _active: Array = []
var _elapsed := 0.0

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	Globals.apply_safe_margins(%Root, 30)
	%Back.pressed.connect(_back)
	%Clear.pressed.connect(_clear)
	%Keep.pressed.connect(_keep)
	_build_grid()
	# Start from whatever the player kept last time, so the room opens on their music.
	_active = SaveData.loop_mix()
	for name in _active:
		if _pads.has(name):
			_paint(name, true)
	AudioManager.play_mix(_active)
	_refresh()

func _build_grid() -> void:
	# One column per family: the header sits in row 0 and its four tunes below it, so a
	# player reading down a column sees drums, then low end, then pads, and so on.
	%Grid.columns = FAMILIES.size()
	for f in FAMILIES:
		var head := Label.new()
		head.theme_type_variation = &"CapsLabel"
		head.add_theme_font_size_override("font_size", 14)
		head.add_theme_color_override("font_color", f["color"])
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.text = str(f["name"])
		%Grid.add_child(head)
	for row in 4:
		for f in FAMILIES:
			var tune: Array = f["tunes"][row]
			var b := Button.new()
			b.toggle_mode = true
			b.text = str(tune[1])
			b.add_theme_font_size_override("font_size", 15)
			b.custom_minimum_size = Vector2(0, 56)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			b.add_theme_color_override("font_pressed_color", f["color"])
			b.add_theme_color_override("font_hover_pressed_color", f["color"])
			b.pressed.connect(_toggle.bind(str(tune[0])))
			%Grid.add_child(b)
			_pads[str(tune[0])] = {"button": b, "color": f["color"]}

func _toggle(name: String) -> void:
	if _active.has(name):
		_active.erase(name)
		AudioManager.back()
	else:
		_active.append(name)
		AudioManager.click()
	_paint(name, _active.has(name))
	AudioManager.play_mix(_active)
	AudioManager.vibrate(18)
	_refresh()

func _paint(name: String, on: bool) -> void:
	var pad: Dictionary = _pads[name]
	var b: Button = pad["button"]
	b.set_pressed_no_signal(on)
	b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)

func _refresh() -> void:
	var n := _active.size()
	%Count.text = "%d TUNE%s" % [n, "" if n == 1 else "S"]
	%Keep.disabled = n == 0
	%Clear.disabled = n == 0

func _clear() -> void:
	AudioManager.back()
	for name in _active.duplicate():
		_paint(name, false)
	_active = []
	AudioManager.play_mix(_active)
	_refresh()

## Keep the mix: it is saved and becomes the YOURS music vibe from here on.
func _keep() -> void:
	AudioManager.click()
	SaveData.set_loop_mix(_active)
	SaveData.set_setting("music_vibe", "yours")
	# The Yard card's stat is the richest mix kept, which is what the milestones count.
	SaveData.record_game_score("loops", _active.size(), {"detail": "%d LAYERS" % _active.size()}, 0.0)
	_toast("SAVED. THIS IS YOUR MUSIC NOW - CHANGE IT ANY TIME IN SETTINGS.")

func _back() -> void:
	AudioManager.back()
	AudioManager.stop_mix()
	Globals.go("start")

func _process(delta: float) -> void:
	# The bar shows the six-second loop going round, so the layering reads as one cycle.
	_elapsed = fmod(_elapsed + delta, LOOP_SECONDS)
	%Bar.value = _elapsed / LOOP_SECONDS

func _toast(text: String) -> void:
	%Toast.text = text
	var t := create_tween()
	t.tween_property(%Toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.4)
	t.tween_property(%Toast, "modulate:a", 0.0, 0.4)
