extends Node2D
## The cricket field, drawn in code with the neon palette: a faint pitch with
## crease lines, three glowing stumps behind the batter's crease, the void
## mouth at the bowler's end, five shot zones fanning out from the crease,
## fielders on the arc, the ninja batter with a blade, and the ball in flight.
## The owning state drives it: layout(), set_fielders(), bowl(), tick(),
## swing(), then contact() / pass_ball() to animate the outcome.

signal passed   # the ball went by untouched, past the hittable window

const GLOW: Texture2D = preload("res://graphics/gen/glow.png")
const DOT: Texture2D = preload("res://graphics/gen/dot.png")
const STAR: Texture2D = preload("res://graphics/gen/player_star.png")
const BALL_SCRIPT: Script = preload("res://cricket/ball.gd")
const FX_SCRIPT: Script = preload("res://cricket/cricket_fx.gd")

const PITCH_W := 220.0
const STUMP_GAP := 16.0
const STUMP_H := 30.0
const FIELDER_RADIUS := 0.84   # fraction of the fan radius the fielders stand at

var cx := 704.0
var top_y := 111.0
var crease_y := 602.0
var stumps_y := 626.0
var rx := 640.0
var ry := 430.0

var fielders: Array = []
var ball: Node2D = null
var ball_in_flight := false
var pass_grace: float = CricketRules.PASS_GRACE
var fx: Node2D

var _stump_off: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _stump_rot: Array = [0.0, 0.0, 0.0]
var _bails_alpha := 1.0
var _stumps_broken := false
var _gap_alpha := 0.0
var _fielder_nodes: Dictionary = {}
var _fielder_layer: Node2D
var _balls: Node2D
var _bowler_halo: Sprite2D
var _bowler_core: Sprite2D
var _batter: Node2D
var _blade: Node2D
var _blade_tween: Tween
var _add: CanvasItemMaterial

const BLADE_REST := 0.45

