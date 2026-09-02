extends Control
class_name SpeechBubble
## Comic-style speech bubble with typewriter text and a tail toward the speaker.

signal typed_char
signal finished_typing
signal advanced

const SPEED := 46.0   # characters per second
const MAX_WIDTH := 440.0
var max_width := MAX_WIDTH

var anchor := Vector2.ZERO   # global point the tail points at
var accent: Color = Globals.CYAN
var _typing := false
var _chars := 0.0
var _full := ""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Hint.modulate.a = 0.0

func show_line(who: String, text: String, p_accent: Color, anchor_global: Vector2) -> void:
	accent = p_accent
	anchor = anchor_global
	_full = text
	%Name.text = who
	%Name.add_theme_color_override("font_color", accent)
	%Text.text = text
	%Text.visible_characters = 0
	%Hint.modulate.a = 0.0
	var sb: StyleBoxFlat = %Panel.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(accent, 0.65)
	sb.shadow_color = Color(accent, 0.16)
	%Panel.add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = max_width
	size = Vector2(max_width, 0)
	_chars = 0.0
	_typing = true
	visible = true
	modulate.a = 0.0
	pivot_offset = Vector2(size.x * 0.5, size.y)
	scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	queue_redraw()

func hide_bubble() -> void:
	_typing = false
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): visible = false)

func is_typing() -> bool:
	return _typing

func skip() -> void:
	if _typing:
		_typing = false
		%Text.visible_characters = -1
		_finish()

func _finish() -> void:
	finished_typing.emit()
	var t := create_tween().set_loops()
	t.tween_property(%Hint, "modulate:a", 1.0, 0.5)
	t.tween_property(%Hint, "modulate:a", 0.3, 0.5)

func _process(delta: float) -> void:
	if not _typing:
		return
	_chars += SPEED * delta
	var n := mini(int(_chars), _full.length())
	if n > %Text.visible_characters:
		var prev: int = %Text.visible_characters
		%Text.visible_characters = n
		if n / 2 != prev / 2:
			typed_char.emit()
	if n >= _full.length():
		_typing = false
		_finish()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			skip()
		else:
			advanced.emit()

func _draw() -> void:
	if not visible:
		return
	var local := anchor - global_position
	var bottom := size.y - 2.0
	var bx: float = clampf(local.x, 40.0, size.x - 40.0)
	var tip := Vector2(local.x, minf(local.y, bottom + 40.0))
	if tip.y < bottom + 8.0:
		tip.y = bottom + 24.0
	var pts := PackedVector2Array([Vector2(bx - 16, bottom), tip, Vector2(bx + 16, bottom)])
	draw_colored_polygon(pts, Color(Globals.BG1, 0.96))
	draw_line(pts[0], pts[1], Color(accent, 0.65), 1.5, true)
	draw_line(pts[1], pts[2], Color(accent, 0.65), 1.5, true)
