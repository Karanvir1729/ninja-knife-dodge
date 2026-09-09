extends "res://story/films/blade.gd"
## Chapter IV's seal film: twenty-five daggers through one patch of empty air,
## the last pillar rising on the very spot they missed beside the three seals
## already standing, and the last lantern brightening a touch. Plays once, on
## the hub, when the Seal of Empty Air is earned.

const PATCH := Vector2(345.0, -10.0)    # the empty patch of air, relative to _c
## The trials that come before the Blade, laid out as the epilogue lays them:
## trial id, glyph, colour. Only the ones actually sealed are staged.
const STANDING := [[-345.0, "draw", "eye", Globals.ORANGE], [-260.0, "match", "mind", Globals.MAGENTA], [260.0, "simon", "memory", Globals.VIOLET]]
const COUNT := 25

var _counter: Label
var _shown := 0
var _pillar: Sprite2D
var _glyph: Sprite2D
var _glyph_glow: Sprite2D

func film_id() -> String:
	return "seal_blade"

func _shots() -> Array:
	return [_shot_count, _shot_seal, _shot_lantern, _shot_title.bind(2.8)]

func _dress() -> void:
	var closing := "Four seals. The star holds." if Story.seals_count() >= Story.ORDER.size() else "The daggers found empty air."
	_set_title("SEAL OF EMPTY AIR", "CHAPTER IV COMPLETE", closing, [["glyph_blade", Globals.GOLD]])

func _build_extra() -> void:
	_show_dojo(0.0)
	# A wider platform, as when the pillars rose in the prologue. No hunters
	# tonight: the guides stand between the last lantern and the patch of air
	# to their right, so the lantern stays in view for the final shot.
	$Stage/Mid/Platform.scale = Vector2(1.35, 1.0)
	for s in STANDING:
		if Story.seal_earned(str(s[1])):
			_sealed_pillar(s[0], str(s[2]), s[3])
	_old = _actor("sensei", _c + Vector2(-60, 62), 0.72, true, "happy")
	_pip = _actor("pip", _c + Vector2(80, 92), 0.62, true, "happy")

## A trial already sealed: the stone, its glyph in the trial's colour, and the
## gold ring around it.
func _sealed_pillar(x: float, glyph: String, accent: Color) -> void:
	var pillar := _sprite($Stage/Mid, "pillar", _c + Vector2(x, 70), 0.62)
	var slot := pillar.position + Vector2(0, -44 * 0.62)
	var g := _sprite($Stage/FX, "glyph_" + glyph, slot, 0.4, accent, true)
	_sprite(g, GLOW, Vector2.ZERO, 0.8, Color(accent, 0.5), true)
	_sprite($Stage/FX, GLOW, slot, 0.7, Color(Globals.GOLD, 0.4), true)
	_sprite($Stage/FX, "seal_ring", slot, 0.58, Globals.GOLD, true)

## The counter climbs; only ever upward, however the taps land.
func _count(n: int) -> void:
	if _counter == null or n <= _shown:
		return
	_shown = n
	_counter.text = str(n)
	var big := n == COUNT
	if big:
		_counter.add_theme_color_override("font_color", Globals.GOLD)
	_counter.scale = Vector2(1.5, 1.5) if big else Vector2(1.25, 1.25)
	var t := create_tween()
	t.tween_property(_counter, "scale", Vector2.ONE, 0.32 if big else 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK if big else Tween.TRANS_QUAD)
	if big:
		AudioManager.play_sfx("record", 1.0, -6.0)
		_burst(_counter.position + _counter.size * 0.5, Globals.GOLD, 46, 320.0)
		_pip.set_mood("excited")
		_old.hop(0.6)
	else:
		AudioManager.play_sfx("tile_land", 1.0 + n * 0.03, -20.0)

# ---------------------------------------------------------------- the film

