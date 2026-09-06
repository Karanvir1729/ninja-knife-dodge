extends Node2D
## Star Cricket walkthrough, in the shared tutorial format: an instruction on
## top, a glowing helper on the thing to tap, step dots at the bottom. The
## balls are slow and the timing windows twice as wide as in the game.

const STEPS := [
	"THE VOID BOWLS. TAP WHEN THE BALL REACHES THE CREASE.",
	"THREE FIELDERS WAIT. TAP ON THE SIDE WITH A GAP.",
	"PERFECT TIMING CLEARS EVERYONE. THAT IS A SIX.",
	"THREE WICKETS. MAKE THEM COUNT.",
]
const WINDOW_SCALE := 2.0
const TRAVEL := [2.2, 2.0, 1.9]
const FIELDERS := [[], [1, 2, 3], [0, 2, 4]]
const HELPER_GAP_ZONE := 4

var step := -1
var runs := 0
var ball_in_flight: bool:
	get:
		return _field != null and is_instance_valid(_field) and _field.ball_in_flight

var _done := false
var _in_intro := false
var _swung := false
var _bowl_in := -1.0
var _flash_tween: Tween
@onready var _field: Node2D = %Field

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Skip.pressed.connect(func(): AudioManager.back(); _finish())
	%TimingBar.idle_alpha = 0.4
	%TimingBar.modulate.a = 0.4
	$Helper.visible = false
	var t := create_tween().set_loops()
	t.tween_property($Helper/Glow, "scale", Vector2(0.62, 0.62), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property($Helper/Glow, "scale", Vector2(0.48, 0.48), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_field.passed.connect(_on_passed)
	_intro()

## The story beat before the drill: who the team is and why Kuro bothers.
## A tap (or four seconds) moves on to step one.
func _intro() -> void:
	_in_intro = true
	step = -1
	%L1.text = str(Story.yard("cricket").get("intro", ""))
	%L1.add_theme_font_size_override("font_size", 27)
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.4)
	%Step.text = "THE YARD  ·  TAP TO BEGIN"
	for d in %Dots.get_children():
		d.color = Globals.LINE2
	await get_tree().create_timer(4.0).timeout
	dismiss_intro()

func dismiss_intro() -> void:
	if not _in_intro or _done:
		return
	_in_intro = false
	%L1.add_theme_font_size_override("font_size", 38)
	_set_step(0)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, 30)
	var r := Globals.view_rect()
	_field.layout(r)
	%TimingBar.custom_minimum_size = Vector2(clampf(r.size.x * 0.4, 360.0, 560.0), 22)
	_place_helper()

func _process(delta: float) -> void:
	if _done:
		return
	if _field.ball_in_flight:
		_field.tick(delta)
		if _field.ball_in_flight:
			%TimingBar.set_progress(_field.ball.t)
	elif _bowl_in > 0.0:
		_bowl_in -= delta
		if _bowl_in <= 0.0:
			_bowl()
	if step == 2 and $Helper.visible:
		# The helper sits on the timing bar (the HUD layer shares world coordinates).
		$Helper.position = %TimingBar.global_position + %TimingBar.size * 0.5

func _set_step(i: int) -> void:
	step = i
	%L1.text = STEPS[i]
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.3)
	%Step.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	for j in %Dots.get_child_count():
		var d: ColorRect = %Dots.get_child(j)
		d.color = Globals.GREEN if j == i else Globals.LINE2
	if i < 3:
		var f: Array = FIELDERS[i]
		if f.is_empty():
			_field.clear_fielders()
		else:
			_field.set_fielders(f)
		_place_helper()
		_bowl_in = 1.0
		return
	$Helper.visible = false
	_field.clear_fielders()
	await get_tree().create_timer(1.4).timeout
	if not _done:
		_finish()

