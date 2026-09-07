extends Node2D
class_name Film
## Base for every in-engine story film: the dojo stage (torii, mist, platform,
## lanterns), typed captions, tap-to-hurry, SKIP, a slow camera, bursts and a
## title card. A film subclasses this, names itself in film_id(), dresses the
## title card in _dress() and lists its shots in _shots().
##
## Play one with Globals.go("film", {"film": id, ...}):
##   return  state to go to when the film ends (default "start")
##   play    a game id to start instead (its tutorial the first time)
##   then    params of another film to play straight after (chains films)
## Finishing (or skipping) sets the Story.film_flag(id) story flag.

const MASCOT := preload("res://UI/mascot.gd")
## Overall pacing. 1.0 is the original cut; higher plays every film slower.
const PACE := 1.3
const CAPTION_CPS := 32.0
const BAR := 72.0

var return_to := "start"
var play_id := ""
var then_params := {}
var _c := Vector2.ZERO          # stage centre
var _advance := false
var _skip_all := false
var _typing := false
var _chars := 0.0
var _caption_full := ""
var _blip_counter := 0
var _orbit: Node2D
var _orbit_on := false
var _orbit_speed := 1.6
var _swirl: Node2D
var _swirl_on := false
var _tex := {}
var _caption_tween: Tween

# ---------------------------------------------------------------- to override

## The film's id: its story flag is Story.film_flag(film_id()).
func film_id() -> String:
	return "film"

## The shots, in order. Each is a Callable that awaits its own timing.
func _shots() -> Array:
	return []

## Dress the title card (texts and glyphs) before the film starts.
func _dress() -> void:
	pass

## Extra props for this film, built after the shared stage exists.
func _build_extra() -> void:
	pass

## Per-frame hook for film-specific motion.
func _tick(_delta: float) -> void:
	pass

# ---------------------------------------------------------------- lifecycle

func init(p: Dictionary) -> void:
	return_to = str(p.get("return", "start"))
	play_id = str(p.get("play", ""))
	var t = p.get("then", {})
	then_params = t if t is Dictionary else {}

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
	_build_extra()
	_dress()
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	for shot in _shots():
		if _skip_all:
			break
		_advance = false
		_hint(false)
		await shot.call()
	_finish()

func _finish() -> void:
	SaveData.set_story_flag(Story.film_flag(film_id()))
	if not then_params.is_empty():
		Globals.go("film", then_params)
	elif not play_id.is_empty():
		Globals.start_game(play_id)
	else:
		Globals.go(return_to)

func _layout_bars() -> void:
	var r := Globals.view_rect()
	%TopBar.size = Vector2(r.size.x, BAR)
	%TopBar.position = r.position
	%BottomBar.size = Vector2(r.size.x, BAR)
	%BottomBar.position = Vector2(r.position.x, r.end.y - BAR)

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
		_orbit.rotation += delta * _orbit_speed
		for s in _orbit.get_children():
			s.rotation -= delta * 5.0
	if _swirl_on:
		_swirl.rotation += delta * 0.9
	_tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_chars = _caption_full.length()
		else:
			_advance = true

# ---------------------------------------------------------------- stage

func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(name if name.begins_with("res://") else "res://graphics/gen/story/%s.png" % name)
	return _tex[name]

func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

## A sprite from graphics/gen/story (or any res:// path), tinted, optionally additive.
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

## The shared dojo: torii and mist far back, the platform and two lanterns in
## the middle, plus an orbit and a swirl node for effects. Everything starts
## invisible; call _show_dojo() (or reveal pieces yourself, as the prologue does).
func _build_stage() -> void:
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

## The dojo as it stands tonight: torii, platform, mist, lantern 0 dimmed and
## lantern 1 out (the prologue's ending state). `dur` 0 snaps it in place.
func _show_dojo(dur: float = 0.8, second_lantern: bool = false) -> void:
	_tween_alpha($Stage/Far/Torii, 1.0, dur)
	_tween_alpha($Stage/Far/Mist, 0.35, dur)
	_tween_alpha($Stage/Mid/Platform, 1.0, dur)
	_tween_alpha($Stage/Mid/Lantern0, 0.75, dur)
	_tween_alpha($Stage/Mid/LanternGlow0, 0.36, dur)
	_tween_alpha($Stage/Mid/Lantern1, 1.0 if second_lantern else 0.0, dur)
	_tween_alpha($Stage/Mid/LanternGlow1, 0.55 if second_lantern else 0.0, dur)

