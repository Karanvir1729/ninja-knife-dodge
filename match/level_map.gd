extends Control
class_name LevelMap
## Winding Shuriken Match level path. Level nodes sit along a sine wave joined
## by a glowing magenta trail: cleared levels show their stars, the next level
## is bigger and pulses with a PLAY caption, locked levels are dim. Lives inside
## a horizontal ScrollContainer; the owning state decides what a tap does.

signal level_pressed(level: int)
signal skip_pressed(level: int)

const STEP := 150.0
const AMP := 120.0
const NODE := 96.0
const NODE_NEXT := 120.0
const SUBDIV := 12        # curve samples per segment (keeps the polyline smooth)

var next_level := 1

var _buttons := {}        # level -> Button
var _glow: TextureRect
var _skip: Button
var _pulse: Tween
var _drag_x := -1.0
var _drag_scroll := 0
var _star_tex: Texture2D
var _lock_tex: Texture2D
var _glow_tex: Texture2D
var _skip_tex: Texture2D

func _ready() -> void:
	_star_tex = load("res://graphics/gen/icon_star.png")
	_lock_tex = load("res://graphics/gen/icon_lock.png")
	_glow_tex = load("res://graphics/gen/glow.png")
	_skip_tex = load("res://graphics/gen/icon_skip.png")
	custom_minimum_size.x = MatchLevels.LEVEL_COUNT * STEP + 300.0
	resized.connect(_place_all)

## Centre of level `level` (1-based) in map coordinates.
func level_pos(level: int) -> Vector2:
	return _curve(float(level - 1))

func _curve(t: float) -> Vector2:
	return Vector2(150.0 + t * STEP, size.y * 0.5 + AMP * sin(t * 0.9))

## (Re)build every node. `show_skip` adds the SKIP pill under the next level.
func build(p_next: int, show_skip: bool) -> void:
	next_level = clampi(p_next, 1, MatchLevels.LEVEL_COUNT)
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buttons.clear()
	_skip = null
	_glow = TextureRect.new()
	_glow.texture = _glow_tex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glow.modulate = Color(Globals.MAGENTA, 0.5)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	for lv in range(1, MatchLevels.LEVEL_COUNT + 1):
		var b := _make_node(lv)
		add_child(b)
		_buttons[lv] = b
	if show_skip:
		_skip = _make_skip()
		add_child(_skip)
	_place_all()
	_start_pulse()

func _place_all() -> void:
	for lv in _buttons.keys():
		var b: Button = _buttons[lv]
		var sz := NODE_NEXT if lv == next_level else NODE
		b.size = Vector2(sz, sz)
		b.position = level_pos(lv) - Vector2(sz, sz) * 0.5
	if _glow:
		var gs := 300.0
		_glow.size = Vector2(gs, gs)
		_glow.pivot_offset = Vector2(gs, gs) * 0.5
		_glow.position = level_pos(next_level) - Vector2(gs, gs) * 0.5
	if _skip:
		_skip.size = Vector2(118, 36)
		_skip.position = level_pos(next_level) + Vector2(-_skip.size.x * 0.5, NODE_NEXT * 0.5 + 12.0)
	queue_redraw()

func _draw() -> void:
	var n := MatchLevels.LEVEL_COUNT
	var lit := float(next_level - 1)   # the trail is lit up to the next level's node
	var bright := PackedVector2Array()
	var dim := PackedVector2Array()
	for i in range((n - 1) * SUBDIV + 1):
		var t := i / float(SUBDIV)
		var p := _curve(t)
		if t <= lit:
			bright.append(p)
		if t >= lit:
			dim.append(p)
	if dim.size() >= 2:
		draw_polyline(dim, Color(Globals.MAGENTA, 0.08), 18.0, true)
		draw_polyline(dim, Color(Globals.LINE2, 1.0), 3.0, true)
	if bright.size() >= 2:
		draw_polyline(bright, Color(Globals.MAGENTA, 0.16), 30.0, true)
		draw_polyline(bright, Color(Globals.MAGENTA, 0.45), 12.0, true)
		draw_polyline(bright, Color(1.0, 0.82, 0.96, 1.0), 3.5, true)
	# Beads between the nodes, like the footsteps on a classic map.
	for i in range(n - 1):
		var on := i < next_level - 1
		for k in [0.35, 0.65]:
			var p := _curve(i + k)
			draw_circle(p, 5.0 if on else 4.0, Color(Globals.MAGENTA, 0.95) if on else Color(Globals.LINE2, 0.9))

