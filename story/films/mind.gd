extends Film
## Chapter III, the Trial of the Mind (Shuriken Match): the Star Dojo kept nine
## hundred shurikens on nine hundred hooks, the Quiet scattered them in a single
## night, and Kuro has spent eighty years bringing them back three of a colour
## at a time. Six shots; plays the first time the trial is opened.

const SHURIKEN := "res://graphics/gen/shuriken.png"
const GLOW := "res://graphics/gen/glow.png"
const COLS := 8
const ROWS := 5
const HOOK_DX := 72.0
const HOOK_DY := 42.0
const WALL_Y := -304.0          # the top row, relative to the stage centre
const WALL_SCALE := 0.18        # a shuriken hanging on its hook
const CARRY := Vector2(0, -150) # where the carried three orbit, above Kuro
## Hooks that have their shuriken back tonight (hook index -> gem colour index),
## eighty years in: a few runs of three, most hooks still empty.
const RETURNED := {0: 0, 1: 0, 2: 0, 11: 2, 12: 2, 13: 2, 24: 3, 25: 3, 26: 3, 29: 4, 30: 4, 31: 4, 34: 5, 35: 5, 36: 5}
## The three Kuro brings home in this film (row 2, the middle of the wall).
const KURO_THREE := [19, 20, 21]
const KURO_COLOR := 1           # magenta, the chapter's colour

var _young: Mascot
var _old: Mascot
var _pip: Mascot
var _wall: Node2D               # hooks and hanging shurikens, behind the platform
var _hung := {}                 # hook index -> Sprite2D
var _carry := false             # the orbit follows old Kuro while true
var _board: Array = []          # the 3x3 board's tiles, row-major

func film_id() -> String:
	return "mind"

func _shots() -> Array:
	return [_shot_dojo, _shot_scatter, _shot_years, _shot_pip, _shot_board, _shot_title]

func _dress() -> void:
	_set_title("TRIAL OF THE MIND", "CHAPTER III  ·  SHURIKEN MATCH", "Three of a colour. Nine hundred to go.", [["glyph_mind", Globals.MAGENTA]])

# ---------------------------------------------------------------- stage

func _build_extra() -> void:
	# Eighty years ago: both lanterns lit, the gate a little further back.
	_show_dojo(0.0, true)
	_tween_alpha(_lantern(0), 1.0, 0.0)
	_tween_alpha(_lantern_glow(0), 0.55, 0.0)
	_tween_alpha($Stage/Far/Torii, 0.6, 0.0)
	_build_wall()
	_young = _actor("young", _home_sensei(), 0.72, true, "neutral")
	_old = _actor("sensei", _c + Vector2(-760, 62), 0.72, true, "neutral")
	_old.modulate.a = 0.0
	_pip = _actor("pip", _c + Vector2(760, 92), 0.62, false, "neutral")
	_pip.modulate.a = 0.0

## The wall: a grid of hooks (little nails) above and behind the platform.
func _build_wall() -> void:
	_wall = Node2D.new()
	_wall.name = "Wall"
	$Stage/Far.add_child(_wall)
	for i in COLS * ROWS:
		_sprite(_wall, "res://graphics/gen/dot.png", _hook_pos(i) + Vector2(0, -HOOK_DY * 0.5), 0.75, Color(Globals.MUTED, 0.85))

func _hook_pos(i: int) -> Vector2:
	return _c + Vector2(-(COLS - 1) * 0.5 * HOOK_DX + (i % COLS) * HOOK_DX, WALL_Y + (i / COLS) * HOOK_DY)

func _gem(k: int) -> Color:
	return Globals.GEM_COLORS[k % Globals.GEM_COLORS.size()]

## A shuriken on hook `i`; `pop` scales it in after `delay` seconds.
func _hang(i: int, col: Color, pop: bool = false, delay: float = 0.0) -> Sprite2D:
	var s := _sprite(_wall, SHURIKEN, _hook_pos(i), 0.0 if pop else WALL_SCALE, col)
	_hung[i] = s
	if pop:
		create_tween().tween_property(s, "scale", Vector2(WALL_SCALE, WALL_SCALE), 0.28 * PACE).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return s

