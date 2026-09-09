extends "res://story/films/name.gd"
## Chapter III's seal: round five held whole, and the third pillar rises with
## the Seal of the Kept Name beside the three already standing. Plays once, on
## the hub, when the seal is earned.

const SEQ := [3, 7, 0, 5, 2]    # the pattern the ninja held, one pad per round
const GLYPHS := ["eye", "mind", "memory", "blade"]
const PILLAR_SCALE := 0.62

var _pillars: Array = []
var _glyphs: Array = []
var _seals: Array = []          # the ring sprites, turned slowly in _tick
var _round_label: Label

func film_id() -> String:
	return "seal_name"

func _shots() -> Array:
	return [_shot_round, _shot_pillar, _shot_names, _shot_title]

func _dress() -> void:
	_set_title("SEAL OF THE KEPT NAME", "CHAPTER III COMPLETE", "One trial remains.", [["glyph_memory", Globals.GOLD]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.3, 1.0)
	_build_pads(true)
	for i in 3:
		_build_pillar(i, i < 2)
	_old = _actor("sensei", _c + Vector2(-330, 62), 0.72, true, "neutral")
	_pip = _actor("pip", _c + Vector2(-195, 92), 0.62, true, "happy")

func _accent(i: int) -> Color:
	return [Globals.ORANGE, Globals.MAGENTA, Globals.VIOLET, Globals.CYAN][i]

## The prologue's pillar positions, so the seals stand where the trials rose.
func _pillar_x(i: int) -> float:
	return -40.0 + i * 126.0

func _slot_y() -> float:
	return _c.y + 70.0 - 44.0 * PILLAR_SCALE

## Pillar i with its glyph: standing and sealed (chapters already done) or
## waiting below the platform to rise.
func _build_pillar(i: int, standing: bool) -> void:
	var x := _c.x + _pillar_x(i)
	var y := _c.y + 70.0 if standing else _c.y + 420.0
	var pillar := _sprite($Stage/Mid, "pillar", Vector2(x, y), PILLAR_SCALE)
	pillar.name = "Pillar%d" % i
	var g := _sprite($Stage/FX, "glyph_" + GLYPHS[i], Vector2(x, y - 44.0 * PILLAR_SCALE), 0.4 if standing else 0.0, _accent(i), true)
	g.name = "TrialGlyph%d" % i
	_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.8, Color(_accent(i), 0.55), true)
	_pillars.append(pillar)
	_glyphs.append(g)
	if standing:
		_seal_ring(i, false)

## A gold seal ring with a glow around pillar i's glyph; `stamp` drops it in.
func _seal_ring(i: int, stamp: bool) -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(_c.x + _pillar_x(i), _slot_y())
	$Stage/FX.add_child(n)
	_sprite(n, "res://graphics/gen/glow.png", Vector2.ZERO, 0.5, Color(Globals.GOLD, 0.35), true)
	var ring := _sprite(n, "seal_ring", Vector2.ZERO, 0.46, Globals.GOLD)
	ring.rotation = i * 0.7
	_seals.append(ring)
	if stamp:
		n.scale = Vector2(2.2, 2.2)
		n.modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(n, "scale", Vector2.ONE, 0.35 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_property(n, "modulate:a", 1.0, 0.25 * PACE)
	return n

func _tick(delta: float) -> void:
	for r in _seals:
		r.rotation += delta * 0.25

func _set_round(r: int) -> void:
	_round_label.text = "ROUND %d" % r
	_round_label.modulate.a = 1.0
	_round_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_round_label, "scale", Vector2.ONE, 0.25 * PACE).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("simon_round", 1.0 + (r - 1) * 0.05, -14.0)

# ---------------------------------------------------------------- the film

func _shot_round() -> void:
	_cam(1.06, Vector2(0, 20), 0.0)
	_cam(1.0, Vector2.ZERO, 8.0)
	await _fade(0.0, 1.0)
	_caption("Round five, held whole when it got long.")
	_round_label = _label("ROUND 1", _c + Vector2(0, -84), 36, Globals.VIOLET, 400.0)
	_round_label.pivot_offset = _round_label.size * 0.5
	_round_label.modulate.a = 0.0
	await _wait(0.3)
	for r in range(1, 6):
		_set_round(r)
		for k in r:
			_light_pad(SEQ[k])
			await _wait(0.15)
		await _wait(0.2)
	# Round five lands, whole.
	_round_label.add_theme_color_override("font_color", Globals.GOLD)
	_round_label.scale = Vector2(1.7, 1.7)
	create_tween().tween_property(_round_label, "scale", Vector2.ONE, 0.45 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("record", 1.0, -6.0)
	_burst(_c + Vector2(0, -84), Globals.GOLD, 50, 340.0)
	_flash(0.3)
	_pip.set_mood("excited")
	_old.set_mood("happy")
	await _wait(0.4)
	_hint(true)
	await _wait(1.2)
	_clear_caption()

func _shot_pillar() -> void:
	_advance = false
	_caption("The Seal of the Kept Name.")
	_cam(1.1, Vector2(-60, 40), 6.0)
	_tween_alpha(_round_label, 0.0, 0.5)
	var pillar: Sprite2D = _pillars[2]
	var g: Sprite2D = _glyphs[2]
	var rise := create_tween()
	rise.tween_property(pillar, "position:y", _c.y + 70.0, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.parallel().tween_property(g, "position:y", _slot_y(), 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_property(g, "scale", Vector2(0.4, 0.4), 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("rise", 0.8, -10.0)
	await _wait(0.8)
	AudioManager.play_sfx("pad_8", 1.0, -6.0)
	_old.point_at(g.global_position)
	await _wait(0.4)
	_seal_ring(2, true)
	await _wait(0.3)
	_flash(0.6)
	AudioManager.play_sfx("seal", 1.0, -4.0)
	AudioManager.vibrate(50)
	_burst(Vector2(_c.x + _pillar_x(2), _slot_y()), Globals.GOLD, 50, 340.0)
	_pip.set_mood("excited")
	_hint(true)
	await _wait(1.6)
	_old.unpoint()
	_clear_caption()

func _shot_names() -> void:
	_advance = false
	_caption("Say your own name out loud after. It helps. Kuro taught Pip that.")
	_cam(1.12, Vector2(200, 40), 5.0)
	_old.set_mood("happy")
	_pip.set_mood("happy")
	await _wait(1.4)
	# Pip says it, so it stays.
	var l := _label("PIP", _pip.position + Vector2(0, -150), 22, Globals.GOLD, 160.0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("star_ding", 1.0, -8.0)
	_pip.hop(1.0)
	await _wait(0.3)
	_hint(true)
	await _wait(1.5)
	_clear_caption()
