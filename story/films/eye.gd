extends Film
## Chapter I, the Trial of the Eye: the Quiet makes nothing of its own. It
## copies the light it has already taken and paints the copy red, because a
## hand that answers a lie is a hand out of position. Kuro answered one once.
## Six shots; plays the first time Quick Draw is opened.

const SHURIKEN_PX := 80.0       # on-screen shuriken size (the texture is 192 px)
const RING_IMAGE_PX := 240.0    # ring diameter inside the 256 px texture
const RING_START := 2.2         # ring size relative to the shuriken at spawn
const RING_END := 1.0           # ... and when the light would expire

var _old: Mascot
var _pip: Mascot
var _young: Mascot
var _lights: Array = []         # live true lights (a Node2D with a Shuriken child)
var _copies: Array = []         # live red copies, drifting
var _one: Label

func film_id() -> String:
	return "eye"

func _shots() -> Array:
	return [_shot_tonight, _shot_copies, _shot_answered, _shot_one, _shot_pip, _shot_title]

func _dress() -> void:
	_set_title("TRIAL OF THE EYE", "CHAPTER I  ·  QUICK DRAW", "The red ones are copies. Leave them.", [["glyph_eye", Globals.ORANGE]])

func _build_extra() -> void:
	_show_dojo(0.0)
	_old = _actor("sensei", _home_sensei(), 0.72, true, "neutral")
	_pip = _actor("pip", _home_pip(), 0.62, false, "neutral")

# ---------------------------------------------------------------- lights and copies