## Every shuriken flies off its hook, spinning, out past the edge of the view.
func _scatter() -> void:
	var centre := _c + Vector2(0, WALL_Y + (ROWS - 1) * HOOK_DY * 0.5)
	for i in _hung.keys():
		var s: Sprite2D = _hung[i]
		var dir := (s.position - centre).normalized()
		if dir.length() < 0.5:
			dir = Vector2.UP
		dir = dir.rotated(randf_range(-0.45, 0.45))
		var t := create_tween()
		t.tween_interval(randf_range(0.0, 0.5) * PACE)
		t.tween_property(s, "position", s.position + dir * 1400.0, 1.0 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(s, "rotation", TAU * randf_range(2.0, 4.0), 1.0 * PACE)
		t.tween_callback(s.queue_free)
	_hung.clear()

## Three of a colour, orbiting above old Kuro as he walks.
func _carry_three(col: Color) -> void:
	for k in 3:
		var s := _sprite(_orbit, SHURIKEN, Vector2.from_angle(k * TAU / 3) * 58.0, 0.0, col)
		_sprite(s, GLOW, Vector2.ZERO, 0.55, Color(col, 0.5), true)
		create_tween().tween_property(s, "scale", Vector2(0.22, 0.22), 0.3 * PACE).set_delay(k * 0.1 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_orbit.position = _old.position + CARRY
	_orbit_speed = 1.8
	_orbit_on = true
	_carry = true

## The carried three leave the orbit and settle on three hooks.
func _snap_three(hooks: Array, col: Color) -> void:
	_carry = false
	_orbit_on = false
	var kids := _orbit.get_children()
	for k in mini(kids.size(), hooks.size()):
		var s: Sprite2D = kids[k]
		s.reparent(_wall)
		s.rotation = fmod(s.rotation, TAU)
		_hung[hooks[k]] = s
		var d := k * 0.08 * PACE
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(s, "position", _hook_pos(hooks[k]), 0.5 * PACE).set_delay(d).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(s, "rotation", 0.0, 0.5 * PACE).set_delay(d)
		t.tween_property(s, "scale", Vector2(WALL_SCALE, WALL_SCALE), 0.5 * PACE).set_delay(d)
		if s.get_child_count() > 0:
			t.tween_property(s.get_child(0), "modulate:a", 0.0, 0.5 * PACE).set_delay(d)
	var mid := _hook_pos(hooks[1]) if hooks.size() > 1 else _hook_pos(hooks[0])
	create_tween().tween_callback(func():
		AudioManager.play_sfx("match", 1.0, -6.0)
		_burst(mid, col, 22, 220.0)).set_delay(0.62 * PACE)

func _tick(_delta: float) -> void:
	if _carry and _old != null and is_instance_valid(_old):
		_orbit.position = _old.position + CARRY

## Tonight's dojo: one lantern dim, the second out, the gate close.
func _tonight(dur: float) -> void:
	_tween_alpha(_lantern(0), 0.75, dur)
	_tween_alpha(_lantern_glow(0), 0.36, dur)
	_tween_alpha(_lantern(1), 0.0, dur)
	_tween_alpha(_lantern_glow(1), 0.0, dur)
	_tween_alpha($Stage/Far/Torii, 1.0, dur)

# ---------------------------------------------------------------- the film

func _shot_dojo() -> void:
	_cam(1.06, Vector2(0, 10), 0.0)
	_cam(1.0, Vector2.ZERO, 8.0)
	await _fade(0.0, 1.2)
	_caption("The Star Dojo kept nine hundred shurikens on nine hundred hooks.")
	for i in COLS * ROWS:
		var col := (i % COLS) + (i / COLS)
		var d := i * 0.045 * PACE
		_hang(i, _gem(col), true, d)
		if i % 2 == 0:
			create_tween().tween_callback(func(): AudioManager.play_sfx("tile_land", 1.0 + (i / COLS) * 0.07, -16.0)).set_delay(d)
	await _wait(2.6)
	_young.hop(0.6)
	_hint(true)
	await _wait(1.8)
	_clear_caption()

func _shot_scatter() -> void:
	_advance = false
	_caption("The Quiet scattered them in a single night.")
	_cam(1.08, Vector2(0, 20), 4.0)
	var mist: Sprite2D = $Stage/Far/Mist
	var mt := create_tween()
	mt.set_parallel(true)
	mt.tween_property(mist, "modulate:a", 0.95, 1.1 * PACE)
	mt.tween_property(mist, "scale", Vector2(3.3, 3.3), 1.1 * PACE).set_ease(Tween.EASE_OUT)
	mt.tween_property(mist, "position:y", _c.y + 120, 1.1 * PACE).set_ease(Tween.EASE_OUT)
	var mb := create_tween()
	mb.tween_interval(1.4 * PACE)
	mb.tween_property(mist, "modulate:a", 0.35, 2.4 * PACE)
	mb.parallel().tween_property(mist, "scale", Vector2(2.2, 2.2), 2.4 * PACE)
	mb.parallel().tween_property(mist, "position:y", _c.y + 260, 2.4 * PACE)
	AudioManager.play_sfx("whoosh", 0.75, -4.0)
	await _wait(0.6)
	_scatter()
	_young.set_mood("think")
	_young.hop(1.2)
	for k in 3:
		create_tween().tween_callback(func(): AudioManager.play_sfx("shatter", 0.9 + k * 0.15, -8.0)).set_delay((0.15 + k * 0.3) * PACE)
	AudioManager.vibrate(40)
	await _wait(2.0)
	_hint(true)
	await _wait(1.4)
	_clear_caption()

func _shot_years() -> void:
	_advance = false
	_caption("Eighty years. Three of a colour at a time.")
	_cam(1.1, Vector2(0, 30), 7.0)
	_swirl.position = _c + Vector2(0, -40)
	for i in 28:
		var a := i * TAU / 28.0
		var r := 380.0 + (i % 3) * 60.0
		var dot := _sprite(_swirl, "res://graphics/gen/dot.png", Vector2.from_angle(a) * r, 0.0, Color(0.9, 0.93, 1.0, 0.8), true)
		create_tween().tween_property(dot, "scale", Vector2(1.6, 1.6), 0.5 * PACE).set_delay(i * 0.03 * PACE)
	_swirl_on = true
	AudioManager.play_sfx("whoosh", 0.7, -8.0)
	await _wait(1.0)
	# The years: young Kuro goes, the lanterns fail, a few shurikens are back.
	_tween_alpha(_young, 0.0, 1.0 * PACE)
	_tonight(1.2 * PACE)
	var n := 0
	for i in RETURNED.keys():
		_hang(i, _gem(RETURNED[i]), true, n * 0.06 * PACE)
		if n % 3 == 0:
			create_tween().tween_callback(func(): AudioManager.play_sfx("tile_land", 0.9 + n * 0.02, -18.0)).set_delay(n * 0.06 * PACE)
		n += 1
	await _wait(1.3)
	var st := create_tween()
	for dot in _swirl.get_children():
		st.parallel().tween_property(dot, "modulate:a", 0.0, 0.8)
	if is_instance_valid(_young):
		_young.queue_free()
	# Old Kuro comes home with three of a colour orbiting above him.
	_old.enter(_c + Vector2(-760, 62), _home_sensei(), 0.0)
	_carry_three(_gem(KURO_COLOR))
	await _wait(1.5)
	_swirl_on = false
	_caption("He says the gathering is the point.")
	_snap_three(KURO_THREE, _gem(KURO_COLOR))
	await _wait(0.7)
	_old.hop(0.5)
	_hint(true)
	await _wait(1.8)
	_clear_caption()

func _shot_pip() -> void:
	_advance = false
	_caption("How many has he got back? He will not tell Pip. Pip has asked for years.")
	_cam(1.12, Vector2(0, 40), 6.0)
	_pip.enter(_c + Vector2(760, 92), _c + Vector2(200, 92), 0.0)
	_pip.set_mood("think")
	await _wait(1.3)
	# Kuro turns away and takes a step toward the wall.
	_old.set_facing(false)
	create_tween().tween_property(_old, "position", _c + Vector2(-250, 62), 0.7 * PACE).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await _wait(0.9)
	_pip.hop(0.8)
	await _wait(0.6)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _board_pos(r: int, c: int) -> Vector2:
	return _c + Vector2(-84.0 + c * 84.0, -254.0 + r * 84.0)

func _shot_board() -> void:
	_advance = false
	_caption("Clear three levels and the Seal of the Gathered is yours. Begin.")
	_cam(1.06, Vector2(0, 30), 5.0)
	_tween_alpha(_wall, 0.16, 0.6)
	_old.set_facing(true)
	_pip.set_mood("neutral")
	# A 3x3 board forms in the air: the middle row is three of a colour.
	var colours := [[0, 2, 3], [1, 1, 1], [4, 0, 5]]
	_board.clear()
	for r in 3:
		for c in 3:
			var k := r * 3 + c
			var col := _gem(colours[r][c])
			var s := _sprite($Stage/FX, SHURIKEN, _board_pos(r, c), 0.0, col)
			var g := _sprite(s, GLOW, Vector2.ZERO, 0.6, Color(col, 0.3), true)
			g.name = "Glow"
			_board.append(s)
			var d := k * 0.09 * PACE
			create_tween().tween_property(s, "scale", Vector2(0.36, 0.36), 0.3 * PACE).set_delay(d).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			create_tween().tween_callback(func(): AudioManager.play_sfx("tile_land", 1.0 + k * 0.04, -14.0)).set_delay(d)
	await _wait(1.6)
	# The row lights up together.
	for c in 3:
		var s: Sprite2D = _board[3 + c]
		create_tween().tween_property(s, "scale", Vector2(0.46, 0.46), 0.25 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		create_tween().tween_property(s.get_node("Glow"), "modulate:a", 1.0, 0.25 * PACE)
	AudioManager.play_sfx("match", 1.0, -4.0)
	_pip.set_mood("excited")
	await _wait(0.45)
	AudioManager.play_sfx("combo", 1.0, -4.0)
	_flash(0.3)
	_burst(_board_pos(1, 1), Globals.MAGENTA, 70, 400.0)
	AudioManager.vibrate(40)
	for c in 3:
		var s: Sprite2D = _board[3 + c]
		create_tween().tween_property(s, "scale", Vector2.ZERO, 0.22 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	await _wait(0.4)
	# The top row drops into the gap, as it does on the board.
	for c in 3:
		var s: Sprite2D = _board[c]
		create_tween().tween_property(s, "position:y", _board_pos(1, c).y, 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	AudioManager.play_sfx("tile_land", 0.9, -12.0)
	await _wait(0.5)
	_old.point_at(_board_pos(1, 1))
	_old.set_mood("neutral")
	_hint(true)
	await _wait(2.0)
	_old.unpoint()
	_clear_caption()
