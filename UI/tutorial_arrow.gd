extends Node2D
## Pulsing arrow used by the tutorials to point from one spot to another.

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var _t := 0.0

func point(a: Vector2, b: Vector2) -> void:
	from = a
	to = b
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if from == to:
		return
	var dir := (to - from).normalized()
	var pulse: float = 0.65 + 0.35 * sin(_t * 5.0)
	var dist := from.distance_to(to)
	var inset := minf(26.0, dist * 0.18)
	var a := from + dir * inset
	var b := to - dir * inset
	var col := Color(color, pulse)
	draw_line(a, b, Color(Globals.BG0, pulse * 0.8), 12.0, true)
	draw_line(a, b, col, 6.0, true)
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([b + dir * 14.0, b - dir * 4.0 + n * 11.0, b - dir * 4.0 - n * 11.0]), col)