func _make_node(lv: int) -> Button:
	var info := SaveData.match_level_info(lv)
	var stars := int(info.stars)
	var unlocked := lv <= next_level
	var is_next := lv == next_level
	var sz := NODE_NEXT if is_next else NODE
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Globals.BG2, 1.0) if unlocked else Color(Globals.BG1, 0.75)
	sb.set_border_width_all(2 if is_next else 1)
	if is_next:
		sb.border_color = Globals.MAGENTA
		sb.shadow_color = Color(Globals.MAGENTA, 0.35)
		sb.shadow_size = 18
	elif stars == 3:
		sb.border_color = Color(Globals.GOLD, 0.55)
	else:
		sb.border_color = Globals.LINE2 if unlocked else Globals.LINE
	sb.set_corner_radius_all(int(sz * 0.5))
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(Globals.MAGENTA, 0.18)
	sbp.border_color = Globals.MAGENTA
	for s in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover_pressed", sbp)
	b.disabled = not unlocked
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0 if is_next else 4)
	b.add_child(v)
	if unlocked:
		var n := Label.new()
		n.theme_type_variation = &"DisplayLabel"
		n.add_theme_font_size_override("font_size", 42 if is_next else 32)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.text = str(lv)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_next:
			n.add_theme_color_override("font_color", Globals.MAGENTA)
			n.add_theme_color_override("font_outline_color", Color(Globals.MAGENTA, 0.35))
			n.add_theme_constant_override("outline_size", 6)
		v.add_child(n)
		if is_next:
			var cap := Label.new()
			cap.theme_type_variation = &"CapsLabel"
			cap.add_theme_font_size_override("font_size", 15)
			cap.add_theme_color_override("font_color", Globals.MAGENTA)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.text = "PLAY"
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(cap)
		else:
			var h := HBoxContainer.new()
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			h.add_theme_constant_override("separation", 2)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for i in 3:
				var st := TextureRect.new()
				st.texture = _star_tex
				st.custom_minimum_size = Vector2(16, 16)
				st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				st.modulate = Globals.GOLD if i < stars else Globals.LINE2
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				h.add_child(st)
			v.add_child(h)
		b.pressed.connect(func(): level_pressed.emit(lv))
	else:
		var lk := TextureRect.new()
		lk.texture = _lock_tex
		lk.custom_minimum_size = Vector2(26, 26)
		lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lk.modulate = Globals.DIM
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lk)
		var n := Label.new()
		n.theme_type_variation = &"CapsLabel"
		n.add_theme_font_size_override("font_size", 15)
		n.add_theme_color_override("font_color", Globals.DIM)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.text = str(lv)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
	return b

func _make_skip() -> Button:
	var b := Button.new()
	b.text = "SKIP"
	b.icon = _skip_tex
	b.expand_icon = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 6)
	for c in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(c, Globals.GOLD)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color"]:
		b.add_theme_color_override(c, Globals.BG0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Globals.GOLD, 0.12)
	sb.set_border_width_all(1)
	sb.border_color = Color(Globals.GOLD, 0.6)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Globals.GOLD
	for s in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover_pressed", sbp)
	b.pressed.connect(func(): skip_pressed.emit(next_level))
	return b

func _start_pulse() -> void:
	if _glow == null:
		return
	_glow.scale = Vector2(0.9, 0.9)
	_glow.modulate.a = 0.35
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "modulate:a", 0.85, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_glow, "scale", Vector2(1.12, 1.12), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_glow, "modulate:a", 0.35, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_glow, "scale", Vector2(0.9, 0.9), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Desktop convenience: drag the empty map with the mouse. On devices the
## ScrollContainer already follows touch drags (they pass through the buttons).
func _gui_input(event: InputEvent) -> void:
	if OS.has_feature("mobile"):
		return
	var sc := get_parent() as ScrollContainer
	if sc == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_x = event.global_position.x
			_drag_scroll = sc.scroll_horizontal
		else:
			_drag_x = -1.0
	elif event is InputEventMouseMotion and _drag_x >= 0.0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		sc.scroll_horizontal = _drag_scroll - int(event.global_position.x - _drag_x)
