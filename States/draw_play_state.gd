extends Node2D
## Quick Draw: tap the shuriken targets before their rings close, never tap
## the red decoy daggers. Three misses end the round (one extra life can be
## bought back once with a booster or a rewarded ad).

const TARGET_SCENE: PackedScene = preload("res://draw/target.tscn")
const MARGIN := 28
const EDGE := 120.0              # play-area inset on every side
const HUD_EXTRA := 100.0         # extra inset at the top for the HUD
const START_LIVES := 3
const COLORS: Array[Color] = [Globals.CYAN, Globals.MAGENTA, Globals.GOLD, Globals.GREEN, Globals.VIOLET]

var lives := START_LIVES
var score := 0
var hits := 0
var misses := 0
var combo := 0
var best_combo := 0
var decoy_taps := 0
var elapsed := 0.0
var ended := false
var paused := false

var _offering := false
var _offer_used := false
var _spawn_in := 2.0             # first target only after the opening toast fades
var _miss_grace := 0.0           # one lapse costs one life, not three
var _area := Rect2(0, 0, Globals.BASE_WIDTH, Globals.BASE_HEIGHT)
var _shake := 0.0
var _last_color := -1
var _pill_tween: Tween
var _flash_tween: Tween
var _toast_tween: Tween
var _score_tween: Tween

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
	$Pause.set_title("PAUSED", "The targets wait.", Globals.ORANGE)
	$Pause.resume.connect(toggle_pause)
	$Pause.restart.connect(func(): Globals.go("draw_play"))
	$Pause.menu.connect(func(): Globals.go("start"))
	%BestVal.text = str(SaveData.best_for("draw"))
	# Own copy of the vignette material: a flash cut short by a state change
	# must not leave the shared resource tinted for the next round.
	%Flash.material = %Flash.material.duplicate()
	%Flash.material.set_shader_parameter("strength", 0.0)
	%ComboPill.modulate.a = 0.0
	%Toast.modulate.a = 0.0
	_update_score(true)
	_update_lives(true)
	_toast("HIT THE TARGETS. SKIP THE DECOYS.", 1.5)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, MARGIN)
	var r := Globals.view_rect()
	var ins := Globals.safe_insets()
	var left: float = r.position.x + EDGE + float(ins.left)
	var top: float = r.position.y + EDGE + HUD_EXTRA + float(ins.top)
	var right: float = r.end.x - EDGE - float(ins.right)
	var bottom: float = r.end.y - EDGE - float(ins.bottom)
	_area = Rect2(left, top, maxf(120.0, right - left), maxf(120.0, bottom - top))

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if ended or paused or _offering:
		return
	elapsed += delta
	%TimeVal.text = Globals.format_time(elapsed)
	_miss_grace = maxf(0.0, _miss_grace - delta)
	for t in alive_targets():
		t.tick(delta)
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = _spawn()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 12.0
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

## Seconds a target stays open: 1.6 s at first, 0.03 s less per hit, floor 0.55 s.
func target_lifetime() -> float:
	return maxf(0.55, 1.6 - 0.03 * hits)

## Seconds between spawns: 1.1 s at first down to 0.45 s.
func spawn_interval() -> float:
	return maxf(0.45, 1.1 - 0.025 * hits)

func max_alive() -> int:
	if hits >= 25:
		return 3
	if hits >= 10:
		return 2
	return 1

## Live target nodes (shurikens and decoys). Each has `global_position` and `is_decoy`.
func alive_targets() -> Array:
	var out := []
	for t in %Targets.get_children():
		if t.alive:
			out.append(t)
	return out

## Spawns something if there is room; returns the delay until the next attempt.
func _spawn() -> float:
	var real := 0
	var decoys := 0
	for t in alive_targets():
		if t.is_decoy:
			decoys += 1
		else:
			real += 1
	if real >= max_alive():
		return 0.12
	# Roll the decoy once per real spawn opportunity, never on retry ticks.
	if hits >= 8 and decoys == 0 and randf() < 0.2:
		_spawn_decoy()
		return minf(spawn_interval(), 0.5)
	_spawn_target()
	return spawn_interval()

func _spawn_target() -> void:
	var t: DrawTarget = TARGET_SCENE.instantiate()
	t.lifetime = target_lifetime()
	t.color = _next_color()
	t.spin = randf_range(-1.4, 1.4)
	t.position = _free_spot()
	t.expired.connect(_on_expired)
	%Targets.add_child(t)
	AudioManager.play_sfx("target_spawn", randf_range(0.95, 1.1), -10.0)