func _ready() -> void:
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fielder_layer = Node2D.new()
	_fielder_layer.z_index = 1
	add_child(_fielder_layer)
	# The void mouth: the bowler's end glows green and breathes.
	_bowler_halo = Sprite2D.new()
	_bowler_halo.texture = GLOW
	_bowler_halo.material = _add
	_bowler_halo.modulate = Color(Globals.GREEN, 0.5)
	_bowler_halo.scale = Vector2(0.7, 0.7)
	_bowler_halo.z_index = 1
	add_child(_bowler_halo)
	_bowler_core = Sprite2D.new()
	_bowler_core.texture = GLOW
	_bowler_core.material = _add
	_bowler_core.modulate = Color(0.85, 1.0, 0.92, 0.9)
	_bowler_core.scale = Vector2(0.2, 0.2)
	_bowler_core.z_index = 1
	add_child(_bowler_core)
	var breathe := create_tween().set_loops()
	breathe.tween_property(_bowler_halo, "scale", Vector2(0.78, 0.78), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(_bowler_halo, "scale", Vector2(0.66, 0.66), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_balls = Node2D.new()
	_balls.z_index = 2
	add_child(_balls)
	# The batter: a small ninja mark at the crease with a blade that swings.
	_batter = Node2D.new()
	_batter.z_index = 3
	add_child(_batter)
	var bglow := Sprite2D.new()
	bglow.texture = GLOW
	bglow.material = _add
	bglow.modulate = Color(Globals.CYAN, 0.3)
	bglow.scale = Vector2(0.3, 0.3)
	_batter.add_child(bglow)
	var star := Sprite2D.new()
	star.texture = STAR
	star.modulate = Color.WHITE
	star.scale = Vector2(0.5, 0.5)
	_batter.add_child(star)
	_blade = Node2D.new()
	_blade.rotation = BLADE_REST
	_batter.add_child(_blade)
	var blade_glow := Line2D.new()
	blade_glow.points = PackedVector2Array([Vector2(0, -6), Vector2(0, -50)])
	blade_glow.width = 13.0
	blade_glow.default_color = Color(Globals.CYAN, 0.28)
	blade_glow.material = _add
	blade_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	blade_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_blade.add_child(blade_glow)
	var blade := Line2D.new()
	blade.points = PackedVector2Array([Vector2(0, -6), Vector2(0, -50)])
	blade.width = 4.5
	blade.default_color = Color(0.93, 0.96, 1.0, 1.0)
	blade.end_cap_mode = Line2D.LINE_CAP_ROUND
	_blade.add_child(blade)
	fx = FX_SCRIPT.new()
	fx.z_index = 4
	add_child(fx)
	layout(Globals.view_rect())

# ---------------------------------------------------------------- geometry

## Places the pitch relative to a view rectangle (call again on resize).
func layout(r: Rect2) -> void:
	cx = r.position.x + r.size.x * 0.5
	crease_y = r.position.y + r.size.y * 0.76
	top_y = crease_y - r.size.y * 0.62
	stumps_y = crease_y + 22.0
	rx = r.size.x * 0.46
	ry = minf(rx * 0.75, crease_y - top_y - 60.0)
	_bowler_halo.position = Vector2(cx, top_y)
	_bowler_core.position = Vector2(cx, top_y)
	_batter.position = Vector2(cx - 48.0, crease_y + 6.0)
	for z in _fielder_nodes.keys():
		_fielder_nodes[z].position = fielder_pos(z)
	if ball != null and is_instance_valid(ball) and ball_in_flight:
		ball.start = Vector2(cx, top_y)
		ball.end = Vector2(cx + ball.line_x, crease_y)
	queue_redraw()

func crease_point() -> Vector2:
	return Vector2(cx, crease_y)

## Angle (maths convention, y up) at the centre of a zone: far left = 162 deg.
func zone_angle(zone: int) -> float:
	return deg_to_rad(162.0 - 36.0 * clampi(zone, 0, 4))

func zone_dir(zone: int) -> Vector2:
	var a := zone_angle(zone)
	return Vector2(cos(a), -sin(a))

## A point `frac` of the way out along the fan in the middle of `zone`.
func zone_point(zone: int, frac: float) -> Vector2:
	var a := zone_angle(zone)
	return Vector2(cx + rx * frac * cos(a), crease_y - ry * frac * sin(a))

func fielder_pos(zone: int) -> Vector2:
	return zone_point(zone, FIELDER_RADIUS)

func gap_zones() -> Array:
	var out := []
	for z in CricketRules.ZONE_COUNT:
		if not fielders.has(z):
			out.append(z)
	return out

## Hide the batter and blade (a story film puts a guide at the crease instead).
func set_batter_visible(on: bool) -> void:
	_batter.visible = on

# ---------------------------------------------------------------- fielders

func set_fielders(zones: Array) -> void:
	clear_fielders()
	fielders = zones.duplicate()
	fielders.sort()
	for z in fielders:
		var f := _make_fielder(z)
		_fielder_nodes[z] = f
	create_tween().tween_method(func(v: float): _gap_alpha = v; queue_redraw(), _gap_alpha, 1.0, 0.3)

func clear_fielders() -> void:
	for z in _fielder_nodes.keys():
		var f: Node2D = _fielder_nodes[z]
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(f, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
		t.tween_property(f, "modulate:a", 0.0, 0.2)
		t.chain().tween_callback(f.queue_free)
	_fielder_nodes.clear()
	fielders = []
	create_tween().tween_method(func(v: float): _gap_alpha = v; queue_redraw(), _gap_alpha, 0.0, 0.2)

func _make_fielder(zone: int) -> Node2D:
	var f := Node2D.new()
	f.position = fielder_pos(zone)
	var g := Sprite2D.new()
	g.texture = GLOW
	g.material = _add
	g.modulate = Color(Globals.ORANGE, 0.5)
	g.scale = Vector2(0.3, 0.3)
	f.add_child(g)
	var d := Sprite2D.new()
	d.texture = DOT
	d.modulate = Globals.ORANGE.lightened(0.2)
	d.scale = Vector2(1.5, 1.5)
	f.add_child(d)
	f.scale = Vector2.ZERO
	_fielder_layer.add_child(f)
	var t := create_tween()
	t.tween_property(f, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return f

## The fielder in `zone` reacts to the ball (a catch pulses harder).
func pulse_fielder(zone: int, strong: bool) -> void:
	if not _fielder_nodes.has(zone):
		return
	var f: Node2D = _fielder_nodes[zone]
	if not is_instance_valid(f):
		return
	f.scale = Vector2.ONE * (1.9 if strong else 1.4)
	var t := create_tween()
	t.tween_property(f, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	fx.ring(f.position, Globals.RED if strong else Globals.ORANGE, 1.3 if strong else 0.8)

# ---------------------------------------------------------------- the ball

## Releases a ball: `travel` seconds to the crease, `line_x` where it crosses
## it (0 = on the stumps), `swing_amp` the lateral drift that resolves late.
func bowl(travel: float, line_x: float, swing_amp: float) -> Node2D:
	if _stumps_broken:
		reset_stumps()
	var b: Node2D = BALL_SCRIPT.new()
	b.travel = travel
	b.line_x = line_x
	b.swing_amp = swing_amp
	b.start = Vector2(cx, top_y)
	b.end = Vector2(cx + line_x, crease_y)
	_balls.add_child(b)
	ball = b
	ball_in_flight = true
	# Release cue: the void mouth pulses.
	_bowler_core.scale = Vector2(0.55, 0.55)
	create_tween().tween_property(_bowler_core, "scale", Vector2(0.2, 0.2), 0.35).set_ease(Tween.EASE_OUT)
	fx.ring(Vector2(cx, top_y), Globals.GREEN, 0.9)
	return b

func tick(delta: float) -> void:
	if ball == null or not ball_in_flight or not is_instance_valid(ball):
		return
	ball.tick(delta)
	if ball.t >= ball.travel + pass_grace:
		ball_in_flight = false
		passed.emit()

func time_to_arrival() -> float:
	if ball_in_flight and ball != null and is_instance_valid(ball):
		return ball.time_to_arrival()
	return -1.0

func line_on_stumps() -> bool:
	return ball != null and is_instance_valid(ball) and ball.on_stumps()

## The blade sweeps toward `zone` (a 0.12 s rotation) and settles back.
func swing(zone: int) -> void:
	if _blade_tween and _blade_tween.is_valid():
		_blade_tween.kill()
	var target := lerpf(-1.7, 1.9, float(clampi(zone, 0, 4)) / 4.0)
	_blade.rotation = BLADE_REST + 0.9
	_blade_tween = create_tween()
	_blade_tween.tween_property(_blade, "rotation", target, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_blade_tween.tween_property(_blade, "rotation", BLADE_REST, 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Animates a contact outcome (see CricketRules.outcome) toward `zone`.
func contact(kind: String, zone: int) -> void:
	var b := ball
	ball = null
	ball_in_flight = false
	if b == null or not is_instance_valid(b):
		return
	var at: Vector2 = b.position
	var dir := zone_dir(zone)
	match kind:
		"six":
			fx.burst(at, Globals.GOLD, 14, 130.0, dir * 110.0)
			fx.ring(at, Globals.GOLD, 1.5)
			b.fly(zone_point(zone, 1.3), 0.6, 1.5)
		"four":
			fx.burst(at, Globals.CYAN, 10, 110.0, dir * 80.0)
			fx.ring(at, Globals.CYAN, 1.1)
			b.fly(zone_point(zone, 1.12), 0.55, 1.15)
		"two":
			fx.burst(at, Globals.GREEN, 7, 80.0, dir * 40.0)
			b.fly(zone_point(zone, 0.62), 0.5, 1.0, 0.15)
		"fielded":
			fx.burst(at, Globals.MUTED, 6, 70.0, dir * 40.0)
			b.fly(fielder_pos(zone), 0.45, 0.9, 0.05)
			var t := create_tween()
			t.tween_interval(0.42)
			t.tween_callback(pulse_fielder.bind(zone, false))
		"caught":
			fx.burst(at, Globals.ORANGE, 8, 80.0, dir * 50.0)
			b.fly(fielder_pos(zone), 0.4, 0.9)
			var t2 := create_tween()
			t2.tween_interval(0.38)
			t2.tween_callback(pulse_fielder.bind(zone, true))
		_:
			b.vanish()

## The ball went by: it either breaks the stumps or runs through to the keeper.
func pass_ball(bowled: bool) -> void:
	var b := ball
	ball = null
	ball_in_flight = false
	if b == null or not is_instance_valid(b):
		return
	if bowled:
		var hit := Vector2(cx, stumps_y + STUMP_H * 0.4)
		fx.burst(hit, Globals.RED, 12, 120.0)
		fx.ring(hit, Globals.RED, 1.2)
		b.fly(hit, 0.06, 1.0)
		break_stumps()
	else:
		b.fly(b.point_at(1.0) + Vector2(0, 150.0), 0.55, 0.8)

# ---------------------------------------------------------------- stumps

func break_stumps() -> void:
	_stumps_broken = true
	var targets := []
	for i in 3:
		targets.append([Vector2(randf_range(-40, 40) + (i - 1) * 26.0, randf_range(18, 46)), randf_range(-1.6, 1.6)])
	var t := create_tween()
	t.tween_method(func(v: float):
		for i in 3:
			_stump_off[i] = Vector2.ZERO.lerp(targets[i][0], v)
			_stump_rot[i] = lerpf(0.0, targets[i][1], v)
		_bails_alpha = 1.0 - v
		queue_redraw(), 0.0, 1.0, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func reset_stumps() -> void:
	_stumps_broken = false
	var from_off: Array = _stump_off.duplicate()
	var from_rot: Array = _stump_rot.duplicate()
	var t := create_tween()
	t.tween_method(func(v: float):
		for i in 3:
			_stump_off[i] = (from_off[i] as Vector2).lerp(Vector2.ZERO, v)
			_stump_rot[i] = lerpf(from_rot[i], 0.0, v)
		_bails_alpha = v
		queue_redraw(), 0.0, 1.0, 0.28).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var origin := Vector2(cx, crease_y)
	# Five shot zones fanning out from the crease.
	for i in CricketRules.ZONE_COUNT:
		var a0 := deg_to_rad(180.0 - 36.0 * i)
		var a1 := deg_to_rad(180.0 - 36.0 * (i + 1))
		var pts := PackedVector2Array([origin])
		for k in 13:
			var a := lerpf(a0, a1, float(k) / 12.0)
			pts.append(origin + Vector2(rx * cos(a), -ry * sin(a)))
		var col: Color = Color(Globals.CYAN, 0.035) if i % 2 == 0 else Color(Globals.VIOLET, 0.03)
		if not fielders.is_empty():
			if fielders.has(i):
				col = col.lerp(Color(Globals.ORANGE, 0.05), _gap_alpha)
			else:
				col = col.lerp(Color(Globals.GREEN, 0.075), _gap_alpha)
		draw_colored_polygon(pts, col)
		draw_polyline(pts.slice(1), Color(Globals.LINE2, 0.55), 2.0)
		draw_line(origin, pts[1], Color(Globals.LINE, 0.95), 1.5)
		if i == CricketRules.ZONE_COUNT - 1:
			draw_line(origin, pts[pts.size() - 1], Color(Globals.LINE, 0.95), 1.5)
	# The pitch.
	var pr := Rect2(cx - PITCH_W * 0.5, top_y, PITCH_W, crease_y - top_y + STUMP_H + 36.0)
	draw_rect(pr, Color(Globals.GREEN, 0.045))
	draw_rect(pr, Color(Globals.GREEN, 0.22), false, 1.5)
	# Crease lines: popping crease at the batter's end, bowling crease at the top.
	draw_line(Vector2(pr.position.x - 18.0, crease_y), Vector2(pr.end.x + 18.0, crease_y), Color(Globals.TEXT, 0.55), 2.0)
	draw_line(Vector2(pr.position.x, crease_y - 44.0), Vector2(pr.position.x, crease_y + 40.0), Color(Globals.TEXT, 0.25), 2.0)
	draw_line(Vector2(pr.end.x, crease_y - 44.0), Vector2(pr.end.x, crease_y + 40.0), Color(Globals.TEXT, 0.25), 2.0)
	draw_line(Vector2(pr.position.x - 18.0, top_y + 26.0), Vector2(pr.end.x + 18.0, top_y + 26.0), Color(Globals.TEXT, 0.3), 2.0)
	# The void mouth sits in a dark disc.
	draw_circle(Vector2(cx, top_y), 30.0, Color(Globals.BG0, 0.9))
	# Stumps with a soft ground glow.
	draw_circle(Vector2(cx, stumps_y + STUMP_H * 0.5), 34.0, Color(Globals.GREEN, 0.07))
	for i in 3:
		var base := Vector2(cx + (i - 1) * STUMP_GAP, stumps_y)
		var off: Vector2 = _stump_off[i]
		var rot: float = _stump_rot[i]
		var p0 := base + off
		var p1 := p0 + Vector2(0, STUMP_H).rotated(rot)
		draw_line(p0, p1, Color(Globals.GREEN, 0.22), 12.0)
		draw_line(p0, p1, Color(Globals.GREEN, 0.65), 6.5)
		draw_line(p0, p1, Color(0.92, 1.0, 0.96, 1.0), 3.0)
	if _bails_alpha > 0.0:
		draw_line(Vector2(cx - STUMP_GAP - 5.0, stumps_y - 2.0), Vector2(cx + STUMP_GAP + 5.0, stumps_y - 2.0), Color(Globals.GOLD, 0.85 * _bails_alpha), 3.0)
