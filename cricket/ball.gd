extends Node2D
## One delivery: a glowing ball that leaves the bowler's end and travels
## straight down the pitch to the crease in `travel` seconds, growing a little
## as it comes (perspective). `line_x` is where it crosses the crease relative
## to the stumps; `swing_amp` adds a sine drift that resolves before arrival.
## The owner calls tick(); flight after contact is animated by the field.

const GLOW: Texture2D = preload("res://graphics/gen/glow.png")

var travel := 1.35
var line_x := 0.0
var swing_amp := 0.0
var start := Vector2.ZERO
var end := Vector2.ZERO
var t := 0.0
## Set by the field once the delivery is over (contact or passed).
var done := false

var _halo: Sprite2D
var _core: Sprite2D
var _trail: Line2D
var _history: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail = Line2D.new()
	_trail.width = 7.0
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.material = add
	var grad := Gradient.new()
	grad.set_color(0, Color(Globals.GREEN, 0.0))
	grad.set_color(1, Color(0.85, 1.0, 0.92, 0.7))
	_trail.gradient = grad
	_trail.top_level = true
	_trail.z_index = -1
	add_child(_trail)
	_halo = Sprite2D.new()
	_halo.texture = GLOW
	_halo.material = add
	_halo.modulate = Color(Globals.GREEN, 0.38)
	_halo.scale = Vector2(0.42, 0.42)
	add_child(_halo)
	_core = Sprite2D.new()
	_core.texture = GLOW
	_core.material = add
	_core.modulate = Color(0.9, 1.0, 0.95, 1.0)
	_core.scale = Vector2(0.15, 0.15)
	add_child(_core)
	position = point_at(0.0)
	scale = Vector2.ONE * 0.62

func on_stumps() -> bool:
	return absf(line_x) < 30.0

func progress() -> float:
	return t / maxf(0.01, travel)

func time_to_arrival() -> float:
	return travel - t

## Position along the delivery for progress `p` (1 = the crease). Past the
## crease the ball slows to a keeper's pace.
func point_at(p: float) -> Vector2:
	var pc := clampf(p, 0.0, 1.0)
	var pos := start.lerp(end, pc)
	pos.x += swing_amp * sin(PI * pc)
	if p > 1.0:
		pos += (end - start) * (p - 1.0) * 0.35
	return pos

func tick(delta: float) -> void:
	t += delta
	position = point_at(progress())
	var pc := clampf(progress(), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.62, 1.0, pc)
	_history.append(position)
	while _history.size() > 9:
		_history.remove_at(0)
	_trail.points = _history

## Stops the trail growing and lets it dissolve behind the shot.
func release_trail() -> void:
	var tr := _trail
	create_tween().tween_property(tr, "modulate:a", 0.0, 0.25)

## Flies to `to` over `sec` seconds then fades; `grow` scales it up on the way.
func fly(to: Vector2, sec: float, grow: float = 1.0, fade_delay: float = 0.0) -> void:
	done = true
	release_trail()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", to, sec).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "scale", Vector2.ONE * grow, sec).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(fade_delay)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)

## Bursts out of existence on the spot.
func vanish() -> void:
	done = true
	release_trail()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE * 1.6, 0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)