func _shot_count() -> void:
	_cam(1.05, Vector2(-30, 24), 0.0)
	_cam(1.0, Vector2(-10, 10), 7.0)
	await _fade(0.0, 0.9)
	_caption("Twenty-five daggers, and every one of them found empty air.")
	var patch := _c + PATCH
	_counter = _label("0", patch + Vector2(0, -180), 46, Globals.CYAN, 240.0)
	_counter.pivot_offset = _counter.size * 0.5
	_counter.modulate.a = 0.0
	_tween_alpha(_counter, 1.0, 0.3)
	await _wait(0.3)
	for i in COUNT:
		if _advance:
			break
		var ang := -0.62 + 0.95 * fmod(i * 0.618034, 1.0)      # from the right, above or below
		var dir := Vector2.from_angle(ang)
		var over := 5.0 + 20.0 * fmod(i * 0.381966, 1.0)   # stop short of the sealed pillars
		var col: Color = Globals.CYAN if i % 2 == 0 else Globals.RED
		_streak(patch + dir * 780.0, patch - dir * over, col, 0.26, -16.0)
		create_tween().tween_callback(_count.bind(i + 1)).set_delay(0.2)
		await _wait(0.09)
	_count(COUNT)
	await _wait(0.7)
	_old.hop(0.5)
	_hint(true)
	await _wait(1.1)
	_clear_caption()

func _shot_seal() -> void:
	_advance = false
	_cam(1.1, Vector2(-40, 36), 4.0)
	if _counter:
		_tween_alpha(_counter, 0.0, 0.5)
	# The fourth pillar rises on the spot the daggers kept missing.
	var x := PATCH.x
	var top := _c.y + 70.0
	var slot_y := top - 44.0 * 0.62
	_pillar = _sprite($Stage/Mid, "pillar", _c + Vector2(x, 420), 0.62)
	_glyph = _sprite($Stage/FX, "glyph_blade", Vector2(_c.x + x, _c.y + 420 - 44.0 * 0.62), 0.0, Globals.CYAN, true)
	_glyph_glow = _sprite(_glyph, GLOW, Vector2.ZERO, 0.8, Color(Globals.CYAN, 0.55), true)
	AudioManager.play_sfx("rise", 0.8, -10.0)
	var rise := create_tween()
	rise.tween_property(_pillar, "position:y", top, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.parallel().tween_property(_glyph, "position:y", slot_y, 0.7 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_property(_glyph, "scale", Vector2(0.4, 0.4), 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rise.tween_callback(func(): AudioManager.play_sfx("pad_2", 1.0, -6.0))
	await _wait(1.1)
	_old.point_at($Stage/FX.to_global(_glyph.position))
	# The seal: a gold ring closes on the glyph.
	var ring := _sprite($Stage/FX, "seal_ring", _glyph.position, 1.6, Color(Globals.GOLD, 0.0))
	var rg := _sprite(ring, GLOW, Vector2.ZERO, 0.9, Color(Globals.GOLD, 0.0), true)
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(0.52, 0.52), 0.45 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	rt.parallel().tween_property(ring, "modulate:a", 1.0, 0.3 * PACE)
	rt.parallel().tween_property(rg, "modulate:a", 0.55, 0.45 * PACE)
	rt.tween_callback(func():
		AudioManager.play_sfx("seal", 1.0, -4.0)
		_flash(0.6)
		_burst(ring.position, Globals.GOLD, 44, 300.0)
		AudioManager.vibrate(50))
	rt.tween_property(ring, "scale", Vector2(0.58, 0.58), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	rt.parallel().tween_property(_glyph, "modulate", Color(Globals.GOLD), 0.4)
	rt.parallel().tween_property(_glyph_glow, "modulate", Color(Globals.GOLD, 0.55), 0.4)
	await _wait(0.5)
	_caption("The Seal of Empty Air.")
	_pip.set_mood("excited")
	await _wait(0.8)
	_hint(true)
	await _wait(1.2)
	_old.unpoint()
	_clear_caption()

func _shot_lantern() -> void:
	_advance = false
	_cam(1.04, Vector2(50, 24), 4.0)
	_caption("Kuro's best was thirty-one. It was a long time ago, and he was not old.")
	_old.set_mood("think")
	# The last lantern brightens. A touch.
	AudioManager.play_sfx("star_ding", 0.8, -14.0)
	_tween_alpha(_lantern(0), 0.92, 1.4 * PACE)
	_tween_alpha(_lantern_glow(0), 0.52, 1.4 * PACE)
	create_tween().tween_property(_lantern_glow(0), "scale", Vector2(0.62, 0.62), 1.4 * PACE).set_ease(Tween.EASE_OUT)
	await _wait(0.5)
	_pip.set_mood("excited")
	await _wait(1.2)
	_pip.hop(0.9)
	_hint(true)
	await _wait(1.5)
	_clear_caption()
