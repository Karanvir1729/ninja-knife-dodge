extends Node2D
## Star Cricket: the void bowls, you read the field and time the swing. One
## tap anywhere swings the blade toward the zone under the finger: a perfect
## swing is a six, a good one finds the gaps for four, a late one finds the
## fielders. Three wickets end the innings (one can be bought back once with
## a booster or a rewarded ad). Runs are the score.

const MARGIN := 28
const START_WICKETS := 3
const FIRST_BALL_IN := 2.0       # first release, after the opening toast
const BETWEEN_BALLS := 1.1       # outcome toast before the field re-sets
const FIELD_LEAD := 0.6          # fielders are shown this long before release
const SWING_FROM_BALL := 8       # the void starts swinging the ball from here
const SWING_CHANCE := 0.45

var runs := 0
var wickets_left := START_WICKETS
var balls := 0
var fours := 0
var sixes := 0
var streak := 0
var best_streak := 0
var elapsed := 0.0
var ended := false
var paused := false
var ball_in_flight: bool:
	get:
		return _field != null and is_instance_valid(_field) and _field.ball_in_flight

var _offering := false
var _offer_used := false
var _next_in := FIRST_BALL_IN
var _fielders_set := false
var _swung := false
var _line_bag: Array = []
var _shake := 0.0
var _window_scale := 1.0
var _pill_tween: Tween
var _flash_tween: Tween
var _toast_tween: Tween
var _score_tween: Tween
var _fire_tween: Tween
@onready var _field: Node2D = %Field

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	AudioManager.play_music("knife")
	Globals.apply_safe_margins(%Root, MARGIN)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%PauseBtn.pressed.connect(toggle_pause)
	$Pause.set_title("PAUSED", "The void waits to bowl.", Globals.GREEN)
	$Pause.resume.connect(toggle_pause)
	$Pause.restart.connect(func(): Globals.go("cricket_play"))
	$Pause.menu.connect(func(): Globals.go("start"))
	%BestVal.text = str(SaveData.best_for("cricket"))
	# Own copy of the vignette material: a flash cut short by a state change
	# must not leave the shared resource tinted for the next innings.
	%Flash.material = %Flash.material.duplicate()
	%Flash.material.set_shader_parameter("strength", 0.0)
	%Banner.modulate.a = 0.0
	%Toast.modulate.a = 0.0
	%FireChip.visible = false
	_field.passed.connect(_on_passed)
	_update_runs(true)
	_update_wickets(true)
	_toast(str(Story.yard("cricket").get("drill", "READ THE FIELD. TIME THE SWING.")), 1.6)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, MARGIN)
	var r := Globals.view_rect()
	_field.layout(r)
	%TimingBar.custom_minimum_size = Vector2(clampf(r.size.x * 0.4, 360.0, 560.0), 18)

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if ended or paused or _offering:
		return
	elapsed += delta
	if _field.ball_in_flight:
		_field.tick(delta)
		if _field.ball_in_flight:
			%TimingBar.set_progress(_field.ball.t)
	else:
		_next_in -= delta
		if not _fielders_set and _next_in <= FIELD_LEAD:
			_place_fielders()
		if _next_in <= 0.0:
			_release()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

func _place_fielders() -> void:
	_fielders_set = true
	_field.set_fielders(CricketRules.random_fielders())

## 60% of balls are on the stumps, dealt from a bag of five so a run of wides
## never lasts long.
func _next_line_on_stumps() -> bool:
	if _line_bag.is_empty():
		_line_bag = [true, true, true, false, false]
		_line_bag.shuffle()
	return _line_bag.pop_back()

func _release() -> void:
	if not _fielders_set:
		_place_fielders()
	var travel := CricketRules.travel_time(balls)
	var line_x := 0.0
	if not _next_line_on_stumps():
		line_x = randf_range(62.0, 92.0) * (1.0 if randf() < 0.5 else -1.0)
	var swing := 0.0
	if balls + 1 >= SWING_FROM_BALL and randf() < SWING_CHANCE:
		swing = randf_range(34.0, 70.0) * (1.0 if randf() < 0.5 else -1.0)
	_field.bowl(travel, line_x, swing)
	_swung = false
	%TimingBar.set_ball(travel, CricketRules.PASS_GRACE, _window_scale)
	AudioManager.play_sfx("bowl", randf_range(0.95, 1.08), -4.0)

## The ball went past untouched: bowled if it was on the stumps, else a dot.
func _on_passed() -> void:
	var on: bool = _field.line_on_stumps()
	var out := CricketRules.outcome("miss", false, on)
	_field.pass_ball(on)
	_apply_outcome(out, 2)

