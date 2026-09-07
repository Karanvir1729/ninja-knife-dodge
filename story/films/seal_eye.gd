extends "res://story/films/eye.gd"
## Chapter II's seal: twenty true lights struck before the Quiet could finish
## a copy, the second pillar rises, and Pip owns up to three flinches. Plays
## once, on the hub, when the Seal of the True Light is earned.

const PILLAR_X := -40.0         # the prologue's first pillar; the rest step right
const PILLAR_STEP := 126.0
const PILLAR_Y := 70.0
const SLOT_DY := -44.0 * 0.62   # the glyph's hole, up the pillar

var _count: Label
var _rings: Array = []          # seal rings, turning slowly

func film_id() -> String:
	return "seal_eye"

func _shots() -> Array:
	return [_shot_twenty, _shot_seal, _shot_flinch, _shot_title]

func _dress() -> void:
	_set_title("SEAL OF THE TRUE LIGHT", "CHAPTER II COMPLETE", "Two seals buy the truth.", [["glyph_eye", Globals.GOLD]])

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.3, 1.0)
	# Chapter I is done: the first pillar already stands, sealed in gold.
	var p0 := _pillar(0, "blade", Globals.CYAN, true)
	_seal_ring(p0.glyph.position, false)
	_old = _actor("sensei", _c + Vector2(-330, 62), 0.72, true, "neutral")
	_pip = _actor("pip", _c + Vector2(-195, 92), 0.62, true, "happy")

## A trial pillar with its glyph in the slot, standing or waiting under the platform.
func _pillar(i: int, glyph: String, accent: Color, standing: bool) -> Dictionary:
	var x := PILLAR_X + i * PILLAR_STEP
	var pillar := _sprite($Stage/Mid, "pillar", _c + Vector2(x, PILLAR_Y if standing else 450.0), 0.62)
	pillar.name = "Pillar%d" % i
	var g := _sprite($Stage/FX, "glyph_" + glyph, pillar.position + Vector2(0, SLOT_DY), 0.4 if standing else 0.0, accent, true)
	g.name = "TrialGlyph%d" % i
	_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.8, Color(accent, 0.55), true)
	return {"pillar": pillar, "glyph": g}

## The gold seal around a glyph, with its glow; `animate` snaps it shut with the seal sound.
func _seal_ring(at: Vector2, animate: bool) -> void:
	var glow := _sprite($Stage/FX, "res://graphics/gen/glow.png", at, 0.7, Color(Globals.GOLD, 0.45), true)
	var ring := _sprite($Stage/FX, "seal_ring", at, 0.5, Globals.GOLD, true)
	_rings.append(ring)
	if not animate:
		return
	glow.scale = Vector2.ZERO
	ring.scale = Vector2(1.6, 1.6)
	ring.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(0.5, 0.5), 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(ring, "modulate:a", 1.0, 0.25)
	t.tween_property(glow, "scale", Vector2(0.7, 0.7), 0.5 * PACE).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("seal", 1.0, -4.0)
	_flash()
	_burst(at, Globals.GOLD, 50, 340.0)

func _tick(delta: float) -> void:
	super(delta)
	for r in _rings:
		if is_instance_valid(r):
			r.rotation += delta * 0.3

# ---------------------------------------------------------------- the film

func _shot_twenty() -> void:
	_cam(1.04, Vector2(0, 20), 0.0)
	_cam(1.0, Vector2(0, 10), 8.0)
	await _fade(0.0, 1.0)
	_caption("Twenty true lights, struck before the Quiet could finish a copy.")
	_count = _label("0", _c + Vector2(500, -200), 64, Globals.GOLD, 240.0)
	_count.pivot_offset = _count.size * 0.5
	_count.modulate.a = 0.0
	_tween_alpha(_count, 1.0, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var cols := [Globals.CYAN, Globals.GOLD, Globals.CYAN, Globals.CYAN, Globals.GOLD]
	var last := Vector2.ZERO
	var prev: Node2D = null
	var prev_col: Color = Globals.CYAN
	for k in 20:
		var at := Vector2.ZERO
		for tries in 8:
			at = _c + Vector2(rng.randf_range(-230.0, 300.0), rng.randf_range(-250.0, -130.0))
			if at.distance_to(last) > 150.0:
				break
		last = at
		var col: Color = cols[k % cols.size()]
		var n := _light(at, col, 0.0)
		if k % 5 == 3:
			# A copy starts beside the lights; nobody answers it, and it fades.
			var cp := _copy(at + Vector2(rng.randf_range(-170.0, 170.0), rng.randf_range(-40.0, 40.0)), Vector2(-20, 8))
			get_tree().create_timer(0.8).timeout.connect(func(): _leave(cp, 0.3))
		if prev != null:
			_strike(prev, prev_col, "target_hit", 1.0 + minf(float(k - 1), 24.0) * 0.025)
			_count.text = str(k)
			_count.scale = Vector2(1.25, 1.25)
			create_tween().tween_property(_count, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)
			if k % 5 == 1:
				_old.hop(0.7)
		prev = n
		prev_col = col
		await _wait(0.12)
	_strike(prev, prev_col, "target_hit", 1.5)
	_count.text = "20"
	_count.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(_count, "scale", Vector2.ONE, 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("record", 1.0, -6.0)
	_flash(0.35)
	_old.set_mood("happy")
	_old.hop(1.0)
	_pip.set_mood("excited")
	await _wait(1.1)
	_hint(true)
	await _wait(0.9)
	_clear_caption()

func _shot_seal() -> void:
	_advance = false
	_caption("The Seal of the True Light.")
	_cam(1.1, Vector2(-30, 30), 5.0)
	_tween_alpha(_count, 0.0, 0.4)
	var p := _pillar(1, "eye", Globals.ORANGE, false)
	var slot := _c + Vector2(PILLAR_X + PILLAR_STEP, PILLAR_Y + SLOT_DY)
	var rise := create_tween()
	rise.tween_property(p.pillar, "position:y", _c.y + PILLAR_Y, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.parallel().tween_property(p.glyph, "position:y", slot.y, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_property(p.glyph, "scale", Vector2(0.4, 0.4), 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_callback(func(): AudioManager.play_sfx("pad_4", 1.0, -6.0))
	AudioManager.play_sfx("rise", 0.8, -10.0)
	await _wait(1.0)
	_seal_ring(slot, true)
	_old.point_at(slot)
	await _wait(1.2)
	_hint(true)
	await _wait(1.2)
	_old.unpoint()
	_clear_caption()

func _shot_flinch() -> void:
	_advance = false
	_caption("Pip flinched at three of the red ones. From the back. Sitting down.")
	_cam(1.16, Vector2(120, 50), 5.0)
	_old.set_mood("happy")
	_pip.set_mood("think")
	await _wait(0.6)
	var lie := _copy(_pip.position + Vector2(60, -200), Vector2(-16, 6))
	await _wait(0.4)
	# The flinch: a jolt back and a small hop, from a safe distance.
	var f := create_tween()
	f.tween_property(_pip, "position:x", _pip.position.x - 22.0, 0.08).set_ease(Tween.EASE_OUT)
	f.tween_property(_pip, "position:x", _pip.position.x, 0.35).set_ease(Tween.EASE_IN_OUT)
	_pip.hop(0.5)
	await _wait(0.7)
	_leave(lie, 0.3)
	_old.hop(0.4)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_title(hold: float = 2.3, sfx: String = "seal") -> void:
	await super(hold, sfx)