## A true light as Quick Draw draws one: a spinning shuriken inside a ring that
## closes over `life` seconds (0 keeps the ring open).
func _light(pos: Vector2, color: Color, life: float = 0.0, size: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.scale = Vector2.ZERO
	_sprite(n, "res://graphics/gen/glow.png", Vector2.ZERO, 0.6 * size, Color(color, 0.38), true)
	var ring := _sprite(n, "res://graphics/gen/ring.png", Vector2.ZERO, RING_START * size * SHURIKEN_PX / RING_IMAGE_PX, Color(color, 0.7), true)
	ring.name = "Ring"
	var sh := _sprite(n, "res://graphics/gen/shuriken.png", Vector2.ZERO, size * SHURIKEN_PX / 192.0, color.lightened(0.15))
	sh.name = "Shuriken"
	sh.rotation = randf() * TAU
	$Stage/FX.add_child(n)
	create_tween().tween_property(n, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if life > 0.0:
		var rt := create_tween()
		rt.set_parallel(true)
		rt.tween_property(ring, "scale", Vector2.ONE * (RING_END * size * SHURIKEN_PX / RING_IMAGE_PX), life * PACE)
		rt.tween_property(ring, "modulate", Color(color.lerp(Color.WHITE, 0.55), 1.0), life * PACE)
	_lights.append(n)
	AudioManager.play_sfx("target_spawn", randf_range(0.95, 1.1), -10.0)
	return n

## A red copy: the Quiet's dagger, flickering in beside the true lights and
## drifting slowly across. Built the way Quick Draw builds a decoy.
func _copy(pos: Vector2, drift: Vector2 = Vector2(-30, 12)) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.rotation = drift.angle()
	n.modulate.a = 0.0
	n.scale = Vector2(0.7, 0.7)
	_sprite(n, "res://graphics/gen/glow.png", Vector2.ZERO, 0.48, Color(Globals.RED, 0.28), true)
	_sprite(n, "res://graphics/gen/tip_glow.png", Vector2(34, 0), 2.5, Color(Globals.RED, 0.9), true)
	var sw := _sprite(n, "res://graphics/skeleton_sword.png", Vector2.ZERO, 1.55, Color(1.0, 0.35, 0.42, 1.0))
	sw.rotation = 0.785398
	n.set_meta("drift", drift)
	$Stage/FX.add_child(n)
	# The Quiet's work flickers before it holds.
	var t := create_tween()
	t.tween_property(n, "modulate:a", 1.0, 0.06)
	t.tween_property(n, "modulate:a", 0.2, 0.05)
	t.tween_property(n, "modulate:a", 1.0, 0.08)
	t.tween_property(n, "modulate:a", 0.45, 0.05)
	t.tween_property(n, "modulate:a", 1.0, 0.1)
	create_tween().tween_property(n, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT)
	_copies.append(n)
	AudioManager.play_sfx("target_spawn", 0.72, -12.0)
	return n

## Strike a light (or, once, a copy): the pop Quick Draw uses, a burst and the sound.
func _strike(n: Node2D, color: Color, sfx: String = "target_hit", pitch: float = 1.0) -> void:
	if not is_instance_valid(n):
		return
	_lights.erase(n)
	_copies.erase(n)
	_burst(n.position, color, 36, 300.0)
	AudioManager.play_sfx(sfx, pitch, -4.0)
	n.z_index = 3
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(n, "scale", n.scale * 1.55, 0.14).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 0.0, 0.14)
	t.chain().tween_callback(n.queue_free)

## Let a light or a copy leave quietly: a copy times out, a light is left alone.
func _leave(n: Node2D, dur: float = 0.25) -> void:
	if not is_instance_valid(n):
		return
	_lights.erase(n)
	_copies.erase(n)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(n, "modulate:a", 0.0, dur)
	t.tween_property(n, "scale", n.scale * 0.7, dur)
	t.chain().tween_callback(n.queue_free)

func _leave_all(dur: float = 0.3) -> void:
	for n in _lights.duplicate():
		_leave(n, dur)
	for n in _copies.duplicate():
		_leave(n, dur)

## A lantern gutters: its flame stutters and settles lower.
func _gutter(i: int) -> void:
	var g := _lantern_glow(i)
	var l := _lantern(i)
	var seq := [[0.06, 0.08], [0.5, 0.12], [0.04, 0.09], [0.35, 0.16], [0.02, 0.1], [0.22, 0.5]]
	var tg := create_tween()
	var tl := create_tween()
	for s in seq:
		tg.tween_property(g, "modulate:a", s[0], s[1])
		tl.tween_property(l, "modulate:a", 0.4 + s[0], s[1])
	AudioManager.play_sfx("swap_fail", 0.7, -14.0)

func _tick(delta: float) -> void:
	for n in _lights:
		if is_instance_valid(n):
			n.get_node("Shuriken").rotation += delta * 2.6
	for n in _copies:
		if is_instance_valid(n):
			var d: Vector2 = n.get_meta("drift")
			n.position += d * delta

# ---------------------------------------------------------------- the film

func _shot_tonight() -> void:
	_cam(1.06, Vector2(0, 20), 0.0)
	_cam(1.0, Vector2.ZERO, 7.0)
	await _fade(0.0, 1.2)
	_caption("The Quiet cannot make light. It can only copy what it has already taken.")
	await _wait(1.0)
	_light(_c + Vector2(40, -200), Globals.CYAN, 5.0)
	_old.set_facing(true)
	_pip.set_mood("happy")
	await _wait(2.8)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_copies() -> void:
	_advance = false
	_caption("The copies come out red. A hand that answers a lie is a hand out of position.")
	_cam(1.08, Vector2(0, 40), 6.0)
	_light(_c + Vector2(-300, -170), Globals.GOLD, 5.0)
	await _wait(0.35)
	_light(_c + Vector2(330, -240), Globals.CYAN, 5.0)
	await _wait(0.5)
	var spots := [Vector2(-150, -270), Vector2(170, -140), Vector2(440, -130), Vector2(-430, -110)]
	for i in spots.size():
		_copy(_c + spots[i], Vector2(-26 + i * 8, 10 - i * 5))
		await _wait(0.16)
	_old.set_mood("think")
	_pip.set_mood("think")
	await _wait(2.0)
	_hint(true)
	await _wait(1.6)
	_leave_all(0.3)
	_clear_caption()

func _shot_answered() -> void:
	_advance = false
	_caption("Kuro answered one once, a long way from here. He will not say what it cost.")
	_cam(1.16, Vector2(0, 50), 7.0)
	# The swirl, and the dojo falling back a century and a long way off.
	_swirl.position = _c + Vector2(0, -40)
	for i in 28:
		var a := i * TAU / 28.0
		var r := 380.0 + (i % 3) * 60.0
		var dot := _sprite(_swirl, "res://graphics/gen/dot.png", Vector2.from_angle(a) * r, 0.0, Color(0.9, 0.93, 1.0, 0.8), true)
		create_tween().tween_property(dot, "scale", Vector2(1.6, 1.6), 0.5 * PACE).set_delay(i * 0.03 * PACE)
	_swirl_on = true
	AudioManager.play_sfx("whoosh", 0.7, -8.0)
	await _wait(1.0)
	_young = _actor("young", _old.position, 0.72, true, "neutral")
	_young.modulate.a = 0.0
	var xf := create_tween()
	xf.set_parallel(true)
	xf.tween_property(_young, "modulate:a", 1.0, 1.2 * PACE)
	xf.tween_property(_old, "modulate:a", 0.0, 1.2 * PACE)
	xf.tween_property(_pip, "modulate:a", 0.0, 0.8 * PACE)
	_tween_alpha($Stage/Far/Torii, 0.4, 1.2 * PACE)
	_tween_alpha($Stage/Mid/Platform, 0.55, 1.2 * PACE)
	for i in 2:
		_tween_alpha(_lantern(i), 1.0, 1.2 * PACE)
		_tween_alpha(_lantern_glow(i), 0.55, 1.2 * PACE)
	await _wait(1.4)
	# A copy, and the young hand that answered it.
	var lie := _copy(_young.position + Vector2(190, -170), Vector2(-18, 6))
	await _wait(0.7)
	_young.set_mood("excited")
	var lunge := create_tween()
	lunge.tween_property(_young, "position:x", _young.position.x + 70, 0.12).set_ease(Tween.EASE_OUT)
	lunge.tween_property(_young, "position:x", _young.position.x, 0.5).set_delay(0.3).set_ease(Tween.EASE_IN_OUT)
	_young.hop(1.3)
	await _wait(0.16)
	_strike(lie, Globals.RED, "decoy_hit", 1.0)
	AudioManager.vibrate(40)
	# ...and the stagger. The lantern feels it too.
	_young.set_mood("think")
	var wob := create_tween()
	wob.tween_property(_young, "rotation", 0.32, 0.12).set_ease(Tween.EASE_OUT)
	wob.tween_property(_young, "rotation", -0.24, 0.18).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(_young, "rotation", 0.14, 0.18).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(_young, "rotation", -0.06, 0.16).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(_young, "rotation", 0.0, 0.14).set_ease(Tween.EASE_OUT)
	_gutter(1)
	await _wait(1.4)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_one() -> void:
	_advance = false
	# Back to tonight: the swirl goes, old Kuro returns, the second lantern is out again.
	_swirl_on = false
	var st := create_tween()
	for dot in _swirl.get_children():
		st.parallel().tween_property(dot, "modulate:a", 0.0, 0.6)
	var xf := create_tween()
	xf.set_parallel(true)
	xf.tween_property(_old, "modulate:a", 1.0, 1.0 * PACE)
	xf.tween_property(_young, "modulate:a", 0.0, 1.0 * PACE)
	xf.tween_property(_pip, "modulate:a", 1.0, 1.0 * PACE)
	xf.chain().tween_callback(_retire.bind(_young))
	_tween_alpha($Stage/Far/Torii, 1.0, 1.0 * PACE)
	_tween_alpha($Stage/Mid/Platform, 1.0, 1.0 * PACE)
	_tween_alpha(_lantern(1), 0.0, 1.0 * PACE)
	_tween_alpha(_lantern_glow(1), 0.0, 1.0 * PACE)
	_tween_alpha(_lantern(0), 0.75, 1.0 * PACE)
	_tween_alpha(_lantern_glow(0), 0.36, 1.0 * PACE)
	_cam(1.08, Vector2(0, 30), 5.0)
	_caption("Now he counts to one before he strikes.")
	_old.set_mood("think")
	await _wait(1.0)
	var truth := _light(_c + Vector2(210, -200), Globals.CYAN, 3.0)
	_copy(_c + Vector2(-190, -240), Vector2(-14, 8))
	await _wait(0.5)
	_one = _label("ONE.", _old.position + Vector2(-175, -135), 36, Globals.ORANGE, 200.0)
	_one.modulate.a = 0.0
	_one.pivot_offset = _one.size * 0.5
	_one.scale = Vector2(0.6, 0.6)
	var ot := create_tween()
	ot.set_parallel(true)
	ot.tween_property(_one, "modulate:a", 1.0, 0.2)
	ot.tween_property(_one, "scale", Vector2.ONE, 0.35 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("pad_5", 1.0, -8.0)
	await _wait(0.9)
	_old.set_mood("happy")
	_old.hop(1.2)
	_strike(truth, Globals.CYAN, "target_hit", 1.0)
	_flash(0.45)
	AudioManager.vibrate(30)
	_pip.set_mood("excited")
	await _wait(0.4)
	for n in _copies.duplicate():
		_leave(n, 0.35)
	_hint(true)
	await _wait(1.8)
	_tween_alpha(_one, 0.0, 0.4)
	_clear_caption()

func _shot_pip() -> void:
	_advance = false
	_caption("Score twenty and the Seal of the True Light is yours. Do not answer a lie.")
	_cam(1.1, Vector2(-50, 20), 5.0)
	_old.set_mood("neutral")
	_pip.set_mood("excited")
	_pip.set_facing(false)
	await _wait(0.5)
	_light(_c + Vector2(40, -210), Globals.CYAN, 0.0)
	_pip.hop(1.2)
	await _wait(2.2)
	_old.set_mood("happy")
	_hint(true)
	await _wait(1.6)
	_clear_caption()