func _lantern(i: int) -> Sprite2D:
	return $Stage/Mid.get_node("Lantern%d" % i)

func _lantern_glow(i: int) -> Sprite2D:
	return $Stage/Mid.get_node("LanternGlow%d" % i)

## Where the guides stand on the platform (Sensei left of centre, Pip beside him).
func _home_sensei() -> Vector2:
	return _c + Vector2(-40, 62)

func _home_pip() -> Vector2:
	return _c + Vector2(130, 92)

## A guide on stage: "sensei" (old Kuro), "young" (Kuro a century ago) or "pip".
func _actor(character: String, pos: Vector2, scale_v: float = 0.72, facing_right: bool = true, mood: String = "neutral") -> Mascot:
	var m: Mascot = MASCOT.new()
	m.character = character
	m.base_scale = scale_v
	$Stage/Actors.add_child(m)
	m.position = pos
	m.set_facing(facing_right)
	m.set_mood(mood)
	return m

## Scale a guide (Pip growing, a spirit shrinking) over `dur` seconds.
func _grow(m: Mascot, from: float, to: float, dur: float) -> Tween:
	var t := create_tween()
	t.tween_method(func(v: float): m.base_scale = v; m.scale = Vector2(v * signf(m.scale.x), v), from, to, dur * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return t

## A caps label in the world (centred on `pos`), for scoreboards and names.
func _label(text: String, pos: Vector2, size: int = 22, color: Color = Globals.TEXT, width: float = 520.0) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"CapsLabel"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(Globals.BG0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.size = Vector2(width, size * 1.6)
	l.position = pos - l.size * 0.5
	$Stage/FX.add_child(l)
	return l

# ---------------------------------------------------------------- captions and timing

func _caption(text: String) -> void:
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_full = text
	%Caption.text = text
	%Caption.visible_characters = 0
	%Caption.modulate.a = 1.0
	_chars = 0.0
	_typing = true

## Show a caption at once (no typing), e.g. words that land one at a time.
func _caption_now(text: String) -> void:
	_typing = false
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_full = text
	%Caption.text = text
	%Caption.visible_characters = -1
	%Caption.modulate.a = 1.0

func _clear_caption() -> void:
	_typing = false
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(%Caption, "modulate:a", 0.0, 0.3)

## Wait, but return early when the player taps or skips.
func _wait(sec: float) -> void:
	var t := 0.0
	sec *= PACE
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

## Zoom the stage around its centre (a slow push-in reads as a camera move);
## `offset` pans it, so Vector2(-900, 0) looks 900 units to the right.
func _cam(k: float, offset: Vector2, dur: float) -> void:
	dur *= PACE
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property($Stage, "scale", Vector2(k, k), dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property($Stage, "position", _c * (1.0 - k) + offset, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _tween_alpha(node: CanvasItem, a: float, dur: float) -> Tween:
	var t := create_tween()
	t.tween_property(node, "modulate:a", a, dur)
	return t

# ---------------------------------------------------------------- title card

## Dress the title card: `glyphs` is a list of [texture name or res:// path, Color],
## up to four; the rest of the row is hidden.
func _set_title(title: String, sub: String, line: String, glyphs: Array = []) -> void:
	%TitleCard.get_node("V/Title").text = title
	%TitleCard.get_node("V/Sub").text = sub
	%TitleCard.get_node("V/Line").text = line
	var row: HBoxContainer = %TitleCard.get_node("V/Glyphs")
	for i in row.get_child_count():
		var g: TextureRect = row.get_child(i)
		g.visible = i < glyphs.size()
		if i < glyphs.size():
			g.texture = _t(str(glyphs[i][0]))
			g.modulate = glyphs[i][1]

## The standard last shot: fade to black, the title card, hold, fade out.
func _shot_title(hold: float = 3.4, sfx: String = "seal") -> void:
	_advance = false
	await _fade(1.0, 0.8)
	%TitleCard.visible = true
	%TitleCard.modulate.a = 0.0
	if not sfx.is_empty():
		AudioManager.play_sfx(sfx, 1.0, -4.0)
	create_tween().tween_property(%TitleCard, "modulate:a", 1.0, 0.9 * PACE)
	await _wait(1.2)
	_hint(true)
	await _wait(hold)
	create_tween().tween_property(%TitleCard, "modulate:a", 0.0, 0.5)
	await _wait(0.5)
