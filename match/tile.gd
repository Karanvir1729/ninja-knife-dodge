extends Node2D
class_name MatchTile
## One shuriken on the board: colour, optional special overlay, selection and hint states.

var color_index := 0
var special := 0
var cell := Vector2i.ZERO
var _hint_tween: Tween
var _idle_spin := 0.0
var _hue := 0.0

func setup(p_color: int, p_special: int, tile_px: float) -> void:
	color_index = p_color
	special = p_special
	var col: Color = Globals.GEM_COLORS[p_color % Globals.GEM_COLORS.size()]
	var s := tile_px / float($Shuriken.texture.get_width())
	var so := tile_px / 128.0
	$Shuriken.scale = Vector2(s, s)
	$Shuriken.modulate = col
	$Ring.scale = Vector2(so, so)
	$Ring.modulate = Color(1, 1, 1, 0.35)
	$Glow.scale = Vector2(so * 0.62, so * 0.62)
	$Glow.modulate = Color(col, 0.42)
	$Overlay.scale = Vector2(so, so)
	$Select.scale = Vector2(so * 0.75, so * 0.75)
	$Select.visible = false
	_idle_spin = (float(cell.x * 7 + cell.y * 13) if cell != Vector2i.ZERO else 0.0)
	$Shuriken.rotation = deg_to_rad(fmod(_idle_spin, 4.0) * 22.0)
	$Overlay.rotation = 0.0
	set_special(p_special)

func set_special(s: int) -> void:
	special = s
	var tex_path := ""
	match s:
		BoardModel.Special.LINE_H: tex_path = "res://graphics/gen/special_line_h.png"
		BoardModel.Special.LINE_V: tex_path = "res://graphics/gen/special_line_v.png"
		BoardModel.Special.BURST: tex_path = "res://graphics/gen/special_burst.png"
		BoardModel.Special.PRISM: tex_path = "res://graphics/gen/special_prism.png"
	$Overlay.visible = tex_path != ""
	if tex_path != "":
		$Overlay.texture = load(tex_path)
		$Overlay.modulate = Color(1, 1, 1, 0.95)
	if s == BoardModel.Special.PRISM:
		$Glow.modulate = Color(1, 1, 1, 0.55)
	set_process(s != BoardModel.Special.NONE)

func _process(delta: float) -> void:
	match special:
		BoardModel.Special.PRISM:
			_hue = fmod(_hue + delta * 0.35, 1.0)
			$Shuriken.modulate = Color.from_hsv(_hue, 0.55, 1.0)
			$Shuriken.rotation += delta * 1.2
			$Overlay.rotation -= delta * 0.8
		BoardModel.Special.LINE_H, BoardModel.Special.LINE_V:
			$Overlay.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		BoardModel.Special.BURST:
			var k := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.007)
			$Overlay.scale = $Shuriken.scale * k

func set_selected(on: bool) -> void:
	$Select.visible = on
	if on:
		$Select.modulate = Color(1, 1, 1, 0.0)
		create_tween().tween_property($Select, "modulate:a", 0.9, 0.12)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_ease(Tween.EASE_OUT)
	else:
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)

func start_hint() -> void:
	stop_hint()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.38).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.38).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func stop_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	scale = Vector2.ONE

func wiggle() -> void:
	var t := create_tween()
	t.tween_property(self, "rotation", 0.12, 0.05)
	t.tween_property(self, "rotation", -0.12, 0.08)
	t.tween_property(self, "rotation", 0.0, 0.05)

## Pop out and free. Returns the tween so callers can await it.
func pop() -> Tween:
	stop_hint()
	z_index = 3
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.35, 1.35), 0.09).set_ease(Tween.EASE_OUT)
	t.tween_property($Shuriken, "modulate", Color(1, 1, 1, 1), 0.09)
	t.chain().tween_property(self, "scale", Vector2(0.0, 0.0), 0.16).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)
	return t

func appear() -> void:
	scale = Vector2(0.0, 0.0)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
