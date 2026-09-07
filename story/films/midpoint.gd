extends Film
## The turn: with two seals the ninja has earned the truth about what they have
## been dodging. Every dagger of light was a star; the Quiet unmade them and
## kept the edges. Pip came through them whole, and nothing else ever has.
## Five shots; plays once on the hub at two seals, chained after the seal film.

const KURO_HOME := Vector2(-60, 62)
const PIP_HOME := Vector2(90, 92)
const BLADE_AT := Vector2(-320, -180)   # where the dagger hangs: over the sealed side

var _old: Mascot
var _pip: Mascot
var _blade: Node2D
var _blade_spin := 0.0
var _rings: Array = []
var _clock := 0.0

func film_id() -> String:
	return "midpoint"

func _shots() -> Array:
	return [_shot_seals, _shot_star, _shot_pip, _shot_whole, _shot_title]

func _dress() -> void:
	_set_title("THE TURN", "TWO SEALS", "The daggers are what the Quiet leaves of a star.",
		[["glyph_blade", Globals.GOLD], ["glyph_eye", Globals.GOLD]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.35, 1.0)
	# The first two seals stand on the dojo's left, clear of the lanterns.
	_sealed_pillar(-345.0, "blade", Globals.CYAN)
	_sealed_pillar(-260.0, "eye", Globals.ORANGE)
	_old = _actor("sensei", _c + KURO_HOME, 0.72, false, "neutral")
	_pip = _actor("pip", _c + PIP_HOME, 0.62, false, "happy")
	# The dagger waits above the top bar until the second shot.
	_blade = _dagger(_c + BLADE_AT + Vector2(0, -300), Globals.CYAN)
	_blade.rotation = PI / 2
	_blade.modulate.a = 0.0

## A sealed pillar: the stone, its glyph in the trial's colour, and a gold seal
## ring (with a glow) around the glyph. Returns the ring.
func _sealed_pillar(x: float, glyph: String, accent: Color) -> Sprite2D:
	var pillar := _sprite($Stage/Mid, "pillar", _c + Vector2(x, 70), 0.62)
	var slot := pillar.position + Vector2(0, -44 * 0.62)
	var g := _sprite($Stage/FX, "glyph_" + glyph, slot, 0.4, accent, true)
	_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.8, Color(accent, 0.5), true)
	var ring := _sprite($Stage/FX, "seal_ring", slot, 0.5, Globals.GOLD, true)
	_sprite(ring, "res://graphics/gen/glow.png", Vector2.ZERO, 1.1, Color(Globals.GOLD, 0.35), true)
	_rings.append(ring)
	return ring

## A dagger of light, its tip along +x: the skeleton sword with a glowing tip,
## plus a hidden star form (a gold star in a glow) for the truth.
func _dagger(pos: Vector2, col: Color) -> Node2D:
	var d := Node2D.new()
	d.position = pos
	var sw := Sprite2D.new()
	sw.name = "Sword"
	sw.texture = _t("res://graphics/skeleton_sword.png")
	sw.rotation = 0.785398
	sw.scale = Vector2(1.6, 1.6)
	sw.modulate = Color.WHITE.lerp(col, 0.3)
	d.add_child(sw)
	var tip := _sprite(d, "res://graphics/gen/tip_glow.png", Vector2(50, 0), 3.0, Color(col, 0.9), true)
	tip.name = "Tip"
	var star := Node2D.new()
	star.name = "Star"
	star.scale = Vector2.ZERO
	_sprite(star, "res://graphics/gen/glow.png", Vector2.ZERO, 0.9, Color(Globals.GOLD, 0.6), true)
	_sprite(star, "res://graphics/gen/player_star.png", Vector2.ZERO, 1.0, Globals.GOLD)
	d.add_child(star)
	$Stage/FX.add_child(d)
	return d

