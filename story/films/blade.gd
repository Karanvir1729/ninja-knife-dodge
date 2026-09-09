extends Film
## Chapter IV, the Trial of the Blade: the daggers of light hunt whatever is
## still burning, and tonight that is the ninja. Kuro's first lesson is the only
## one the dojo ever proved against them: a blade owns the thin line it travels
## on, and every other place in the void belongs to you. Six shots; plays before
## the player's first Knife Dodge run.

const SWORD := "res://graphics/skeleton_sword.png"
const TIP := "res://graphics/gen/tip_glow.png"
const GLOW := "res://graphics/gen/glow.png"
## The hunters' ring: a flat ellipse behind the dojo, a little above it (its
## low point sits at the guides' shoulders, clear of the platform).
const RING_C := Vector2(40.0, -105.0)
const RING_RX := 540.0
const RING_RY := 180.0
const RING_SPEED := 0.55

var _old: Mascot
var _pip: Mascot
var _hunt: Node2D               # parent of the circling daggers
var _hunters: Array = []        # Node2D per dagger; meta "a" is its ring angle, "on" whether it circles
var _clock := 0.0

func film_id() -> String:
	return "blade"

func _shots() -> Array:
	return [_shot_dojo, _shot_hunt, _shot_lesson, _shot_pip, _shot_you, _shot_title]

