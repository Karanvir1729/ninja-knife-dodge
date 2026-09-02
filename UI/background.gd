extends Node2D
## Persistent void backdrop: drifting stars, two soft colour glows and a few
## faint daggers. Fills whatever the (expanding) viewport is, so it looks right
## on 16:9, iPhone 19.5:9 and iPad 4:3 alike. Moods tint it per screen.

const STAR_COUNT := 110
const DAGGER_COUNT := 5

var _stars: Array = []
var _daggers: Array = []
var _time := 0.0
var _mood := "menu"
var _glow_a: Sprite2D
var _glow_b: Sprite2D
var _dagger_tex: Texture2D
var _dot_tex: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dagger_tex = load("res://graphics/skeleton_sword.png")
	_dot_tex = load("res://graphics/gen/dot.png")
	var glow_tex: Texture2D = load("res://graphics/gen/glow.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_a = Sprite2D.new(); _glow_a.texture = glow_tex; _glow_a.material = mat; _glow_a.scale = Vector2(4.2, 4.2)
	_glow_b = Sprite2D.new(); _glow_b.texture = glow_tex; _glow_b.material = mat; _glow_b.scale = Vector2(4.6, 4.6)
	add_child(_glow_a)
	add_child(_glow_b)
	seed(1337)
	for i in STAR_COUNT:
		_stars.append({
			"p": Vector2(randf(), randf()), "r": randf_range(0.7, 2.2),
			"a": randf_range(0.25, 0.9), "ph": randf() * TAU, "sp": randf_range(0.004, 0.014),
		})
	for i in DAGGER_COUNT:
		_daggers.append({
			"p": Vector2(randf(), randf()), "rot": randf() * TAU, "spin": randf_range(-0.12, 0.12),
			"sp": Vector2(randf_range(-0.01, 0.01), randf_range(0.006, 0.02)), "s": randf_range(1.0, 1.8),
			"c": [Globals.CYAN, Globals.MAGENTA, Globals.GOLD][i % 3],
		})
	set_mood("menu")
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var r := Globals.view_rect()
	_glow_a.position = r.position + Vector2(r.size.x * 0.1, r.size.y * 0.15)
	_glow_b.position = r.position + Vector2(r.size.x * 0.9, r.size.y * 0.88)
	queue_redraw()

func set_mood(mood: String) -> void:
	_mood = mood
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	match mood:
		"menu":
			t.tween_property(_glow_a, "modulate", Color(Globals.CYAN, 0.16), 0.6)
			t.tween_property(_glow_b, "modulate", Color(Globals.MAGENTA, 0.14), 0.6)
		"knife":
			t.tween_property(_glow_a, "modulate", Color(Globals.CYAN, 0.05), 0.6)
			t.tween_property(_glow_b, "modulate", Color(Globals.RED, 0.05), 0.6)
		"match":
			t.tween_property(_glow_a, "modulate", Color(Globals.VIOLET, 0.12), 0.6)
			t.tween_property(_glow_b, "modulate", Color(Globals.MAGENTA, 0.16), 0.6)
		_:
			t.tween_property(_glow_a, "modulate", Color(Globals.CYAN, 0.1), 0.6)
			t.tween_property(_glow_b, "modulate", Color(Globals.MAGENTA, 0.1), 0.6)

func _process(delta: float) -> void:
	_time += delta
	for s in _stars:
		s.p.y += s.sp * delta
		s.p.x -= s.sp * 0.3 * delta
		if s.p.y > 1.0: s.p.y -= 1.0
		if s.p.x < 0.0: s.p.x += 1.0
	for d in _daggers:
		d.p += d.sp * delta
		d.rot += d.spin * delta
		if d.p.y > 1.1: d.p.y = -0.1; d.p.x = randf()
		if d.p.x < -0.1: d.p.x = 1.1
		if d.p.x > 1.1: d.p.x = -0.1
	queue_redraw()

func _draw() -> void:
	var r := Globals.view_rect()
	draw_rect(r, Globals.BG0)
	var dagger_alpha := 0.22 if _mood == "menu" else 0.08
	for d in _daggers:
		var pos: Vector2 = r.position + d.p * r.size
		draw_set_transform(pos, d.rot, Vector2(d.s, d.s))
		draw_texture(_dagger_tex, -_dagger_tex.get_size() * 0.5, Color(d.c, dagger_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var star_alpha := 1.0 if _mood != "knife" else 0.5
	for s in _stars:
		var tw: float = 0.6 + 0.4 * sin(_time * 1.3 + s.ph)
		var pos: Vector2 = r.position + s.p * r.size
		var col := Color(0.87, 0.9, 1.0, s.a * tw * star_alpha)
		var sz: float = s.r * 2.6
		draw_texture_rect(_dot_tex, Rect2(pos - Vector2(sz, sz), Vector2(sz * 2, sz * 2)), false, col)