func _spawn_decoy() -> void:
	var t: DrawTarget = TARGET_SCENE.instantiate()
	t.is_decoy = true
	t.lifetime = 1.2
	var dir := Vector2.from_angle(randf_range(-0.6, 0.6)) * (1.0 if randf() < 0.5 else -1.0)
	t.drift = dir * 75.0
	t.position = _free_spot() - dir * 45.0
	%Targets.add_child(t)
	AudioManager.play_sfx("target_spawn", 0.72, -12.0)

func _next_color() -> Color:
	var i := randi() % COLORS.size()
	if i == _last_color:
		i = (i + 1 + randi() % (COLORS.size() - 1)) % COLORS.size()
	_last_color = i
	return COLORS[i]

## A random point in the play area away from the live targets.
func _free_spot() -> Vector2:
	var live := alive_targets()
	var best := _area.get_center()
	var best_d := -1.0
	for i in 16:
		var p := Vector2(randf_range(_area.position.x, _area.end.x), randf_range(_area.position.y, _area.end.y))
		var d := INF
		for t in live:
			d = minf(d, t.position.distance_to(p))
		if d >= 190.0:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best

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

## A tap at a canvas position: hits the nearest target within its tap radius.
func tap_at(global_pos: Vector2) -> void:
	if ended or paused or _offering:
		return
	var best: DrawTarget = null
	var best_d := INF
	for t in alive_targets():
		var d: float = t.global_position.distance_to(global_pos)
		if d <= t.tap_radius() and d < best_d:
			best = t
			best_d = d
	if best == null:
		$FX.ring($FX.to_local(global_pos), Globals.DIM, 0.45)
		return
	if best.is_decoy:
		_on_decoy_tapped(best)
	else:
		_on_hit(best)

# ---------------------------------------------------------------- scoring

func _on_hit(t: DrawTarget) -> void:
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	var pts := 1 + floori(combo / 5.0)
	score += pts
	var at: Vector2 = $FX.to_local(t.global_position)
	AudioManager.play_sfx("target_hit", 1.0 + minf(float(combo), 24.0) * 0.025)
	AudioManager.vibrate(10)
	$FX.burst(at, t.color, 9, 110.0)
	$FX.ring(at, t.color, 1.1)
	$FX.popup("+%d" % pts, at, Globals.GOLD if pts > 1 else t.color)
	t.pop()
	_update_score()
	var milestone := combo >= 5 and combo % 5 == 0
	_update_combo(milestone)
	if milestone:
		AudioManager.play_sfx("combo_up", 1.0 + minf(combo / 5.0 - 1.0, 6.0) * 0.08)
		AudioManager.vibrate(20)

func _on_expired(t: DrawTarget) -> void:
	if ended or _offering:
		return
	if _miss_grace > 0.0:
		t.fade_out()
		return
	_miss_grace = 0.5
	misses += 1
	var at: Vector2 = $FX.to_local(t.global_position)
	$FX.popup("MISS", at, Globals.RED, 22)
	t.miss_out()
	AudioManager.play_sfx("target_miss")
	AudioManager.vibrate(30)
	_flash(0.5)
	_lose_life()

func _on_decoy_tapped(t: DrawTarget) -> void:
	misses += 1
	decoy_taps += 1
	var at: Vector2 = $FX.to_local(t.global_position)
	$FX.burst(at, Globals.RED, 10, 120.0)
	$FX.popup("DECOY!", at, Globals.RED, 24)
	t.pop()
	AudioManager.play_sfx("decoy_hit")
	AudioManager.vibrate(60)
	_shake = 1.0
	_flash(0.7)
	_lose_life()

func _lose_life() -> void:
	if ended or _offering or lives <= 0:
		return
	combo = 0
	_update_combo(false)
	lives -= 1
	_update_lives()
	if lives <= 0:
		_out_of_lives()

## Expire every live shuriken as a miss (decoys just leave). Used by tests.
func force_expire_all() -> void:
	for t in alive_targets():
		if ended or _offering or lives <= 0:
			break
		if t.is_decoy:
			t.fade_out()
		else:
			t.alive = false
			_on_expired(t)

func _clear_targets() -> void:
	for t in alive_targets():
		t.fade_out()

