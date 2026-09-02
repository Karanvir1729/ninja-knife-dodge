extends Control
class_name SimonPad
## One pad of the Sensei Says grid: a rounded tile (drawn like a match board
## cell) with a tinted shuriken and a soft glow behind it that brightens when
## the pad lights. Emits `tapped` when a left press lands inside the tile, so
## taps on HUD buttons never reach the game.

signal tapped(index: int)

const GLOW_TEX := preload("res://graphics/gen/glow.png")
const SHURIKEN_TEX := preload("res://graphics/gen/shuriken.png")

var index := 0
var hue := Color.WHITE
var lit := false
## 0..1 red mix driven by flash_wrong().
var flash := 0.0:
	set(v):
		flash = v
		_apply()

var _glow: TextureRect
var _icon: TextureRect
var _fill := Color(Globals.BG1, 0.92)
var _border := Globals.LINE
var _light_tween: Tween
var _flash_tween: Tween

func setup(p_index: int, p_hue: Color) -> void:
	index = p_index
	hue = p_hue
	name = "Pad%d" % (p_index + 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _make_sprite(GLOW_TEX, mat)
	_icon = _make_sprite(SHURIKEN_TEX, null)
	_icon.rotation = deg_to_rad(fmod(float(index) * 11.0, 90.0))
	resized.connect(_relayout)
	_relayout()
	_apply()
	set_process(false)

func _make_sprite(tex: Texture2D, mat: Material) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.material = mat
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(t)
	return t

func _relayout() -> void:
	pivot_offset = size * 0.5
	var s := minf(size.x, size.y)
	var g := s * 1.3
	_glow.size = Vector2(g, g)
	_glow.position = (size - _glow.size) * 0.5
	var ic := s * 0.56
	_icon.size = Vector2(ic, ic)
	_icon.position = (size - _icon.size) * 0.5
	_icon.pivot_offset = _icon.size * 0.5
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _fill
	sb.set_border_width_all(2 if lit else 1)
	sb.border_color = _border
	sb.set_corner_radius_all(int(s * 0.14))
	if lit:
		sb.shadow_color = Color(hue, 0.35)
		sb.shadow_size = int(s * 0.08)
	sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

func _apply() -> void:
	var fill := Color(Globals.BG1, 0.92)
	var border := Globals.LINE
	var glow_col := hue
	var glow_a := 0.16
	var icon_col := hue
	if lit:
		fill = Globals.BG1.lerp(hue, 0.3)
		border = hue
		glow_a = 0.9
		icon_col = hue.lightened(0.5)
	if flash > 0.0:
		fill = fill.lerp(Globals.RED, 0.5 * flash)
		border = border.lerp(Globals.RED, flash)
		glow_col = glow_col.lerp(Globals.RED, flash)
		glow_a = maxf(glow_a, 0.7 * flash)
		icon_col = icon_col.lerp(Globals.RED, flash)
	_fill = fill
	_border = border
	if _glow:
		_glow.modulate = Color(glow_col, glow_a)
		_icon.modulate = icon_col
	queue_redraw()

## Light the pad for `duration` seconds: scale up 15%, bright glow, and the
## pad's own tone (pad_1..pad_9) unless `tone` is false.
func light(duration: float, tone: bool = true) -> void:
	if tone:
		AudioManager.play_sfx("pad_%d" % (index + 1))
	_set_lit(true)
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.07).set_ease(Tween.EASE_OUT)
	_light_tween.tween_interval(maxf(0.02, duration - 0.19))
	_light_tween.tween_callback(_set_lit.bind(false))
	_light_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN_OUT)

func _set_lit(on: bool) -> void:
	lit = on
	z_index = 1 if on else 0
	set_process(on)
	_apply()

func _process(delta: float) -> void:
	_icon.rotation += delta * 2.4

## Flash the tile red twice with a small squash.
func flash_wrong() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "flash", 1.0, 0.05)
	_flash_tween.tween_property(self, "flash", 0.25, 0.18)
	_flash_tween.tween_property(self, "flash", 1.0, 0.08)
	_flash_tween.tween_property(self, "flash", 0.0, 0.45)
	var s := create_tween()
	s.tween_property(self, "scale", Vector2(0.94, 0.94), 0.06)
	s.tween_property(self, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		tapped.emit(index)
