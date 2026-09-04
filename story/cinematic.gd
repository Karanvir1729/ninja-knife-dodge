extends Node2D
## The prologue: an in-engine animated short about Sensei Kuro and the fallen
## star, told in seven shots. Tap to hurry a caption or jump to the next shot;
## SKIP ends it. Plays on first launch and from the Story journal.

const MASCOT := preload("res://UI/mascot.gd")
const CAPTION_CPS := 42.0
const BAR := 72.0

var return_to := "start"
var _c := Vector2.ZERO          # stage centre
var _advance := false
var _skip_all := false
var _typing := false
var _chars := 0.0
var _caption_full := ""
var _blip_counter := 0
var _orbit: Node2D
var _orbit_on := false
var _swirl: Node2D
var _swirl_on := false
var _young: Mascot
var _old: Mascot
var _pip: Mascot
var _tex := {}

func init(p: Dictionary) -> void:
	return_to = str(p.get("return", "start"))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("story")
	_c = Globals.view_center()
	%Skip.pressed.connect(func(): AudioManager.back(); _skip_all = true; _advance = true)
	%TapHint.modulate.a = 0.0
	%TitleCard.visible = false
	%Fade.color = Color(Globals.BG0, 1.0)
	_layout_bars()
	get_viewport().size_changed.connect(_layout_bars)
	_build_stage()
	call_deferred("_run")

func _layout_bars() -> void:
	var r := Globals.view_rect()
	%TopBar.size = Vector2(r.size.x, BAR)
	%TopBar.position = r.position
	%BottomBar.size = Vector2(r.size.x, BAR)
	%BottomBar.position = Vector2(r.position.x, r.end.y - BAR)

func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(name if name.begins_with("res://") else "res://graphics/gen/story/%s.png" % name)
	return _tex[name]