func _dress() -> void:
	_set_title("TRIAL OF THE BLADE", "CHAPTER IV  ·  KNIFE DODGE", "Be elsewhere when they arrive.", [["glyph_blade", Globals.CYAN]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	# The hunters live behind the platform, so their ring never crosses a face.
	_hunt = Node2D.new()
	_hunt.name = "Hunters"
	$Stage/Far.add_child(_hunt)
	for i in 6:
		var col: Color = Globals.CYAN if i % 2 == 0 else Globals.RED
		var d := _dagger(_hunt, col)
		d.set_meta("a", i * TAU / 6.0)
		d.set_meta("on", false)
		d.visible = false
		_hunters.append(d)
	_old = _actor("sensei", _home_sensei(), 0.72, true, "neutral")
	_pip = _actor("pip", _home_pip(), 0.62, false, "neutral")

## A dagger of light, the prologue's recipe: the skeleton sword with a glowing
## tip, tinted. The node's +x axis is the direction the blade travels.
func _dagger(parent: Node, col: Color) -> Node2D:
	var d := Node2D.new()
	var sw := Sprite2D.new()
	sw.texture = _t(SWORD)
	sw.position = Vector2(40, 0)
	sw.rotation = 0.785398
	sw.scale = Vector2(1.6, 1.6)
	sw.modulate = Color.WHITE.lerp(col, 0.3)
	d.add_child(sw)
	_sprite(d, TIP, Vector2(60, 0), 3.0, Color(col, 0.9), true)
	parent.add_child(d)
	return d

## A dagger streaks from `from` to `to` (stage coordinates) in `dur` seconds
## and shatters where it stops.
func _streak(from: Vector2, to: Vector2, col: Color, dur: float, db: float = -10.0) -> Node2D:
	var d := _dagger($Stage/FX, col)
	d.position = from
	d.rotation = (to - from).angle()
	AudioManager.play_sfx("whoosh", randf_range(1.2, 1.5), db)
	var t := create_tween()
	t.tween_property(d, "position", to, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		_burst(to, col, 24, 260.0)
		AudioManager.play_sfx("shatter", randf_range(0.9, 1.25), db)
		d.queue_free())
	return d

## The thin line a blade owns: drawn along its path a beat after it passes,
## then let go.
func _line(from: Vector2, to: Vector2) -> void:
	for w in [[18.0, 0.22], [4.0, 0.95]]:
		var l := Line2D.new()
		l.points = PackedVector2Array([from, to])
		l.width = w[0]
		l.default_color = Color(Globals.CYAN, w[1])
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.material = _add_material()
		l.modulate.a = 0.0
		$Stage/FX.add_child(l)
		var t := create_tween()
		t.tween_property(l, "modulate:a", 1.0, 0.25).set_delay(0.2)
		t.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.4)
		t.tween_callback(l.queue_free)

func _ring_point(a: float) -> Vector2:
	return _c + RING_C + Vector2(cos(a) * RING_RX, sin(a) * RING_RY)

## The heading of a dagger circling the ring at angle `a` (its tangent).
func _ring_heading(a: float) -> float:
	return atan2(RING_RY * cos(a), -RING_RX * sin(a))

## The hunters rise out of the void below and take up their ring.
func _raise_hunters() -> void:
	AudioManager.play_sfx("rise", 1.0, -8.0)
	for i in _hunters.size():
		var h: Node2D = _hunters[i]
		var a: float = h.get_meta("a")
		var home := _ring_point(a)
		var heading := _ring_heading(a)
		var turn := wrapf(heading + PI / 2, -PI, PI)     # shortest turn from pointing up
		h.position = Vector2(home.x, _c.y + 560.0)
		h.rotation = -PI / 2
		h.visible = true
		h.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(i * 0.14 * PACE)
		t.tween_property(h, "modulate:a", 1.0, 0.3)
		t.parallel().tween_property(h, "position", home, 1.1 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(h, "rotation", -PI / 2 + turn, 1.1 * PACE).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(func(): h.set_meta("on", true))

func _tick(delta: float) -> void:
	_clock += delta
	for i in _hunters.size():
		var h: Node2D = _hunters[i]
		if not is_instance_valid(h) or not h.get_meta("on", false):
			continue
		var a: float = h.get_meta("a") + delta * RING_SPEED
		h.set_meta("a", a)
		h.position = _ring_point(a) + Vector2(0, sin(_clock * 2.4 + i) * 5.0)
		h.rotation = _ring_heading(a)
		var s := 0.9 + 0.15 * sin(a)       # nearer at the bottom of the ring
		h.scale = Vector2(s, s)

# ---------------------------------------------------------------- the film

func _shot_dojo() -> void:
	_cam(1.08, Vector2(0, 20), 0.0)
	_cam(1.0, Vector2.ZERO, 8.0)
	await _fade(0.0, 1.2)
	_caption("The second lantern is out. Tonight the daggers come for what is still burning.")
	# What is still burning: the last lantern gutters, and holds.
	var g := _lantern_glow(0)
	var fl := create_tween()
	fl.tween_interval(1.6 * PACE)
	fl.tween_property(g, "modulate:a", 0.14, 0.12)
	fl.tween_property(g, "modulate:a", 0.42, 0.18)
	fl.tween_property(g, "modulate:a", 0.2, 0.1)
	fl.tween_property(g, "modulate:a", 0.36, 0.5)
	var lt := create_tween()
	lt.tween_interval(1.6 * PACE)
	lt.tween_property(_lantern(0), "modulate:a", 0.5, 0.12)
	lt.tween_property(_lantern(0), "modulate:a", 0.75, 0.5)
	await _wait(2.2)
	_pip.set_mood("think")
	await _wait(1.0)
	_old.set_mood("think")
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_hunt() -> void:
	_advance = false
	_cam(0.96, Vector2(0, -6), 7.0)
	_raise_hunters()
	await _wait(0.4)
	_old.set_facing(false)
	_pip.set_facing(true)
	await _wait(0.4)
	_caption("They hunt whatever is still burning. Out here, that is a short list.")
	await _wait(1.4)
	_pip.set_facing(false)
	_pip.hop(0.4)
	_old.set_facing(true)
	await _wait(1.0)
	_old.set_mood("neutral")
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_lesson() -> void:
	_advance = false
	_cam(1.1, Vector2(40, 30), 5.0)
	_tween_alpha(_hunt, 0.5, 1.0)
	_caption("A blade owns the thin line it travels on. Every other place belongs to you.")
	await _wait(1.4)
	# Kuro steps aside...
	var aside := _c + Vector2(-200, 62)
	create_tween().tween_property(_old, "position", aside, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_old.hop(0.8)
	AudioManager.play_sfx("whoosh", 0.8, -14.0)
	await _wait(0.4)
	# ...and a beat later a blade owns the line he was standing on.
	var spot := _home_sensei() + Vector2(0, -22)
	var from := _c + Vector2(80, -360)
	var dir := (spot - from).normalized()
	var to := spot + dir * ((_c.y + 150.0 - spot.y) / dir.y)
	_line(from, to)
	_streak(from, to, Globals.CYAN, 0.32)
	await _wait(0.5)
	_old.set_mood("neutral")
	_pip.set_mood("excited")
	await _wait(1.2)
	_hint(true)
	await _wait(1.8)
	_clear_caption()

func _shot_pip() -> void:
	_advance = false
	_cam(1.08, Vector2(-50, 30), 6.0)
	_caption("Pip has been practising.")
	_pip.set_facing(true)
	await _wait(0.8)
	# One from the side: Pip goes over it.
	_pip.set_mood("excited")
	var home: Vector2 = _pip.position
	var jump := create_tween()
	jump.tween_property(_pip, "position:y", home.y - 120.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	jump.tween_interval(0.12)
	jump.tween_property(_pip, "position:y", home.y, 0.26).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_streak(_c + Vector2(760, 104), _c + Vector2(-10, 104), Globals.RED, 0.42)
	await _wait(1.1)
	# One from above: Pip is elsewhere.
	_streak(_c + Vector2(-150, -360), home + Vector2(0, 58), Globals.CYAN, 0.4)
	var dart := create_tween()
	dart.tween_interval(0.08)
	dart.tween_property(_pip, "position", _c + Vector2(270, 92), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	dart.tween_callback(func(): _pip.hop(0.7))
	await _wait(0.8)
	_caption("Pip's record is eleven. Once.")
	_pip.hop(1.2)
	await _wait(0.5)
	_pip.hop(0.8)
	await _wait(0.5)
	_hint(true)
	await _wait(1.7)
	_clear_caption()

func _shot_you() -> void:
	_advance = false
	_cam(1.02, Vector2(-70, 20), 6.0)
	_tween_alpha(_hunt, 0.3, 1.5)
	_caption("Twenty-five in one run and the Seal of Empty Air is yours. Move before you are moved.")
	# The ninja: a star rising at the edge of the void, still burning.
	var star := _sprite($Stage/FX, "res://graphics/gen/player_star.png", _c + Vector2(520, 470), 0.72, Globals.GOLD)
	var glow := _sprite(star, GLOW, Vector2.ZERO, 1.2, Color(Globals.GOLD, 0.65), true)
	AudioManager.play_sfx("rise", 1.2, -10.0)
	var st := create_tween()
	st.tween_property(star, "position:y", _c.y - 60.0, 1.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	st.parallel().tween_property(star, "rotation", TAU * 0.5, 1.4 * PACE).set_ease(Tween.EASE_OUT)
	st.tween_callback(func():
		AudioManager.play_sfx("star_ding", 1.0, -8.0)
		_burst(star.position, Globals.GOLD, 30, 220.0))
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(1.45, 1.45), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await _wait(0.8)
	_old.set_mood("neutral")
	_old.point_at($Stage/FX.to_global(_c + Vector2(500, -60)))
	_pip.set_facing(true)
	_pip.set_mood("excited")
	await _wait(2.4)
	_hint(true)
	await _wait(1.8)
	_old.unpoint()
	_clear_caption()
