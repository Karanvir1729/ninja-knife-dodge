extends Button
class_name NeonToggle
## Pill toggle drawn in code so it matches the neon theme on every platform.

var accent: Color = Globals.CYAN
var _knob := 0.0

func _ready() -> void:
	toggle_mode = true
	text = ""
	custom_minimum_size = Vector2(78, 42)
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_knob = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)

func set_on_silent(on: bool) -> void:
	set_pressed_no_signal(on)
	_knob = 1.0 if on else 0.0
	queue_redraw()

func _on_toggled(on: bool) -> void:
	AudioManager.click()
	var t := create_tween()
	t.tween_method(func(v: float): _knob = v; queue_redraw(), _knob, 1.0 if on else 0.0, 0.18).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var h := size.y
	var pill := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Globals.LINE.lerp(accent, _knob)
	sb.set_corner_radius_all(int(h / 2))
	if _knob < 0.5:
		sb.set_border_width_all(1)
		sb.border_color = Globals.LINE2
	else:
		sb.shadow_color = Color(accent, 0.35 * _knob)
		sb.shadow_size = 12
	sb.draw(get_canvas_item(), pill)
	var kr := h / 2 - 4
	var kx: float = lerpf(4 + kr, size.x - 4 - kr, _knob)
	draw_circle(Vector2(kx, h / 2), kr, Globals.MUTED.lerp(Globals.BG0, _knob))
