extends Film
## The Yard, chapter opening: every spring a cricket team from Japan climbs to
## the Star Dojo to pray before they play India. They have never won. Kuro does
## not do miracles, so he laid a pitch in the yard and bowls with the void
## itself. Seven shots; plays the first time Star Cricket is opened.

const FIELD_SCRIPT: Script = preload("res://cricket/field.gd")
const TEAM_SIZE := 11
const YARD_X := 1280.0          # the yard's centre sits this far right of the dojo
const YARD_K := 0.92            # camera zoom that frames the whole pitch

var _old: Mascot
var _pip: Mascot
var _team: Array = []           # Node2D per cricketer, origin at the feet
var _walking := {}              # node -> phase while that cricketer walks
var _step_timer := 0.0
var _petals: Array = []
var _petals_on := false
var _field: Node2D
var _yard_lanterns: Array = []
var _book: Sprite2D
var _board: Array = []          # the scorebook's labels
var _clock := 0.0

func film_id() -> String:
	return "cricket"

func _shots() -> Array:
	return [_shot_spring, _shot_climb, _shot_scorebook, _shot_miracle, _shot_yard, _shot_drill, _shot_title]

func _dress() -> void:
	_set_title("STAR CRICKET", "THE YARD  ·  KURO'S DRILL", "Score fifty, and Pip tells them a ninja did it.",
		[["glyph_bat", Globals.CYAN], ["glyph_ball", Globals.GREEN], ["glyph_stumps", Globals.GOLD]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	_show_dojo(0.0)
	# The thousand steps, rising to the platform's left edge.
	var st := _sprite($Stage/Mid, "steps", _c + Vector2(-470, 236), 1.0)
	st.name = "Steps"
	$Stage/Mid.move_child(st, 0)
	# The yard: the real cricket field, laid out far to the right of the dojo.
	_field = FIELD_SCRIPT.new()
	_field.name = "Yard"
	$Stage/Mid.add_child(_field)
	_field.layout(_yard_rect())
	_field.set_batter_visible(false)
	_field.modulate.a = 0.0
	for i in 2:
		var lx: float = -240.0 if i == 0 else 240.0
		var at := Vector2(_field.cx + lx, _field.stumps_y + 4.0)
		var glow := _sprite($Stage/Mid, "res://graphics/gen/glow.png", at, 0.45, Color(Globals.ORANGE, 0.0), true)
		var lan := _sprite($Stage/Mid, "lantern", at, 0.7, Color(1, 1, 1, 0.0))
		_yard_lanterns.append([lan, glow])
	# Petals for spring, off until the first shot.
	for i in 16:
		var p := _sprite($Stage/FX, "res://graphics/gen/dot.png", _petal_spawn(true), randf_range(0.45, 0.8), Color(1.0, 0.62, 0.8, 0.0), true)
		p.set_meta("vy", randf_range(28.0, 52.0))
		p.set_meta("phase", randf() * TAU)
		_petals.append(p)
	# Actors: old Kuro on the platform, Pip beside him, both facing the steps.
	_old = _actor("sensei", _c + Vector2(70, 62), 0.72, false, "neutral")
	_pip = _actor("pip", _c + Vector2(200, 92), 0.62, false, "neutral")
	for i in TEAM_SIZE:
		_team.append(_cricketer(i))

func _yard_rect() -> Rect2:
	return Rect2(_c + Vector2(YARD_X - 380.0, -260.0), Vector2(760.0, 560.0))

## A cricketer: a node at the feet with the sprite above it, so it can bow,
## kneel and bob without leaving the ground. The first one is the captain.
func _cricketer(i: int) -> Node2D:
	var n := Node2D.new()
	n.position = _c + Vector2(-760.0 - i * 80.0, 470.0 + i * 36.0)
	var spr := _sprite(n, "cricketer", Vector2(0, -64), 1.0)
	spr.name = "Sprite"
	if i == 0:
		n.scale = Vector2(1.08, 1.08)
		var bat := _sprite(spr, "cricket_bat", Vector2(34, 20), 0.75)
		bat.rotation = 0.35
	$Stage/Actors.add_child(n)
	$Stage/Actors.move_child(n, 0)
	return n

func _spr(n: Node2D) -> Sprite2D:
	return n.get_node("Sprite")

## Where each cricketer stands on the platform: a back row of six, a front row of five.
func _platform_slot(i: int) -> Vector2:
	if i < 6:
		return _c + Vector2(-300.0 + i * 52.0, 128.0)
	return _c + Vector2(-276.0 + (i - 6) * 56.0, 164.0)

## Where each cricketer stands beside the pitch (two loose files along the yard's left edge).
func _yard_slot(i: int) -> Vector2:
	return Vector2(_field.cx - 590.0 + (i % 2) * 64.0 + (i / 2) * 6.0, _field.crease_y - 300.0 + (i / 2) * 62.0)

func _petal_spawn(anywhere: bool) -> Vector2:
	return _c + Vector2(randf_range(-760.0, 760.0), randf_range(-440.0, 440.0) if anywhere else -440.0)

func _tick(delta: float) -> void:
	_clock += delta
	if _petals_on:
		for p in _petals:
			var vy: float = p.get_meta("vy")
			var ph: float = p.get_meta("phase")
			p.position.y += vy * delta
			p.position.x += sin(_clock * 1.3 + ph) * 22.0 * delta
			p.rotation += delta * 0.8
			if p.position.y > _c.y + 440.0:
				p.position = _petal_spawn(false)
	if not _walking.is_empty():
		for n in _walking.keys():
			if not is_instance_valid(n):
				continue
			var ph: float = _walking[n]
			var spr := _spr(n)
			spr.position.y = -64.0 - absf(sin(_clock * 13.0 + ph)) * 7.0
			spr.rotation = sin(_clock * 13.0 + ph) * 0.06
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.16
			AudioManager.play_sfx("tile_land", randf_range(1.5, 1.9), -20.0)
	if _field != null and _field.ball_in_flight:
		_field.tick(delta)

func _walk(n: Node2D, to: Vector2, dur: float, delay: float = 0.0) -> Tween:
	var t := create_tween()
	t.tween_interval(delay * PACE)
	t.tween_callback(func(): _walking[n] = randf() * TAU; n.scale.x = absf(n.scale.x) * (1.0 if to.x >= n.position.x else -1.0))
	t.tween_property(n, "position", to, dur * PACE)
	t.tween_callback(func():
		_walking.erase(n)
		_spr(n).position.y = -64.0
		_spr(n).rotation = 0.0)
	return t

## Everyone bows (a lean from the feet) and straightens again.
func _bow(hold: float) -> void:
	for i in _team.size():
		var spr := _spr(_team[i])
		var t := create_tween()
		t.tween_property(spr, "rotation", 0.55, 0.4 * PACE).set_delay(i * 0.04 * PACE).set_ease(Tween.EASE_OUT)
		t.tween_interval(hold * PACE)
		t.tween_property(spr, "rotation", 0.0, 0.45 * PACE).set_ease(Tween.EASE_IN_OUT)

## A ripple of little hops down the line.
func _cheer(strength: float = 1.0) -> void:
	for i in _team.size():
		var spr := _spr(_team[i])
		var t := create_tween()
		t.tween_interval(i * 0.05 * PACE)
		t.tween_property(spr, "position:y", -64.0 - 30.0 * strength, 0.16).set_ease(Tween.EASE_OUT)
		t.tween_property(spr, "position:y", -64.0, 0.2).set_ease(Tween.EASE_IN)
		t.tween_property(spr, "position:y", -64.0 - 14.0 * strength, 0.12).set_ease(Tween.EASE_OUT)
		t.tween_property(spr, "position:y", -64.0, 0.16).set_ease(Tween.EASE_IN)

## Snap the whole cast to the yard (used behind a cut to black).
func _place_yard() -> void:
	_petals_on = false
	for p in _petals:
		p.modulate.a = 0.0
	_cam(YARD_K, Vector2(-YARD_X * YARD_K, 16.0), 0.0)
	for i in _team.size():
		var n: Node2D = _team[i]
		n.position = _yard_slot(i)
		n.scale.x = absf(n.scale.x)
		_spr(n).rotation = 0.0
		_spr(n).scale = Vector2.ONE
		_spr(n).position.y = -64.0
	_old.position = Vector2(_field.cx - 44.0, _field.crease_y - 68.0)
	_old.set_facing(true)
	_old.unpoint()
	_pip.position = Vector2(_field.cx + 130.0, _field.crease_y - 12.0)
	_pip.set_facing(false)
	_field.modulate.a = 1.0
	for pair in _yard_lanterns:
		pair[0].modulate.a = 1.0
		pair[1].modulate.a = 0.55

## Kuro swings at the ball that has just reached the crease: a six every time.
func _swing(zone: int) -> void:
	var at: Vector2 = _field.ball.position if _field.ball != null and is_instance_valid(_field.ball) else _field.crease_point()
	_old.set_facing(zone >= 2)
	var t := create_tween()
	t.tween_property(_old, "rotation", -0.9, 0.09).set_ease(Tween.EASE_OUT)
	t.tween_property(_old, "rotation", 0.18, 0.12).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_old, "rotation", 0.0, 0.25).set_ease(Tween.EASE_OUT)
	_old.hop(1.2)
	_field.fx.ring(at, Globals.CYAN, 1.2)
	_field.contact("six", zone)
	AudioManager.play_sfx("bat_hit", 1.0, -2.0)
	AudioManager.play_sfx("six", 1.0, -4.0)
	AudioManager.vibrate(40)
	_flash(0.3)

# ---------------------------------------------------------------- the film

func _shot_spring() -> void:
	_cam(1.06, Vector2(0, 10), 0.0)
	_cam(1.0, Vector2.ZERO, 9.0)
	_petals_on = true
	for p in _petals:
		_tween_alpha(p, 0.75, 2.0)
	await _fade(0.0, 1.2)
	AudioManager.play_sfx("whoosh", 0.6, -14.0)
	_caption("Every spring, when the mist thins, the Star Dojo gets visitors.")
	await _wait(3.0)
	_pip.set_mood("think")
	_pip.set_facing(false)
	_hint(true)
	await _wait(1.8)
	_clear_caption()

func _shot_climb() -> void:
	_advance = false
	_caption("Eleven of them. A cricket team from Japan, up a thousand steps.")
	_cam(1.1, Vector2(90, 40), 8.0)
	var top := _c + Vector2(-350.0, 200.0)
	for i in TEAM_SIZE:
		var n: Node2D = _team[i]
		var t := _walk(n, top, 1.7, i * 0.26)
		t.tween_callback(func(): _walk(n, _platform_slot(i), 0.7))
	await _wait(2.2)
	_pip.set_mood("excited")
	await _wait(3.4)
	_caption("They come to pray to Kuro before they play India.")
	await _wait(0.6)
	_bow(1.3)
	AudioManager.play_sfx("pad_3", 0.9, -8.0)
	_old.set_mood("neutral")
	await _wait(1.2)
	_old.hop(0.4)
	_hint(true)
	await _wait(2.4)
	_clear_caption()

func _shot_scorebook() -> void:
	_advance = false
	_caption("They have never beaten India. Not once. Pip keeps the scorebook.")
	_cam(1.16, Vector2(-40, 60), 7.0)
	_pip.set_mood("neutral")
	_pip.hop(0.8)
	await _wait(0.7)
	_pip.set_facing(false)
	_book = _sprite($Stage/FX, "scorebook", _c + Vector2(310, -70), 0.0)
	create_tween().tween_property(_book, "scale", Vector2(1.15, 1.15), 0.45 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("shuffle", 1.1, -12.0)
	await _wait(0.9)
	var l1 := _label("JAPAN  v  INDIA", _c + Vector2(310, -196), 18, Globals.MUTED)
	var l2 := _label("PLAYED 27   ·   WON 0", _c + Vector2(310, -162), 24, Globals.RED)
	_board = [l1, l2]
	for l in _board:
		l.modulate.a = 0.0
	_tween_alpha(l1, 1.0, 0.4)
	create_tween().tween_property(l2, "modulate:a", 1.0, 0.4).set_delay(0.5 * PACE)
	await _wait(0.7)
	AudioManager.play_sfx("swap_fail", 0.8, -12.0)
	_pip.set_mood("think")
	_old.set_mood("think")
	_hint(true)
	await _wait(3.0)
	_clear_caption()

func _shot_miracle() -> void:
	_advance = false
	_caption("They asked for a miracle.")
	_cam(1.2, Vector2(60, 70), 3.0)
	var cap: Node2D = _team[0]
	var spr := _spr(cap)
	_walk(cap, _c + Vector2(-120.0, 176.0), 0.7)
	await _wait(0.9)
	var kneel := create_tween()
	kneel.tween_property(spr, "scale:y", 0.78, 0.35 * PACE).set_ease(Tween.EASE_OUT)
	await _wait(1.3)
	# Kuro shakes his head.
	for k in 4:
		_old.set_facing(k % 2 == 1)
		await _wait(0.17)
	_old.set_facing(false)
	_caption("Kuro does not do miracles.")
	await _wait(2.0)
	_caption("He does drills.")
	_old.set_mood("happy")
	_old.hop(1.0)
	AudioManager.play_sfx("rise", 1.1, -8.0)
	for i in 2:
		var g := _lantern_glow(i)
		var flare := create_tween()
		flare.tween_property(g, "modulate:a", 0.9, 0.25)
		flare.tween_property(g, "modulate:a", 0.36 if i == 0 else 0.0, 0.9)
		var lt := create_tween()
		lt.tween_property(_lantern(i), "modulate:a", 1.0, 0.25)
		lt.tween_property(_lantern(i), "modulate:a", 0.75 if i == 0 else 0.0, 0.9)
	create_tween().tween_property(spr, "scale:y", 1.0, 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_pip.set_mood("excited")
	await _wait(0.5)
	_cheer(0.6)
	_hint(true)
	await _wait(2.6)
	_clear_caption()

func _shot_yard() -> void:
	_advance = false
	await _fade(1.0, 0.5)
	if _book:
		_book.visible = false
	for l in _board:
		l.visible = false
	_place_yard()
	_field.modulate.a = 0.0
	for pair in _yard_lanterns:
		pair[0].modulate.a = 0.0
		pair[1].modulate.a = 0.0
	_pip.set_mood("happy")
	_old.set_mood("neutral")
	await _fade(0.0, 0.9)
	_caption("So he laid a pitch in the yard, and he bowls with the void itself.")
	_tween_alpha(_field, 1.0, 1.4)
	for pair in _yard_lanterns:
		_tween_alpha(pair[0], 1.0, 1.4)
		_tween_alpha(pair[1], 0.55, 1.8)
	AudioManager.play_sfx("rise", 0.8, -10.0)
	_cam(YARD_K + 0.04, Vector2(-YARD_X * (YARD_K + 0.04), 16.0), 9.0)
	await _wait(2.6)
	_field.set_fielders([0, 2, 4])
	for k in 3:
		AudioManager.play_sfx("target_spawn", 1.0 + k * 0.08, -12.0)
		await _wait(0.12)
	_caption("Three fielders, two gaps, one ball. That is the whole drill.")
	await _wait(1.0)
	_old.point_at(_field.zone_point(3, 0.7))
	_hint(true)
	await _wait(2.6)
	_old.unpoint()
	_clear_caption()

func _shot_drill() -> void:
	_advance = false
	_cam(1.0, Vector2(-YARD_X, 30.0), 9.0)
	_caption_now("Read the field.")
	AudioManager.play_sfx("pad_5", 1.0, -8.0)
	await _wait(1.3)
	_caption_now("Read the field.   Wait for the ball.")
	AudioManager.play_sfx("pad_7", 1.0, -8.0)
	_field.bowl(1.9, 0.0, 0.0)
	AudioManager.play_sfx("bowl", 1.0, -4.0)
	var t0 := Time.get_ticks_msec()
	while _field.ball_in_flight and _field.time_to_arrival() > 0.02 and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	_caption_now("Read the field.   Wait for the ball.   Swing once.")
	AudioManager.play_sfx("pad_9", 1.0, -8.0)
	_swing(3)
	await _wait(0.5)
	_cheer(1.0)
	AudioManager.play_sfx("level_win", 1.0, -10.0)
	_pip.set_mood("excited")
	await _wait(1.6)
	_caption("The daggers, for once, stay out of it. Fifty runs, and the team might finally listen.")
	_old.set_mood("happy")
	await _wait(2.0)
	_hint(true)
	await _wait(2.6)
	_clear_caption()
