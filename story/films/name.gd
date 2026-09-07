extends Film
## Chapter IV, the Trial of the Name: nine pads, one for each master of the
## Star Dojo, in the order they stood at dawn. Kuro is the ninth and can still
## play the whole roll without thinking. The eighth was his own master; he kept
## her drill and lost her name. Six shots; plays the first time Sensei Says is
## opened. seal_name.gd extends this for the pad helpers.

const PADS := 9
const PAD_DOT := 2.6            # dot.png scale at rest
const PAD_GLOW := 0.55          # glow.png scale at rest
const PAD_GLOW_REST := 0.32     # glow alpha at rest
const SPIRIT_SCALE := 0.38
const SPIRIT_ALPHA := 0.32
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

var _old: Mascot
var _pip: Mascot
var _pads: Array = []           # Node2D per pad, in $Stage/FX
var _pad_glows: Array = []
var _pad_dots: Array = []
var _pad_nums: Array = []       # the numeral under each pad
var _pad_tweens: Array = []
var _spirits: Array = []        # faint "young" mascots, one per master

func film_id() -> String:
	return "name"

func _shots() -> Array:
	return [_shot_pads, _shot_masters, _shot_roll, _shot_eighth, _shot_pip, _shot_title]

func _dress() -> void:
	_set_title("TRIAL OF THE NAME", "CHAPTER IV  ·  SENSEI SAYS", "Nine pads. Nine masters. Hold the roll.",
		[["glyph_memory", Globals.VIOLET]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.3, 1.0)
	_build_pads(false)
	# The nine masters as they stood at dawn: eight faint spirits and, at the
	# end of the line, the ninth, who brightens into old Kuro.
	for i in PADS:
		var s := _actor("young", _spirit_pos(i), SPIRIT_SCALE, true, "neutral")
		s.modulate = Color(_pad_color(i).lerp(Color.WHITE, 0.45), 0.0)
		_spirits.append(s)
	_old = _actor("sensei", _c + Vector2(_slot_x(8), 62), 0.72, true, "neutral")
	_old.modulate.a = 0.0
	_pip = _actor("pip", _home_pip() + Vector2(620, 0), 0.62, false, "neutral")
	_pip.modulate.a = 0.0

## Where master i stood: eight along the platform, the ninth a step apart.
func _slot_x(i: int) -> float:
	return -350.0 + i * 70.0 if i < 8 else 250.0

func _spirit_pos(i: int) -> Vector2:
	return _c + Vector2(_slot_x(i), 93)

## The pads hang in an arc above the platform, first master on the left.
func _pad_pos(i: int) -> Vector2:
	var t := (i - 4) / 4.0
	return _c + Vector2(t * 430.0, -140.0 - 95.0 * (1.0 - t * t))

func _pad_color(i: int) -> Color:
	return Color.from_hsv(fmod(0.72 + i * 0.11, 1.0), 0.7, 1.0)

## A pad: a glow, a dot and a numeral, all under one node so it can rise as one.
func _build_pads(shown: bool) -> void:
	for i in PADS:
		var col := _pad_color(i)
		var n := Node2D.new()
		n.name = "Pad%d" % i
		n.position = _pad_pos(i)
		n.modulate.a = 1.0 if shown else 0.0
		$Stage/FX.add_child(n)
		var glow := _sprite(n, "res://graphics/gen/glow.png", Vector2.ZERO, PAD_GLOW, Color(col, PAD_GLOW_REST), true)
		var dot := _sprite(n, "res://graphics/gen/dot.png", Vector2.ZERO, PAD_DOT, col)
		var num := _label(NUMERALS[i], Vector2.ZERO, 14, Globals.MUTED, 120.0)
		$Stage/FX.remove_child(num)
		n.add_child(num)
		num.position = Vector2(0, 44) - num.size * 0.5
		_pads.append(n)
		_pad_glows.append(glow)
		_pad_dots.append(dot)
		_pad_nums.append(num)
		_pad_tweens.append(null)

## Pad i rises into place, lit, with its tone.
func _pad_rise(i: int) -> void:
	var n: Node2D = _pads[i]
	var home := _pad_pos(i)
	n.position = home + Vector2(0, 70)
	n.scale = Vector2(0.4, 0.4)
	var t := create_tween().set_parallel(true)
	t.tween_property(n, "modulate:a", 1.0, 0.3 * PACE)
	t.tween_property(n, "position", home, 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(n, "scale", Vector2.ONE, 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_light_pad(i)

## Pad i lights: the glow swells, a ring rolls out, its tone plays.
func _light_pad(i: int, sound: bool = true) -> void:
	var glow: Sprite2D = _pad_glows[i]
	var dot: Sprite2D = _pad_dots[i]
	if _pad_tweens[i] and _pad_tweens[i].is_valid():
		_pad_tweens[i].kill()
	var t := create_tween()
	t.tween_property(glow, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(glow, "scale", Vector2.ONE * PAD_GLOW * 1.5, 0.06)
	t.parallel().tween_property(dot, "scale", Vector2.ONE * PAD_DOT * 1.4, 0.06)
	t.tween_property(glow, "modulate:a", PAD_GLOW_REST, 0.55).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glow, "scale", Vector2.ONE * PAD_GLOW, 0.55).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(dot, "scale", Vector2.ONE * PAD_DOT, 0.55).set_ease(Tween.EASE_OUT)
	_pad_tweens[i] = t
	var ring := _sprite(_pads[i], "res://graphics/gen/ring.png", Vector2.ZERO, 0.15, Color(_pad_color(i), 0.9), true)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(0.7, 0.7), 0.45).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.45)
	rt.chain().tween_callback(ring.queue_free)
	if sound:
		AudioManager.play_sfx("pad_%d" % (i + 1), 1.0, -6.0)

## Pad i gutters like a lantern and settles dim; its numeral goes with it.
func _gutter_pad(i: int) -> void:
	if _pad_tweens[i] and _pad_tweens[i].is_valid():
		_pad_tweens[i].kill()
	var glow: Sprite2D = _pad_glows[i]
	var dot: Sprite2D = _pad_dots[i]
	var t := create_tween()
	for a in [0.9, 0.1, 0.7, 0.05, 0.5, 0.1, 0.3, 0.06]:
		t.tween_property(glow, "modulate:a", a, 0.11)
	t.tween_property(glow, "modulate:a", 0.05, 0.4)
	t.parallel().tween_property(dot, "modulate", Color(_pad_color(i), 0.28), 0.4)
	t.parallel().tween_property(_pad_nums[i], "modulate:a", 0.0, 0.4)
	_pad_tweens[i] = t

func _spirit_flash(i: int) -> void:
	var s: Mascot = _spirits[i]
	var t := create_tween()
	t.tween_property(s, "modulate:a", 0.85, 0.06)
	t.tween_property(s, "modulate:a", SPIRIT_ALPHA, 0.5).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- the film

func _shot_pads() -> void:
	_cam(1.05, Vector2(0, 10), 0.0)
	_cam(1.0, Vector2.ZERO, 9.0)
	await _fade(0.0, 1.2)
	_caption("Nine pads. One for each master of the Star Dojo, in the order they stood at dawn.")
	AudioManager.play_sfx("rise", 0.9, -12.0)
	await _wait(0.5)
	for i in PADS:
		_pad_rise(i)
		await _wait(0.3)
	await _wait(1.2)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_masters() -> void:
	_advance = false
	_caption("Kuro is the ninth. He can still play the whole roll without thinking.")
	_cam(1.08, Vector2(0, 36), 8.0)
	AudioManager.play_sfx("whoosh", 0.6, -14.0)
	for i in PADS:
		create_tween().tween_property(_spirits[i], "modulate:a", SPIRIT_ALPHA, 0.9 * PACE).set_delay(i * 0.1 * PACE)
	await _wait(1.6)
	# The ninth brightens into old Kuro.
	var ghost: Mascot = _spirits[8]
	_grow(ghost, SPIRIT_SCALE, 0.72, 1.1)
	var xf := create_tween().set_parallel(true)
	xf.tween_property(ghost, "position:y", _old.position.y, 1.1 * PACE)
	xf.tween_property(ghost, "modulate:a", 0.0, 1.1 * PACE)
	xf.tween_property(_old, "modulate:a", 1.0, 1.1 * PACE)
	AudioManager.play_sfx("star_ding", 0.9, -10.0)
	_light_pad(8)
	await _wait(1.2)
	_old.hop(0.8)
	_hint(true)
	await _wait(2.0)
	_clear_caption()

func _shot_roll() -> void:
	_advance = false
	_caption("The eighth was his own master. He kept her drill.")
	_cam(1.0, Vector2.ZERO, 7.0)
	await _wait(0.6)
	for i in PADS:
		_light_pad(i)
		_old.hop(0.5)
		if i < 8:
			_spirit_flash(i)
		await _wait(0.36)
	await _wait(0.4)
	_hint(true)
	await _wait(1.8)
	_clear_caption()

func _shot_eighth() -> void:
	_advance = false
	_caption("He lost her name in the second fifty years. The Quiet takes a name last.")
	_cam(1.12, Vector2(-110, 30), 5.0)
	await _wait(0.4)
	_gutter_pad(7)
	AudioManager.play_sfx("swap_fail", 0.75, -12.0)
	create_tween().tween_property(_spirits[7], "modulate:a", 0.0, 1.4 * PACE)
	_old.set_mood("think")
	await _wait(1.2)
	_old.point_at(_pads[7].global_position)
	var q := _label("?", _pad_pos(7) + Vector2(52, -4), 34, Globals.VIOLET, 60.0)
	q.pivot_offset = q.size * 0.5
	q.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(q, "scale", Vector2.ONE, 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("pad_8", 0.5, -14.0)
	await _wait(0.9)
	_hint(true)
	await _wait(2.2)
	_old.unpoint()
	_clear_caption()

func _shot_pip() -> void:
	_advance = false
	_caption("Reach round five and the Seal of the Kept Name is yours. Hold the pattern.")
	_cam(1.04, Vector2(0, 20), 6.0)
	for i in 7:
		create_tween().tween_property(_spirits[i], "modulate:a", 0.0, 0.7 * PACE)
	_old.set_mood("neutral")
	_old.set_facing(true)
	create_tween().tween_property(_old, "position", _home_sensei(), 0.8 * PACE).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pip.enter(_home_pip() + Vector2(620, 0), _home_pip(), 0.3 * PACE)
	await _wait(1.2)
	_pip.set_mood("excited")
	for i in 5:
		_light_pad(i)
		await _wait(0.24)
	_old.set_mood("happy")
	_hint(true)
	await _wait(2.0)
	_clear_caption()