func _place_helper() -> void:
	match step:
		0:
			$Helper.position = _field.crease_point()
			$Helper.visible = true
		1:
			$Helper.position = _field.zone_point(HELPER_GAP_ZONE, 0.5)
			$Helper.visible = true
		2:
			$Helper.position = %TimingBar.global_position + %TimingBar.size * 0.5
			$Helper.visible = true
		_:
			$Helper.visible = false

func _bowl() -> void:
	if _done or step < 0 or step > 2:
		return
	var travel: float = TRAVEL[step]
	_field.bowl(travel, 0.0, 0.0)
	_swung = false
	%TimingBar.set_ball(travel, CricketRules.PASS_GRACE, WINDOW_SCALE)
	AudioManager.play_sfx("bowl", 1.0, -4.0)

## The ball went by: show what happens and bowl again.
func _on_passed() -> void:
	var on: bool = _field.line_on_stumps()
	_field.pass_ball(on)
	%TimingBar.clear()
	var at: Vector2 = _field.crease_point() + Vector2(0, -34)
	if on:
		AudioManager.play_sfx("wicket", 1.0, -6.0)
		AudioManager.vibrate(30)
		_field.fx.popup("BOWLED!", at, Globals.RED, 26)
	else:
		AudioManager.play_sfx("near_miss", 0.8, -8.0)
		_field.fx.popup("DOT", at, Globals.DIM, 22)
	_flash_text()
	_bowl_in = 1.5

# ---------------------------------------------------------------- public API

func time_to_arrival() -> float:
	return _field.time_to_arrival()

func gap_zones() -> Array:
	return _field.gap_zones()

func zone_center_x(zone: int) -> float:
	var r := Globals.view_rect()
	return r.position.x + r.size.x * 0.5 + CricketRules.zone_fraction(zone) * r.size.x * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if _in_intro and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		dismiss_intro()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(event.position)
	elif event is InputEventScreenTouch and event.pressed and event.index > 0:
		tap_at(event.position)

func tap_at(global_pos: Vector2) -> void:
	if _done or not _field.ball_in_flight or _swung:
		return
	_swung = true
	var r := Globals.view_rect()
	var zone := CricketRules.zone_for_x(global_pos.x - (r.position.x + r.size.x * 0.5), r.size.x * 0.5)
	_field.swing(zone)
	var b: Node2D = _field.ball
	var g := "miss"
	if b.t >= b.travel * CricketRules.EARLY_FRACTION:
		g = CricketRules.grade(absf(b.t - b.travel), WINDOW_SCALE)
	if g == "miss":
		AudioManager.play_sfx("whoosh", 1.7, -12.0)
		return
	var out := CricketRules.outcome(g, _field.gap_zones().has(zone), b.on_stumps())
	var kind := str(out.kind)
	_field.contact(kind, zone)
	%TimingBar.clear()
	runs += int(out.runs)
	var at: Vector2 = _field.crease_point() + Vector2(0, -34)
	AudioManager.play_sfx("bat_hit", 1.3 if kind == "six" else 1.0)
	AudioManager.vibrate(15)
	if kind == "six":
		AudioManager.play_sfx("six", 1.0, -3.0)
		AudioManager.vibrate(40)
	if int(out.runs) > 0:
		_field.fx.popup("+%d  %s" % [int(out.runs), str(out.label)], at, CricketRules.color_for(kind), 28)
	else:
		_field.fx.popup(str(out.label), at, CricketRules.color_for(kind), 26)
	var advance := true
	if step == 1:
		advance = int(out.runs) > 0
	if not advance:
		_flash_text()
		_bowl_in = 1.5
		return
	$Helper.visible = false
	var s := step
	await get_tree().create_timer(1.3).timeout
	if not _done and step == s:
		_set_step(s + 1)

func _flash_text() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(%L1, "modulate", Color(1, 0.45, 0.55, 1), 0.08)
	_flash_tween.tween_property(%L1, "modulate", Color.WHITE, 0.3)

func _finish() -> void:
	if _done:
		return
	_done = true
	SaveData.set_tutorial_done("cricket")
	Globals.go("cricket_play")
