extends Control
## Three little stumps drawn in code for the HUD; they dim as wickets fall.

var lit := 3:
	set(v):
		lit = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(54, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	for i in 3:
		var x := w * 0.5 + (i - 1) * 15.0
		var on := i < lit
		var col: Color = Globals.GREEN if on else Globals.LINE2
		if on:
			draw_line(Vector2(x, 4), Vector2(x, h - 2), Color(col, 0.22), 9.0)
		draw_line(Vector2(x, 4), Vector2(x, h - 2), col, 3.5)
	var bail_col: Color = Color(Globals.GREEN, 0.8) if lit > 0 else Globals.LINE2
	draw_line(Vector2(w * 0.5 - 17, 3), Vector2(w * 0.5 + 17, 3), bail_col, 2.0)
