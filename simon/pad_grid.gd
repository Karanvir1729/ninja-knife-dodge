extends GridContainer
class_name SimonPadGrid
## The 3x3 pad grid shared by Sensei Says play and its tutorial. Nine pads in
## distinct hues spread around the colour wheel; pad i plays tone pad_(i+1).

signal pad_tapped(index: int)

const PAD_SCRIPT := preload("res://simon/pad.gd")
const COUNT := 9
const GAP := 0.12

var pads: Array = []
## When false, taps are swallowed (playback, between rounds, game over).
var input_enabled := false
var _shake_tween: Tween
var _shake_origin := Vector2.ZERO

func _ready() -> void:
	columns = 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 18)
	add_theme_constant_override("v_separation", 18)
	for i in COUNT:
		var pad: SimonPad = PAD_SCRIPT.new()
		pad.setup(i, pad_color(i))
		pad.tapped.connect(_on_pad_tapped)
		add_child(pad)
		pads.append(pad)

## Nine bright hues 40 degrees apart, ordered so neighbours contrast.
static func pad_color(i: int) -> Color:
	return Color.from_hsv(float((i * 4) % COUNT) / float(COUNT), 0.72, 1.0)

func _on_pad_tapped(i: int) -> void:
	if input_enabled:
		pad_tapped.emit(i)

func light(i: int, duration: float, tone: bool = true) -> void:
	if i >= 0 and i < pads.size():
		pads[i].light(duration, tone)

func flash_wrong(i: int) -> void:
	if i >= 0 and i < pads.size():
		pads[i].flash_wrong()

## Light each pad of `seq` in turn (`interval` seconds lit, GAP between).
## Awaitable; stops quietly if the grid leaves the tree.
func play_sequence(seq: Array, interval: float) -> void:
	for i in seq:
		if not is_inside_tree():
			return
		light(i, interval)
		await sleep(interval + GAP)

## Await a node-bound pause: it pauses with the tree and dies with the grid,
## so a state change mid-sequence never resumes a freed coroutine.
func sleep(sec: float) -> void:
	var t := create_tween()
	t.tween_interval(sec)
	await t.finished

## Global centre of pad i (for tutorial helpers), ignoring its light scale.
func pad_center(i: int) -> Vector2:
	var p: Control = pads[i]
	return global_position + p.position + p.size * 0.5

func shake(strength: float = 14.0, duration: float = 0.45) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _shake_origin
	_shake_origin = position
	_shake_tween = create_tween()
	_shake_tween.tween_method(_shake_step.bind(strength), 1.0, 0.0, duration)
	_shake_tween.tween_callback(func(): position = _shake_origin)

func _shake_step(t: float, strength: float) -> void:
	position = _shake_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * t
