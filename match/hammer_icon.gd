extends Control
class_name HammerIcon
## A small mallet drawn with _draw(), used as the HAMMER booster's icon
## (there is no generated hammer sprite). Sized like the 30 px theme icons.

var color: Color = Color("ebeef8")
var box := 30.0

func _draw() -> void:
	var c := size * 0.5
	var s := box / 30.0
	# Handle from bottom-left up to the head.
	draw_line(c + Vector2(-12, 12) * s, c + Vector2(4, -4) * s, color, 4.0 * s, true)
	draw_circle(c + Vector2(-12, 12) * s, 2.0 * s, color)
	# Head: a rounded bar across the top-right end, perpendicular to the handle.
	draw_set_transform(c + Vector2(6, -6) * s, PI / 4.0, Vector2.ONE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(3.0 * s))
	sb.draw(get_canvas_item(), Rect2(Vector2(-11, -6) * s, Vector2(22, 12) * s))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
