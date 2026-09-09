extends Film
## The epilogue: four seals, and the star holds. Kuro sits down for the first
## time in a hundred years and gives the dojo away; both lanterns light; Pip
## says his name out loud so that it stays. Seven shots; plays once on the hub
## after the fourth seal.

const KURO_HOME := Vector2(-60, 62)
const PIP_HOME := Vector2(90, 92)

var _old: Mascot
var _pip: Mascot
var _pip_glow: Sprite2D
var _blaze := 1.4               # Pip's glow, in Pip's own scale
var _rings: Array = []
var _clock := 0.0

func film_id() -> String:
	return "epilogue"

func _shots() -> Array:
	return [_shot_four, _shot_alone, _shot_sit, _shot_lanterns, _shot_name, _shot_daggers, _shot_title]

func _dress() -> void:
	_set_title("THE STAR SHINES", "EPILOGUE", "Every trial stays open. Come back. We will keep the light on.",
		[["glyph_eye", Globals.GOLD], ["glyph_mind", Globals.GOLD], ["glyph_memory", Globals.GOLD], ["glyph_blade", Globals.GOLD]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.35, 1.0)
	# The four seals stand two to a side, clear of the lanterns.
	var seals := [[-345.0, "eye", Globals.ORANGE], [-260.0, "mind", Globals.MAGENTA],
		[260.0, "memory", Globals.VIOLET], [345.0, "blade", Globals.CYAN]]
	for s in seals:
		_sealed_pillar(s[0], s[1], s[2])
	_old = _actor("sensei", _c + KURO_HOME, 0.72, true, "happy")
	_pip = _actor("pip", _c + PIP_HOME, 0.62, false, "happy")
	# Pip blazing: a gold glow behind Pip, pulsing in _tick.
	_pip_glow = _sprite(_pip, "res://graphics/gen/glow.png", Vector2(0, -6), _blaze, Color(Globals.GOLD, 0.5), true)
	_pip.move_child(_pip_glow, 0)

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

## A dagger of light, its tip along +x (the prologue's build).
func _dagger(pos: Vector2, col: Color) -> Node2D:
	var d := Node2D.new()
	d.position = pos
	var sw := Sprite2D.new()
	sw.texture = _t("res://graphics/skeleton_sword.png")
	sw.position = Vector2(40, 0)
	sw.rotation = 0.785398
	sw.scale = Vector2(1.6, 1.6)
	sw.modulate = Color.WHITE.lerp(col, 0.3)
	d.add_child(sw)
	_sprite(d, "res://graphics/gen/tip_glow.png", Vector2(60, 0), 3.0, Color(col, 0.9), true)
	$Stage/FX.add_child(d)
	return d

## A seal ring swells once, with a tone.
func _pulse(ring: Sprite2D, delay: float, sfx: String) -> void:
	var t := create_tween()
	t.tween_interval(delay * PACE)
	t.tween_callback(func(): AudioManager.play_sfx(sfx, 1.0, -8.0))
	t.tween_property(ring, "scale", Vector2(0.64, 0.64), 0.22 * PACE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "scale", Vector2(0.5, 0.5), 0.45 * PACE).set_ease(Tween.EASE_IN_OUT)

## Everything but Kuro: the stage layers and Pip.
func _dim_world(a: float, dur: float) -> void:
	for n in [$Stage/Far, $Stage/Mid, $Stage/FX, _pip]:
		_tween_alpha(n, a, dur * PACE)

## Kuro sits: a squash and a drop, and his base scale follows so a later turn
## keeps him seated.
func _sit() -> void:
	var sx := signf(_old.scale.x)
	_old.base_scale = 0.72 * 1.08
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_old, "scale", Vector2(0.72 * 1.08 * sx, 0.72 * 0.86), 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_old, "position:y", _c.y + KURO_HOME.y + 26.0, 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var land := create_tween()
	land.tween_interval(0.3 * PACE)
	land.tween_callback(func():
		AudioManager.play_sfx("tile_land", 0.8, -8.0)
		_burst(_old.position + Vector2(0, 92), Color(1.0, 0.95, 0.85, 0.5), 14, 130.0))

func _warm_flash(strength: float) -> void:
	%Flash.color = Color(1.0, 0.85, 0.55, strength)
	create_tween().tween_property(%Flash, "color:a", 0.0, 0.6)

## Lantern 1 comes back and lantern 0 to full, with a seal and a warm flash.
func _light_lanterns() -> void:
	AudioManager.play_sfx("rise", 1.0, -10.0)
	for i in 2:
		_tween_alpha(_lantern(i), 1.0, 0.7 * PACE)
		var g := _lantern_glow(i)
		var f := create_tween()
		f.tween_property(g, "modulate:a", 0.95, 0.7 * PACE)
		f.tween_property(g, "modulate:a", 0.6, 1.0 * PACE)
	var t := create_tween()
	t.tween_interval(0.55 * PACE)
	t.tween_callback(func():
		AudioManager.play_sfx("seal", 1.0, -6.0)
		_warm_flash(0.5)
		for i in 2:
			_burst(_lantern(i).position, Globals.ORANGE, 30, 240.0))

## A few daggers fall past the far edges of the frame.
func _rain(count: int) -> void:
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * randf_range(560.0, 625.0)
		var col: Color = Globals.RED if i % 2 == 0 else Globals.CYAN
		var d := _dagger(_c + Vector2(x, -440.0), col)
		d.rotation = PI / 2
		var t := create_tween()
		t.tween_interval(i * 0.45 * PACE)
		t.tween_callback(func(): AudioManager.play_sfx("whoosh", randf_range(0.9, 1.2), -14.0))
		t.tween_property(d, "position:y", _c.y + 440.0, 1.3 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_callback(d.queue_free)

func _tick(delta: float) -> void:
	_clock += delta
	for r in _rings:
		r.rotation += delta * 0.35
	if _pip_glow != null:
		var k := _blaze * (1.0 + 0.07 * sin(_clock * 3.1))
		_pip_glow.scale = Vector2(k, k)

# ---------------------------------------------------------------- the film

func _shot_four() -> void:
	_cam(1.0, Vector2.ZERO, 0.0)
	_cam(1.06, Vector2(0, 24), 9.0)
	await _fade(0.0, 1.2)
	_caption("Four seals. The star holds.")
	for i in _rings.size():
		_pulse(_rings[i], 0.3 + i * 0.3, "pad_%d" % [i * 2 + 2])
	await _wait(1.0)
	AudioManager.play_sfx("seal", 1.0, -8.0)
	create_tween().tween_property(self, "_blaze", 1.9, 0.9 * PACE).set_ease(Tween.EASE_OUT)
	_grow(_pip, 0.62, 0.7, 0.8)
	_burst(_pip.position, Globals.GOLD, 40, 260.0)
	_pip.set_mood("excited")
	await _wait(1.4)
	_hint(true)
	await _wait(1.3)
	_clear_caption()

func _shot_alone() -> void:
	_advance = false
	_caption("For ninety years he had been the only thing standing here. Tonight he was not.")
	_cam(1.3, Vector2(78, -40), 4.5)
	_old.set_facing(false)
	_old.set_mood("think")
	_dim_world(0.1, 1.0)
	await _wait(2.6)
	_dim_world(1.0, 1.0)
	_old.set_facing(true)
	_old.set_mood("happy")
	await _wait(0.5)
	_hint(true)
	await _wait(1.4)
	_clear_caption()

func _shot_sit() -> void:
	_advance = false
	_caption("Pip told him to sit down. He had been standing since before Pip fell.")
	_cam(1.15, Vector2(-17, 0), 6.0)
	_pip.set_mood("neutral")
	_pip.set_facing(false)
	_pip.hop(0.8)
	await _wait(1.5)
	_sit()
	await _wait(1.2)
	_old.set_mood("happy")
	_pip.set_mood("happy")
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_lanterns() -> void:
	_advance = false
	_caption("The dojo is the ninja's now. Two lanterns. Light them both. Keep the count.")
	_cam(1.0, Vector2.ZERO, 5.0)
	await _wait(0.9)
	_light_lanterns()
	await _wait(1.6)
	_old.point_at(_lantern(1).global_position)
	await _wait(0.4)
	_hint(true)
	await _wait(1.4)
	_old.unpoint()
	_clear_caption()

func _shot_name() -> void:
	_advance = false
	_caption("Pip says his name out loud, so that it stays.")
	_cam(1.06, Vector2(0, 30), 5.0)
	_pip.set_mood("happy")
	_pip.set_facing(false)
	await _wait(1.0)
	var name_at := _c + Vector2(0, -235)
	var l := _label("KURO.", name_at, 72, Globals.GOLD, 420.0)
	l.add_theme_font_size_override("font_size", 72)
	l.scale = Vector2(0.2, 0.2)
	l.pivot_offset = l.size * 0.5
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("star_ding", 1.0, -4.0)
	_burst(name_at, Globals.GOLD, 50, 340.0)
	_pip.hop(1.2)
	await _wait(1.2)
	_old.set_mood("happy")
	_old.hop(0.4)
	AudioManager.play_sfx("pad_9", 1.0, -8.0)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_daggers() -> void:
	_advance = false
	_caption("The daggers still come. They are no longer the only thing that does.")
	_cam(1.0, Vector2.ZERO, 3.0)
	_rain(5)
	_old.set_mood("neutral")
	_pip.set_mood("happy")
	await _wait(2.6)
	# The lanterns answer.
	for i in 2:
		var g := _lantern_glow(i)
		var f := create_tween()
		f.tween_property(g, "modulate:a", 0.95, 0.3)
		f.tween_property(g, "modulate:a", 0.6, 0.9)
	AudioManager.play_sfx("pad_1", 1.0, -10.0)
	_hint(true)
	await _wait(1.6)
	_clear_caption()