func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _sprite(parent: Node, tex: String, pos: Vector2, scale_v: float = 1.0, mod: Color = Color.WHITE, additive: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _t(tex)
	s.position = pos
	s.scale = Vector2(scale_v, scale_v)
	s.modulate = mod
	if additive:
		s.material = _add_material()
	parent.add_child(s)
	return s

func _build_stage() -> void:
	# Far: torii and mist. Mid: platform and lanterns. Actors and FX on top.
	var torii := _sprite($Stage/Far, "torii", _c + Vector2(-10, -80), 0.85, Color(1, 1, 1, 0.0))
	torii.name = "Torii"
	var mist := _sprite($Stage/Far, "mist", _c + Vector2(0, 260), 2.2, Color(Globals.VIOLET, 0.0), true)
	mist.name = "Mist"
	var platform := _sprite($Stage/Mid, "platform", _c + Vector2(0, 190), 1.0, Color(1, 1, 1, 0.0))
	platform.name = "Platform"
	for i in 2:
		var lx: float = -196.0 if i == 0 else 176.0
		var glow := _sprite($Stage/Mid, "res://graphics/gen/glow.png", _c + Vector2(lx, 30), 0.5, Color(Globals.ORANGE, 0.0), true)
		glow.name = "LanternGlow%d" % i
		var lan := _sprite($Stage/Mid, "lantern", _c + Vector2(lx, 30), 0.8, Color(1, 1, 1, 0.0))
		lan.name = "Lantern%d" % i
	_orbit = Node2D.new()
	_orbit.name = "Orbit"
	$Stage/FX.add_child(_orbit)
	_swirl = Node2D.new()
	_swirl.name = "Swirl"
	$Stage/FX.add_child(_swirl)

func _process(delta: float) -> void:
	if _typing:
		_chars += CAPTION_CPS * delta
		var n := mini(int(_chars), _caption_full.length())
		if n > %Caption.visible_characters:
			%Caption.visible_characters = n
			_blip_counter += 1
			if _blip_counter % 3 == 0:
				AudioManager.play_sfx("narrator_blip", randf_range(0.9, 1.1), -16.0)
		if n >= _caption_full.length():
			_typing = false
	if _orbit_on:
		_orbit.rotation += delta * 1.6
		for s in _orbit.get_children():
			s.rotation -= delta * 5.0
	if _swirl_on:
		_swirl.rotation += delta * 0.9

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_chars = _caption_full.length()
		else:
			_advance = true

# ---------------------------------------------------------------- helpers

func _caption(text: String) -> void:
	_caption_full = text
	%Caption.text = text
	%Caption.visible_characters = 0
	%Caption.modulate.a = 1.0
	_chars = 0.0
	_typing = true

func _clear_caption() -> void:
	_typing = false
	create_tween().tween_property(%Caption, "modulate:a", 0.0, 0.3)

## Wait, but return early when the player taps or skips.
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _advance:
		await get_tree().process_frame
		t += get_process_delta_time()

func _hint(on: bool) -> void:
	create_tween().tween_property(%TapHint, "modulate:a", 0.8 if on else 0.0, 0.3)

func _fade(to_alpha: float, dur: float = 0.6) -> void:
	var t := create_tween()
	t.tween_property(%Fade, "color:a", to_alpha, dur)
	await t.finished

func _flash(strength: float = 0.7) -> void:
	%Flash.color = Color(1, 1, 1, strength)
	create_tween().tween_property(%Flash, "color:a", 0.0, 0.45)

func _burst(at: Vector2, color: Color, amount: int = 40, speed: float = 320.0) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = amount
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.texture = _t("res://graphics/gen/spark.png")
	p.material = _add_material()
	p.spread = 180.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.color = color
	$Stage/FX.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _tween_alpha(node: CanvasItem, a: float, dur: float) -> Tween:
	var t := create_tween()
	t.tween_property(node, "modulate:a", a, dur)
	return t

# ---------------------------------------------------------------- the film

func _run() -> void:
	await get_tree().process_frame
	var shots := [_shot_void, _shot_training, _shot_starfall, _shot_daggers, _shot_years, _shot_trials, _shot_title]
	for shot in shots:
		if _skip_all:
			break
		_advance = false
		_hint(false)
		await shot.call()
	_finish()

func _finish() -> void:
	SaveData.set_story_flag("prologue_seen")
	Globals.go(return_to)

func _shot_void() -> void:
	await _fade(0.0, 1.2)
	var mist: Sprite2D = $Stage/Far/Mist
	_tween_alpha(mist, 0.35, 2.0)
	create_tween().tween_property(mist, "position:x", mist.position.x + 60, 6.0)
	_caption("Before the first ninja, there was only the void.")
	await _wait(3.6)
	_tween_alpha($Stage/Far/Torii, 0.55, 1.6)
	await _wait(1.6)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_training() -> void:
	_advance = false
	var platform: Sprite2D = $Stage/Mid/Platform
	platform.position.y += 40
	_tween_alpha(platform, 1.0, 0.8)
	create_tween().tween_property(platform, "position:y", platform.position.y - 40, 0.9).set_ease(Tween.EASE_OUT)
	for i in 2:
		_tween_alpha($Stage/Mid.get_node("Lantern%d" % i), 1.0, 0.8)
		_tween_alpha($Stage/Mid.get_node("LanternGlow%d" % i), 0.55, 1.2)
	_tween_alpha($Stage/Far/Torii, 1.0, 0.8)
	_young = MASCOT.new()
	_young.character = "young"
	_young.base_scale = 0.72
	$Stage/Actors.add_child(_young)
	var home := _c + Vector2(-40, 62)
	_young.enter(home + Vector2(-520, 0), home, 0.2)
	_caption("In the Star Dojo, Kuro trained for a hundred years.")
	await _wait(1.4)
	_orbit.position = home + Vector2(0, -40)
	var cols := [Globals.CYAN, Globals.MAGENTA, Globals.GOLD, Globals.GREEN]
	for i in 4:
		var s := _sprite(_orbit, "res://graphics/gen/shuriken.png", Vector2.from_angle(i * TAU / 4) * 130.0, 0.0, cols[i])
		create_tween().tween_property(s, "scale", Vector2(0.3, 0.3), 0.3).set_delay(i * 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_sprite(s, "res://graphics/gen/glow.png", Vector2.ZERO, 0.5, Color(cols[i], 0.5), true)
	AudioManager.play_sfx("whoosh", 1.1, -6.0)
	_orbit_on = true
	_young.hop(1.2)
	await _wait(2.4)
	var glyphs := ["blade", "eye", "mind", "memory"]
	var words := ["Blade.", "Eye.", "Mind.", "Memory."]
	_caption("")
	%Caption.modulate.a = 1.0
	for i in 4:
		var g := _sprite($Stage/FX, "glyph_" + glyphs[i], _c + Vector2(-270 + i * 180, -250), 0.0, Globals.CYAN, true)
		g.name = "TrainGlyph%d" % i
		_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.9, Color(Globals.CYAN, 0.5), true)
		create_tween().tween_property(g, "scale", Vector2(0.55, 0.55), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		AudioManager.play_sfx("pad_%d" % [i * 2 + 1], 1.0, -6.0)
		%Caption.text = " ".join(words.slice(0, i + 1))
		%Caption.visible_characters = -1
		_young.hop(0.6)
		await _wait(0.55)
	_hint(true)
	await _wait(2.0)
	for i in 4:
		var g: Sprite2D = $Stage/FX.get_node("TrainGlyph%d" % i)
		create_tween().tween_property(g, "modulate:a", 0.0, 0.4).set_delay(i * 0.05)
	var ot := create_tween()
	for s in _orbit.get_children():
		ot.parallel().tween_property(s, "scale", Vector2.ZERO, 0.3)
	_clear_caption()

func _shot_starfall() -> void:
	_advance = false
	_orbit_on = false
	_young.set_facing(true)
	_young.set_mood("think")
	_caption("Then a star fell from the dark.")
	AudioManager.play_sfx("star_fall", 1.0, -4.0)
	var star := _sprite($Stage/FX, "res://graphics/gen/player_star.png", _c + Vector2(760, -520), 0.5, Globals.GOLD)
	_sprite(star, "res://graphics/gen/glow.png", Vector2.ZERO, 0.9, Color(Globals.GOLD, 0.7), true)
	var trail := CPUParticles2D.new()
	trail.amount = 50
	trail.lifetime = 0.7
	trail.texture = _t("res://graphics/gen/spark.png")
	trail.material = _add_material()
	trail.direction = Vector2(1, -1)
	trail.spread = 20.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 60.0
	trail.initial_velocity_max = 140.0
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	trail.color = Color(Globals.GOLD, 0.9)
	star.add_child(trail)
	var land := _c + Vector2(170, 70)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(star, "position:x", land.x, 1.5)
	t.tween_property(star, "position:y", land.y, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(star, "rotation", TAU * 1.5, 1.5)
	await _wait(1.5)
	star.visible = false
	_flash(0.75)
	_burst(land, Globals.GOLD, 70, 420.0)
	AudioManager.play_sfx("impact")
	AudioManager.vibrate(60)
	_young.hop(1.4)
	await _wait(0.5)
	_pip = MASCOT.new()
	_pip.character = "pip"
	_pip.base_scale = 0.0
	$Stage/Actors.add_child(_pip)
	_pip.position = land + Vector2(0, -20)
	_pip.set_mood("neutral")
	var pt := create_tween()
	pt.tween_method(func(v: float): _pip.base_scale = v; _pip.scale = Vector2(v, v), 0.0, 0.62, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await _wait(0.8)
	_young.set_facing(true)
	_hint(true)
	await _wait(2.2)
	_clear_caption()

func _shot_daggers() -> void:
	_advance = false
	_caption("The daggers of light came hunting. Kuro stood between.")
	var pip_pos: Vector2 = _pip.position
	var between := pip_pos + Vector2(-120, -10)
	var kt := create_tween()
	kt.tween_property(_young, "position", between, 0.35).set_ease(Tween.EASE_OUT)
	_young.hop(1.6)
	_young.set_mood("excited")
	var daggers: Array = []
	for i in 6:
		var d := Node2D.new()
		d.position = _c + Vector2(-380 + i * 150 + randf_range(-30, 30), 520 + i * 30)
		d.rotation = -PI / 2
		var sw := Sprite2D.new()
		sw.texture = load("res://graphics/skeleton_sword.png")
		sw.position = Vector2(40, 0)
		sw.rotation = 0.785398
		sw.scale = Vector2(1.6, 1.6)
		d.add_child(sw)
		var col: Color = Globals.RED if i % 2 == 0 else Globals.CYAN
		sw.modulate = Color(1, 1, 1, 1).lerp(col, 0.3)
		_sprite(d, "res://graphics/gen/tip_glow.png", Vector2(60, 0), 3.0, Color(col, 0.9), true)
		$Stage/FX.add_child(d)
		daggers.append(d)
	AudioManager.play_sfx("rise", 1.0, -8.0)
	for i in daggers.size():
		var d: Node2D = daggers[i]
		var target := between + Vector2(randf_range(-40, 40), randf_range(-60, 40))
		d.look_at(target)
		var dt := create_tween()
		dt.tween_property(d, "position", target, 0.9).set_delay(i * 0.22).set_ease(Tween.EASE_IN)
		dt.tween_callback(func():
			_burst(d.position, Globals.RED if i % 2 == 0 else Globals.CYAN, 26, 260.0)
			AudioManager.play_sfx("shatter", randf_range(0.9, 1.2), -8.0)
			d.queue_free()
			_young.hop(0.9))
	# Kuro spins as the daggers arrive
	var spin := create_tween()
	spin.tween_interval(0.8)
	spin.tween_property(_young, "rotation", TAU, 0.7).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(_young, "rotation", 0.0, 0.0)
	spin.tween_interval(0.5)
	spin.tween_property(_young, "rotation", -TAU, 0.7).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(_young, "rotation", 0.0, 0.0)
	await _wait(3.2)
	_pip.set_mood("happy")
	_young.set_mood("happy")
	_hint(true)
	await _wait(2.0)
	_clear_caption()

func _shot_years() -> void:
	_advance = false
	_caption("Years passed. The master grew old, and the star grew bright. But the daggers never stopped.")
	_swirl.position = _c + Vector2(0, -40)
	for i in 28:
		var a := i * TAU / 28.0
		var r := 380.0 + (i % 3) * 60.0
		var dot := _sprite(_swirl, "res://graphics/gen/dot.png", Vector2.from_angle(a) * r, 0.0, Color(0.9, 0.93, 1.0, 0.8), true)
		create_tween().tween_property(dot, "scale", Vector2(1.6, 1.6), 0.5).set_delay(i * 0.03)
	_swirl_on = true
	AudioManager.play_sfx("whoosh", 0.7, -8.0)
	await _wait(1.6)
	_old = MASCOT.new()
	_old.character = "sensei"
	_old.base_scale = 0.72
	$Stage/Actors.add_child(_old)
	_old.position = _young.position
	_old.set_facing(_young.scale.x > 0)
	_old.modulate.a = 0.0
	_old.set_mood("happy")
	var xf := create_tween()
	xf.set_parallel(true)
	xf.tween_property(_old, "modulate:a", 1.0, 1.4)
	xf.tween_property(_young, "modulate:a", 0.0, 1.4)
	var grow := create_tween()
	grow.tween_method(func(v: float): _pip.base_scale = v; _pip.scale = Vector2(v, v), 0.62, 0.74, 1.4)
	_pip.set_mood("excited")
	await _wait(1.8)
	var st := create_tween()
	for dot in _swirl.get_children():
		st.parallel().tween_property(dot, "modulate:a", 0.0, 0.8)
	_hint(true)
	await _wait(2.6)
	_swirl_on = false
	if is_instance_valid(_young):
		_young.queue_free()
	_clear_caption()

func _shot_trials() -> void:
	_advance = false
	_caption("Four trials remain. Master them, and the star will shine unbroken.")
	var glyphs := ["blade", "eye", "mind", "memory"]
	var accents := [Globals.CYAN, Globals.ORANGE, Globals.MAGENTA, Globals.VIOLET]
	var om := create_tween()
	om.tween_property(_old, "position", _c + Vector2(-300, 62), 0.6).set_ease(Tween.EASE_OUT)
	var pm := create_tween()
	pm.tween_property(_pip, "position", _c + Vector2(-170, 90), 0.6).set_ease(Tween.EASE_OUT)
	for i in 4:
		var x: float = -60.0 + i * 130.0
		var pillar := _sprite($Stage/Mid, "pillar", _c + Vector2(x, 420), 0.62, Color(1, 1, 1, 1))
		pillar.name = "Pillar%d" % i
		var slot := pillar.position + Vector2(0, -44 * 0.62 - 0)
		var g := _sprite($Stage/FX, "glyph_" + glyphs[i], slot, 0.0, accents[i], true)
		g.name = "TrialGlyph%d" % i
		_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.8, Color(accents[i], 0.55), true)
		var rise := create_tween()
		rise.tween_property(pillar, "position:y", _c.y + 70, 0.7).set_delay(i * 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.parallel().tween_property(g, "position:y", _c.y + 70 - 44 * 0.62, 0.7).set_delay(i * 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.tween_property(g, "scale", Vector2(0.4, 0.4), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.tween_callback(func(): AudioManager.play_sfx("pad_%d" % [i * 2 + 2], 1.0, -6.0))
	AudioManager.play_sfx("rise", 0.8, -10.0)
	await _wait(1.2)
	_old.point_at(_c + Vector2(130, 60))
	await _wait(2.4)
	_hint(true)
	await _wait(2.4)
	_old.unpoint()
	_clear_caption()

func _shot_title() -> void:
	_advance = false
	await _fade(1.0, 0.8)
	%TitleCard.visible = true
	%TitleCard.modulate.a = 0.0
	AudioManager.play_sfx("seal", 1.0, -4.0)
	create_tween().tween_property(%TitleCard, "modulate:a", 1.0, 0.9)
	await _wait(1.2)
	_hint(true)
	await _wait(3.4)
	create_tween().tween_property(%TitleCard, "modulate:a", 0.0, 0.5)
	await _wait(0.5)