# ---------------------------------------------------------------- public API

## Seconds until the current ball reaches the crease (-1 with no ball).
func time_to_arrival() -> float:
	return _field.time_to_arrival()

func current_line_on_stumps() -> bool:
	return _field.line_on_stumps()

## Zone indices 0..4 without a fielder for the current ball.
func gap_zones() -> Array:
	return _field.gap_zones()

## A global x coordinate that maps onto `zone` for tap_at.
func zone_center_x(zone: int) -> float:
	var r := Globals.view_rect()
	return r.position.x + r.size.x * 0.5 + CricketRules.zone_fraction(zone) * r.size.x * 0.5

## Ends the between-ball pause: the next ball is released on the next frame.
func debug_skip_wait() -> void:
	if ended or _offering or _field.ball_in_flight:
		return
	if not _fielders_set:
		_place_fielders()
	_next_in = 0.0

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(event.position)
	elif event is InputEventScreenTouch and event.pressed and event.index > 0:
		# Second finger: only the first touch is mouse-emulated.
		tap_at(event.position)

## The swing. The tap's x picks the zone; its timing against the ball's
## arrival at the crease picks the grade. One swing per ball.
func tap_at(global_pos: Vector2) -> void:
	if ended or paused or _offering:
		return
	if not _field.ball_in_flight or _swung:
		return
	_swung = true
	var r := Globals.view_rect()
	var zone := CricketRules.zone_for_x(global_pos.x - (r.position.x + r.size.x * 0.5), r.size.x * 0.5)
	_field.swing(zone)
	var b: Node2D = _field.ball
	var g := "miss"
	if b.t >= b.travel * CricketRules.EARLY_FRACTION:
		g = CricketRules.grade(absf(b.t - b.travel), _window_scale)
	if g == "miss":
		AudioManager.play_sfx("whoosh", 1.7, -12.0)
		return
	var out := CricketRules.outcome(g, _field.gap_zones().has(zone), b.on_stumps())
	_field.contact(out.kind, zone)
	_apply_outcome(out, zone)

# ---------------------------------------------------------------- scoring

func _apply_outcome(out: Dictionary, _zone: int) -> void:
	balls += 1
	%TimingBar.clear()
	var kind := str(out.kind)
	var color := CricketRules.color_for(kind)
	runs += int(out.runs)
	if kind == "four":
		fours += 1
	elif kind == "six":
		sixes += 1
	if kind == "four" or kind == "six":
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
	_update_fire()
	var at: Vector2 = _field.crease_point() + Vector2(0, -34)
	if bool(out.contact):
		AudioManager.play_sfx("bat_hit", 1.3 if kind == "six" else (1.05 if kind == "four" else 0.9))
		AudioManager.vibrate(15)
	match kind:
		"six":
			AudioManager.play_sfx("six", 1.0, -3.0)
			AudioManager.vibrate(40)
			_flash(Globals.GOLD, 0.55)
			_field.fx.popup("+6", at, Globals.GOLD, 32)
		"four":
			AudioManager.vibrate(20)
			_field.fx.popup("+4", at, Globals.CYAN, 28)
		"two", "fielded":
			_field.fx.popup("+2", at, color, 24)
		"dot":
			AudioManager.play_sfx("near_miss", 0.8, -8.0)
			_field.fx.popup("DOT", at, Globals.DIM, 22)
		_:
			_field.fx.popup(str(out.label), at, Globals.RED, 26)
	_banner(str(out.label), color)
	_update_runs()
	%BallsVal.text = str(balls)
	if bool(out.wicket):
		_lose_wicket()
	else:
		_schedule_next()

func _lose_wicket() -> void:
	wickets_left -= 1
	AudioManager.play_sfx("wicket")
	AudioManager.vibrate(60)
	_shake = 1.0
	_flash(Globals.RED, 0.7)
	_update_wickets()
	if wickets_left <= 0:
		_out_of_wickets()
	else:
		_schedule_next()

func _schedule_next(extra: float = 0.0) -> void:
	_next_in = BETWEEN_BALLS + FIELD_LEAD + extra
	_fielders_set = false

func _out_of_wickets() -> void:
	if ended:
		return
	if not _offer_used and (SaveData.booster_count("life") > 0 or Ads.available("life")):
		_offer_used = true
		_offering = true
		await get_tree().create_timer(0.5).timeout
		if ended or not is_inside_tree():
			return
		var o := OfferOverlay.open(get_tree(), "life")
		var ok: bool = await o.finished
		if not is_inside_tree():
			return
		_offering = false
		if ok:
			wickets_left = 1
			_update_wickets()
			_toast("ONE MORE WICKET", 1.3)
			_schedule_next(0.6)
			return
	_end()

