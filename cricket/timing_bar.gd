extends Control
## Thin bar under the pitch showing the ball's progress with a bright "hit
## window" band near its end. Set up per delivery with set_ball(), fed with
## set_progress() every frame and hidden again with clear().

## Opacity between balls (the tutorial keeps the bar faintly visible).
var idle_alpha := 0.0

var _travel := 1.35
var _grace := 0.23
var _scale := 1.0
var _t := -1.0
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = idle_alpha

## `travel` seconds to the crease, `grace` seconds it stays hittable after,
## `window_scale` widens the drawn windows (tutorial).
func set_ball(travel: float, grace: float, window_scale: float = 1.0) -> void:
	_travel = travel
	_grace = grace
	_scale = window_scale
	_t = 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	queue_redraw()

func set_progress(t: float) -> void:
	_t = t
	queue_redraw()

func clear() -> void:
	_t = -1.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", idle_alpha, 0.3)
	queue_redraw()

func _frac(sec: float) -> float:
	return clampf(sec / (_travel + _grace), 0.0, 1.0)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var y := h * 0.5
	var th := 6.0
	# Track.
	draw_line(Vector2(0, y), Vector2(w, y), Globals.LINE2, th)
	# Windows: OK (dim), GOOD (brighter), PERFECT (a bright line).
	var ok0 := _frac(_travel - CricketRules.OK * _scale) * w
	var ok1 := _frac(_travel + CricketRules.OK * _scale) * w
	var g0 := _frac(_travel - CricketRules.GOOD * _scale) * w
	var g1 := _frac(_travel + CricketRules.GOOD * _scale) * w
	var p0 := _frac(_travel - CricketRules.PERFECT * _scale) * w
	var p1 := _frac(_travel + CricketRules.PERFECT * _scale) * w
	draw_line(Vector2(ok0, y), Vector2(ok1, y), Color(Globals.GREEN, 0.22), th + 4)
	draw_line(Vector2(g0, y), Vector2(g1, y), Color(Globals.GREEN, 0.5), th + 4)
	draw_line(Vector2(p0, y), Vector2(p1, y), Color(Globals.GOLD, 0.9), th + 6)
	if _t < 0.0:
		return
	var px := _frac(_t) * w
	draw_line(Vector2(0, y), Vector2(px, y), Color(0.85, 1.0, 0.92, 0.9), th - 1)
	draw_circle(Vector2(px, y), 7.0, Color(Globals.GREEN, 0.35))
	draw_circle(Vector2(px, y), 4.0, Color(0.95, 1.0, 0.97, 1.0))
