extends Node2D
## Quick Draw effects layer: spark bursts, expanding rings and floating score
## text. Positions are in this node's local space (use to_local for globals).

var _spark_tex: Texture2D = preload("res://graphics/gen/spark.png")
var _ring_tex: Texture2D = preload("res://graphics/gen/ring.png")
var _add_mat: CanvasItemMaterial

func _ready() -> void:
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

## Sparks flung outward from a point (same recipe as the match-3 shards).
func burst(at: Vector2, color: Color, count: int = 8, reach: float = 96.0) -> void:
	for i in count:
		var s := Sprite2D.new()
		s.texture = _spark_tex
		s.material = _add_mat
		s.modulate = color.lightened(0.25)
		s.position = at
		s.rotation = randf() * TAU
		s.scale = Vector2.ONE * randf_range(0.7, 1.4)
		add_child(s)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(reach * 0.4, reach)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(s, "position", at + dir, 0.42).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
		t.tween_property(s, "scale", Vector2.ZERO, 0.42)
		t.chain().tween_callback(s.queue_free)

## A ring that expands and fades.
func ring(at: Vector2, color: Color, size_mult: float = 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = _ring_tex
	s.material = _add_mat
	s.modulate = Color(color, 0.9)
	s.position = at
	s.scale = Vector2.ONE * 0.12
	add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * 0.62 * size_mult, 0.36).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.36).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(s.queue_free)

## Floating text that rises and fades, centred on `at`.
func popup(text: String, at: Vector2, color: Color, font_size: int = 26) -> void:
	var l := Label.new()
	l.theme_type_variation = &"NumberLabel"
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(Globals.BG0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(240, 44)
	l.position = at - Vector2(120, 62)
	l.modulate.a = 0.0
	add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "modulate:a", 1.0, 0.1)
	t.tween_property(l, "position:y", l.position.y - 46, 0.85).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(l.queue_free)