func _end() -> void:
	if ended:
		return
	ended = true
	_offering = false
	_field.clear_fielders()
	AudioManager.play_sfx("level_fail", 1.0, -6.0)
	_toast("FIFTY. PIP IS TELLING THE TEAM." if runs >= int(Story.yard("cricket").get("goal_target", 50)) else "INNINGS OVER", 1.2)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	Globals.go("arcade_result", {
		"game": "cricket", "score": runs, "time": elapsed, "title": CricketRules.title_for(runs),
		"detail": "%d runs · %d balls" % [runs, balls],
		"stats": [
			[runs, "RUNS"], [balls, "BALLS"],
			[fours, "FOURS", Globals.CYAN], [sixes, "SIXES", Globals.GOLD],
		],
		"quip": _quip(),
	})

func _quip() -> String:
	if runs >= 200:
		return "Sensei: \"Two hundred. The void will need a new bowler.\""
	if runs >= 100:
		return "Sensei: \"A century. Do not smile yet; the stumps remember.\""
	if runs >= 50:
		return "Pip: \"Fifty! I am telling the team a ninja did it. They might finally listen.\""
	if runs >= 25:
		return "Sensei: \"You read the field. Now read it faster.\""
	if runs == 0:
		return "Sensei: \"Three wickets, no runs. The team from Japan started here too.\""
	return "Sensei: \"The ball arrives when it arrives, not when you swing.\""

# ---------------------------------------------------------------- HUD

func _update_runs(instant: bool = false) -> void:
	%Runs.text = str(runs)
	if instant:
		return
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	%Runs.pivot_offset = Vector2(0, %Runs.size.y * 0.5)
	%Runs.scale = Vector2(1.08, 1.08)
	_score_tween = create_tween()
	_score_tween.tween_property(%Runs, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)

func _update_wickets(instant: bool = false) -> void:
	%Stumps.lit = wickets_left
	if instant:
		return
	%Stumps.pivot_offset = %Stumps.size * 0.5
	%Stumps.scale = Vector2(1.5, 1.5)
	var t := create_tween()
	t.tween_property(%Stumps, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _update_fire() -> void:
	var show := streak >= 3
	%FireVal.text = "x%d" % streak
	if _fire_tween and _fire_tween.is_valid():
		_fire_tween.kill()
	if not show:
		if %FireChip.visible:
			_fire_tween = create_tween()
			_fire_tween.tween_property(%FireChip, "modulate:a", 0.0, 0.25)
			_fire_tween.tween_callback(func(): %FireChip.visible = false)
		return
	%FireChip.visible = true
	%FireChip.modulate.a = 1.0
	%FireChip.pivot_offset = Vector2(0, %FireChip.size.y * 0.5)
	%FireChip.scale = Vector2(1.18, 1.18)
	_fire_tween = create_tween()
	_fire_tween.tween_property(%FireChip, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## The outcome pill at the top centre.
func _banner(text: String, color: Color) -> void:
	%BannerLabel.text = text
	%BannerLabel.add_theme_color_override("font_color", color)
	var sb: StyleBoxFlat = %Banner.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(color, 0.6)
	sb.shadow_color = Color(color, 0.22)
	%Banner.add_theme_stylebox_override("panel", sb)
	if _pill_tween and _pill_tween.is_valid():
		_pill_tween.kill()
	%Banner.modulate.a = 0.0
	%Banner.pivot_offset = %Banner.size * 0.5
	%Banner.scale = Vector2(0.86, 0.86)
	_pill_tween = create_tween()
	_pill_tween.set_parallel(true)
	_pill_tween.tween_property(%Banner, "modulate:a", 1.0, 0.12)
	_pill_tween.tween_property(%Banner, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_pill_tween.chain().tween_interval(0.9)
	_pill_tween.chain().tween_property(%Banner, "modulate:a", 0.0, 0.35)

func _flash(color: Color, strength: float) -> void:
	var mat: ShaderMaterial = %Flash.material
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("strength", strength)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float): mat.set_shader_parameter("strength", v), strength, 0.0, 0.45).set_ease(Tween.EASE_OUT)

func _toast(text: String, hold: float = 1.8) -> void:
	%Toast.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	%Toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(%Toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(%Toast, "modulate:a", 0.0, 0.4)

# ---------------------------------------------------------------- pause

func toggle_pause() -> void:
	if ended or _offering:
		return
	paused = not paused
	get_tree().paused = paused
	$Pause.set_open(paused)
	AudioManager.click()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if Ads.is_showing():
			return
		if not paused and not ended and not _offering and is_inside_tree() and elapsed > 0.5:
			toggle_pause()