## The dagger dissolves into a star (on) or the Quiet takes it back (off).
func _star_form(on: bool) -> void:
	var sw: Sprite2D = _blade.get_node("Sword")
	var tip: Sprite2D = _blade.get_node("Tip")
	var star: Node2D = _blade.get_node("Star")
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(sw, "modulate:a", 0.0 if on else 1.0, 0.45 * PACE)
	t.tween_property(tip, "modulate:a", 0.0 if on else 0.9, 0.45 * PACE)
	if on:
		t.tween_property(star, "scale", Vector2(0.62, 0.62), 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		t.tween_property(star, "scale", Vector2.ZERO, 0.4 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_burst(_blade.position, Globals.GOLD if on else Globals.RED, 44 if on else 30, 300.0)
	AudioManager.play_sfx("star_ding" if on else "shatter", 1.0 if on else 0.8, -6.0)
	if not on:
		_flash(0.25)

## A seal ring swells once, with a tone.
func _pulse(ring: Sprite2D, delay: float, sfx: String) -> void:
	var t := create_tween()
	t.tween_interval(delay * PACE)
	t.tween_callback(func(): AudioManager.play_sfx(sfx, 1.0, -8.0))
	t.tween_property(ring, "scale", Vector2(0.64, 0.64), 0.22 * PACE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "scale", Vector2(0.5, 0.5), 0.45 * PACE).set_ease(Tween.EASE_IN_OUT)

func _tick(delta: float) -> void:
	_clock += delta
	for r in _rings:
		r.rotation += delta * 0.35
	if _blade != null and is_instance_valid(_blade):
		_blade.rotation += delta * _blade_spin

# ---------------------------------------------------------------- the film

func _shot_seals() -> void:
	_cam(1.0, Vector2.ZERO, 0.0)
	_cam(1.06, Vector2(40, 20), 8.0)
	await _fade(0.0, 1.0)
	_caption("Two seals. Kuro decided the ninja had earned the truth.")
	await _wait(0.8)
	for i in _rings.size():
		_pulse(_rings[i], i * 0.35, "pad_%d" % [i * 2 + 2])
	_old.point_at(_rings[0].global_position)
	await _wait(1.3)
	_hint(true)
	await _wait(1.2)
	_old.unpoint()
	_clear_caption()

func _shot_star() -> void:
	_advance = false
	_caption("Every dagger of light was a star. The Quiet unmade them and kept the edges.")
	_cam(1.1, Vector2(130, 70), 6.0)
	_old.set_facing(false)
	_old.set_mood("think")
	_pip.set_mood("neutral")
	# A dagger falls in like the others, and stops in the air.
	AudioManager.play_sfx("whoosh", 0.8, -10.0)
	_blade.modulate.a = 1.0
	var fall := create_tween()
	fall.tween_property(_blade, "position", _c + BLADE_AT, 1.1 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	fall.tween_callback(func(): AudioManager.play_sfx("rise", 0.9, -12.0))
	_blade_spin = 0.55
	await _wait(2.3)
	_star_form(true)
	await _wait(1.4)
	_star_form(false)
	_hint(true)
	await _wait(1.3)
	_clear_caption()

func _shot_pip() -> void:
	_advance = false
	_caption("Pip had been calling them light. The whole time. Out loud.")
	_cam(1.2, Vector2(-108, 10), 5.0)
	_pip.set_mood("neutral")
	await _wait(0.9)
	_pip.set_mood("think")
	AudioManager.play_sfx("swap_fail", 0.7, -14.0)
	_grow(_pip, 0.62, 0.5, 0.4)
	await _wait(1.0)
	_grow(_pip, 0.5, 0.62, 0.5)
	AudioManager.play_sfx("pad_5", 1.0, -10.0)
	_hint(true)
	await _wait(1.4)
	_clear_caption()

func _shot_whole() -> void:
	_advance = false
	_caption("Pip came through them whole. Nothing else ever has. That is why they keep coming.")
	_cam(1.08, Vector2(0, 30), 7.0)
	_old.set_facing(true)
	_old.set_mood("neutral")
	_old.hop(0.5)
	_pip.set_facing(false)
	# The dagger drifts back up into the dark.
	_blade_spin = 0.3
	var away := create_tween()
	away.set_parallel(true)
	away.tween_property(_blade, "modulate:a", 0.0, 1.6 * PACE)
	away.tween_property(_blade, "position:y", _blade.position.y - 120.0, 1.6 * PACE).set_ease(Tween.EASE_IN)
	await _wait(3.3)
	_caption("Then we do not lose. Two more.")
	_pip.set_mood("excited")
	_old.set_mood("happy")
	await _wait(0.7)
	_pip.hop(1.2)
	_hint(true)
	await _wait(1.4)
	_clear_caption()
