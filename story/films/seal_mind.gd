extends "res://story/films/mind.gd"
## Chapter II's seal film: the Seal of the Gathered, earned by clearing level 3
## of Shuriken Match. Shurikens come home in threes, the third pillar rises with
## its glyph and a gold seal, and Kuro is tired rather than bitter. Four shots;
## plays once, on the hub, when the seal is earned.

## The groups of three that come home in the first shot (hook indices) and their colours.
const HOMECOMING := [[16, 17, 18], [27, 28, 29], [32, 33, 34], [35, 36, 37]]
const HOMECOMING_COLORS := [0, 2, 3, 5]
const PILLAR_GLYPHS := ["eye", "mind", "memory", "blade"]
const PILLAR_SCALE := 0.62
const RING_SCALE := 0.44

var _pillar: Sprite2D           # the second pillar, waiting below the stage
var _glyph: Sprite2D            # its glyph

func film_id() -> String:
	return "seal_mind"

func _shots() -> Array:
	return [_shot_home, _shot_seal, _shot_tired, _shot_end]

func _dress() -> void:
	_set_title("SEAL OF THE GATHERED", "CHAPTER II COMPLETE", "Two seals buy the truth.", [["glyph_mind", Globals.GOLD]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	$Stage/Mid/Platform.scale = Vector2(1.3, 1.0)
	_build_wall()
	# Eighty years of gathering plus the three from the opening: two rows and a bit.
	for i in 2 * COLS:
		_hang(i, _gem((i % COLS) / 3 + (i / COLS) * 2))
	for i in KURO_THREE:
		_hang(i, _gem(KURO_COLOR))
	for i in [24, 25, 26]:
		_hang(i, _gem(3))
	# Chapter I (the Eye) is done: its pillar already stands, sealed in gold.
	_build_pillar(0, true)
	_pillar = _build_pillar(1, false)
	_old = _actor("sensei", _c + Vector2(-330, 62), 0.72, true, "happy")
	_pip = _actor("pip", _c + Vector2(-195, 92), 0.62, true, "happy")

func _accent(i: int) -> Color:
	return [Globals.ORANGE, Globals.MAGENTA, Globals.VIOLET, Globals.CYAN][i]

## The prologue's pillar positions, and the glyph's slot on a pillar.
func _pillar_x(i: int) -> float:
	return -40.0 + i * 126.0

func _slot_dy() -> float:
	return -44.0 * PILLAR_SCALE

## A trial pillar; `standing` puts it up with its glyph and a gold seal already
## on it, otherwise it waits below the stage with its glyph folded away.
func _build_pillar(i: int, standing: bool) -> Sprite2D:
	var y := 70.0 if standing else 420.0
	var p := _sprite($Stage/Mid, "pillar", _c + Vector2(_pillar_x(i), y), PILLAR_SCALE)
	p.name = "Pillar%d" % i
	var slot := p.position + Vector2(0, _slot_dy())
	var g := _sprite($Stage/FX, "glyph_" + PILLAR_GLYPHS[i], slot, 0.4 if standing else 0.0, _accent(i), true)
	g.name = "TrialGlyph%d" % i
	_sprite(g, GLOW, Vector2.ZERO, 0.8, Color(_accent(i), 0.55), true)
	if standing:
		_seal_ring(slot, 0.0)
	else:
		_glyph = g
	return p

## The gold seal: a ring with a glow around a pillar's glyph; `grow` > 0 scales it in.
func _seal_ring(slot: Vector2, grow: float) -> Sprite2D:
	var ring := _sprite($Stage/FX, "seal_ring", slot, 0.0 if grow > 0.0 else RING_SCALE, Globals.GOLD)
	_sprite(ring, GLOW, Vector2.ZERO, 1.1, Color(Globals.GOLD, 0.4), true)
	if grow > 0.0:
		create_tween().tween_property(ring, "scale", Vector2(RING_SCALE, RING_SCALE), grow * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return ring

## Three of a colour fly in from outside the dojo and settle on three hooks.
func _fly_in(hooks: Array, col: Color, from: Vector2, delay: float, sfx: String) -> void:
	for k in hooks.size():
		var s := _sprite(_wall, SHURIKEN, from + Vector2(k * 44.0 - 44.0, 0), 0.26, col)
		var g := _sprite(s, GLOW, Vector2.ZERO, 0.5, Color(col, 0.45), true)
		s.modulate.a = 0.0
		_hung[hooks[k]] = s
		var t := create_tween()
		t.tween_interval((delay + k * 0.06) * PACE)
		t.tween_property(s, "modulate:a", 1.0, 0.08)
		t.tween_property(s, "position", _hook_pos(hooks[k]), 0.55 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(s, "rotation", TAU * 2.0, 0.55 * PACE)
		t.parallel().tween_property(s, "scale", Vector2(WALL_SCALE, WALL_SCALE), 0.55 * PACE)
		t.parallel().tween_property(g, "modulate:a", 0.0, 0.55 * PACE)
		if k == hooks.size() - 1:
			t.tween_callback(func():
				AudioManager.play_sfx(sfx, 1.0, -6.0)
				_burst(_hook_pos(hooks[1]), col, 18, 200.0))

# ---------------------------------------------------------------- the film

func _shot_home() -> void:
	_cam(1.06, Vector2(0, 10), 0.0)
	_cam(1.0, Vector2.ZERO, 7.0)
	await _fade(0.0, 1.0)
	_caption("Three levels. Order out of scatter, three at a time.")
	await _wait(0.4)
	for k in HOMECOMING.size():
		var side := 1.0 if k % 2 == 0 else -1.0
		var from := _c + Vector2(820.0 * side, randf_range(-160.0, 80.0))
		_fly_in(HOMECOMING[k], _gem(HOMECOMING_COLORS[k]), from, k * 0.5, "match" if k < 2 else "combo")
	_pip.set_mood("excited")
	await _wait(2.0)
	_old.hop(0.6)
	_hint(true)
	await _wait(1.2)
	_clear_caption()

func _shot_seal() -> void:
	_advance = false
	_caption("The Seal of the Gathered.")
	_cam(1.1, Vector2(-60, 40), 5.0)
	var slot_y := _c.y + 70.0 + _slot_dy()
	var rise := create_tween()
	rise.tween_property(_pillar, "position:y", _c.y + 70.0, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.parallel().tween_property(_glyph, "position:y", slot_y, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_property(_glyph, "scale", Vector2(0.4, 0.4), 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_callback(func(): AudioManager.play_sfx("pad_6", 1.0, -6.0))
	AudioManager.play_sfx("rise", 0.8, -8.0)
	await _wait(1.0)
	var slot := Vector2(_pillar.position.x, slot_y)
	_seal_ring(slot, 0.45)
	AudioManager.play_sfx("seal", 1.0, -4.0)
	_flash()
	_burst(slot, Globals.GOLD, 60, 360.0)
	AudioManager.vibrate(50)
	_old.point_at(slot)
	_pip.hop(1.0)
	await _wait(0.5)
	_hint(true)
	await _wait(1.2)
	_old.unpoint()
	_clear_caption()

func _shot_tired() -> void:
	_advance = false
	_caption("A piece of eighty years of Kuro's work, done before dinner.")
	_cam(1.16, Vector2(120, 60), 6.0)
	_old.set_mood("think")
	_old.set_facing(false)
	_pip.set_mood("happy")
	await _wait(1.9)
	_caption("He is not bitter. He is tired.")
	_pip.set_mood("neutral")
	await _wait(0.4)
	_hint(true)
	await _wait(1.4)
	_clear_caption()

func _shot_end() -> void:
	await _shot_title(2.8)