func _out_of_lives() -> void:
	if ended:
		return
	if not _offer_used and (SaveData.booster_count("life") > 0 or Ads.available("life")):
		_offer_used = true
		_offering = true
		_clear_targets()
		await get_tree().create_timer(0.4).timeout
		if ended or not is_inside_tree():
			return
		var o := OfferOverlay.open(get_tree(), "life")
		var ok: bool = await o.finished
		if not is_inside_tree():
			return
		_offering = false
		if ok:
			lives = 1
			_update_lives()
			_spawn_in = 1.6
			_toast("ONE MORE LIFE", 1.3)
			return
	_end()

func _end() -> void:
	if ended:
		return
	ended = true
	_offering = false
	_clear_targets()
	AudioManager.play_sfx("level_fail", 1.0, -6.0)
	_toast("ROUND OVER", 1.2)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	Globals.go("arcade_result", {
		"game": "draw", "score": score, "time": elapsed, "title": _title(),
		"detail": "COMBO x%d" % best_combo,
		"stats": [
			[str(hits), "HITS", Globals.TEXT], [str(misses), "MISSES", Globals.RED],
			["x%d" % best_combo, "BEST COMBO", Globals.GOLD], [Globals.format_time(elapsed), "TIME", Globals.TEXT],
		],
		"quip": _quip(),
	})

## Headline from the same milestone table the leaderboard uses.
func _title() -> String:
	var title := "WARMING UP"
	for m in Globals.game("draw").get("milestones", []):
		if score >= int(m[0]):
			title = str(m[1])
	return title

func _quip() -> String:
	var lines := []
	if hits >= 8 and decoy_taps == 0:
		lines.append("Pip: \"Those decoys never saw you coming!\"")
	if decoy_taps >= 2:
		lines.append("Pip: \"Red daggers, remember? Red means no.\"")
	if best_combo >= 10:
		lines.append("Pip: \"That combo had me seeing stars. More stars.\"")
	if score >= 100:
		lines.append("Pip: \"Blink and you'd miss it. You didn't blink.\"")
	if score < 20:
		lines.append("Pip: \"Warm-up's over. The rings get faster from here.\"")
	lines.append("Pip: \"Rings close, hands fly. Nice reflexes!\"")
	lines.append("Pip: \"Quick hands, quicker eyes. Go again?\"")
	return lines[randi() % lines.size()]

# ---------------------------------------------------------------- HUD

func _update_score(instant: bool = false) -> void:
	%Score.text = Globals.pad_score(score)
	if instant:
		return
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	%Score.pivot_offset = Vector2(0, %Score.size.y * 0.5)
	%Score.scale = Vector2(1.08, 1.08)
	_score_tween = create_tween()
	_score_tween.tween_property(%Score, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)

func _update_combo(milestone: bool) -> void:
	var show := combo >= 2
	%ComboVal.text = "x%d" % combo
	%ComboRate.text = "+%d PER HIT" % (1 + floori(combo / 5.0))
	if _pill_tween and _pill_tween.is_valid():
		_pill_tween.kill()
	_pill_tween = create_tween()
	if not show:
		_pill_tween.tween_property(%ComboPill, "modulate:a", 0.0, 0.25)
		return
	%ComboPill.modulate.a = 1.0
	%ComboPill.pivot_offset = %ComboPill.size * 0.5
	if milestone:
		%ComboPill.scale = Vector2(1.28, 1.28)
		_pill_tween.tween_property(%ComboPill, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		%ComboPill.scale = Vector2(1.06, 1.06)
		_pill_tween.tween_property(%ComboPill, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)

func _update_lives(instant: bool = false) -> void:
	var icons := [%Life1, %Life2, %Life3]
	for i in icons.size():
		var icon: TextureRect = icons[i]
		var lit := i < lives
		var col: Color = Globals.GOLD if lit else Globals.LINE2
		if instant or icon.modulate == col:
			icon.modulate = col
			continue
		icon.pivot_offset = icon.size * 0.5
		icon.scale = Vector2(1.7, 1.7) if lit else Vector2(1.5, 1.5)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(icon, "modulate", col, 0.3)
		t.tween_property(icon, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _flash(strength: float) -> void:
	var mat: ShaderMaterial = %Flash.material
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
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
		if not paused and not ended and not _offering and is_inside_tree() and elapsed > 0.5:
			toggle_pause()
