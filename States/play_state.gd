extends Node2D
## Knife Dodge: survive escalating dagger formations. One hit ends the run.

const WAVE_NAMES := {"interval": "VOLLEY", "spray": "CROSSFIRE", "circle": "RING", "teeth": "TEETH"}
const WAVE_COLORS := {"interval": Color("5afaff"), "spray": Color("ff3b5c"), "circle": Color("ff4fd8"), "teeth": Color("e5ec45")}
const NEAR_MISS_POINTS := 5
const STREAK_WINDOW := 2.5

var stages := [
	{"type": "interval", "params": {"intervals": [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7]}, "wait": 10},
	{"type": "spray", "params": {}, "wait": 0.5, "repeat": 5},
	{"type": "circle", "params": {"num_knives": 8, "radius": 400}, "wait": 3, "repeat": 3},
	{"type": "teeth", "params": {"num_knives": 5}, "wait": 5},
	{"type": "interval", "params": {"intervals": [1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 7, 7]}, "wait": 10},
	{"type": "spray", "params": {}, "wait": 0.5, "repeat": 10},
	{"type": "circle", "params": {"num_knives": 10, "radius": 350}, "wait": 3, "repeat": 5},
	{"type": "teeth", "params": {"num_knives": 10}, "wait": 5},
	{"type": "spray", "params": {}, "wait": 0.5, "repeat": 15},
	{"type": "circle", "params": {"num_knives": 10, "radius": 300}, "wait": 3, "repeat": 7},
	{"type": "teeth", "params": {"num_knives": 20}, "wait": 5},
	{"type": "spray", "params": {}, "wait": 0.5, "repeat": 20},
	{"type": "teeth", "params": {"num_knives": 30}, "wait": 5},
]

var score := 0
var dodged := 0
var near_misses := 0
var wave := 0
var waves_started := 0
var repeat := 1
var cycle := 0
var elapsed := 0.0
var streak := 0
var streak_timer := 0.0
var dead := false
var paused := false
var revived_this_run := false
var _shake := 0.0
var _offer: OfferOverlay

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	add_to_group("playstate")
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	AudioManager.play_music("knife")
	%Player.position = Globals.view_center() + Vector2(0, -100)
	$HUD.set_best(int(SaveData.knife_stats().best))
	$HUD.set_score(0)
	$HUD.pause_pressed.connect(toggle_pause)
	$Pause.resume.connect(toggle_pause)
	$Pause.restart.connect(func(): Globals.go("play"))
	$Pause.menu.connect(func(): Globals.go("start"))
	$Spawn.start()

func _process(delta: float) -> void:
	if dead:
		return
	elapsed += delta
	$HUD.set_time(elapsed)
	$HUD.set_progress(1.0 - $Spawn.time_left / maxf(0.01, $Spawn.wait_time))
	if streak > 0:
		streak_timer -= delta
		if streak_timer <= 0:
			streak = 0
			$HUD.set_streak(0)
	_bounds()
	if _shake > 0:
		_shake = maxf(0, _shake - delta * 2.5)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

func _bounds() -> void:
	var r := Globals.view_rect()
	var p: CharacterBody2D = %Player
	if p.invulnerable and p.position.y >= r.end.y - 20:
		# Second-wind grace: a soft floor instead of falling out of the void.
		p.position.y = r.end.y - 20
		p.velocity.y = -absf(p.velocity.y) * 0.5
	elif p.position.y >= r.end.y + 24:
		game_over()
		return
	if p.position.y <= r.position.y:
		p.position.y = r.position.y
		p.velocity.y = absf(p.velocity.y)
	if p.position.x >= r.end.x - 10:
		p.position.x = r.end.x - 10
		p.velocity.x = -absf(p.velocity.x)
	if p.position.x <= r.position.x + 10:
		p.position.x = r.position.x + 10
		p.velocity.x = absf(p.velocity.x)

func _on_spawn_timeout() -> void:
	if dead:
		return
	var stage: Dictionary = stages[wave]
	if repeat == 1:
		waves_started += 1
		$HUD.show_wave(waves_started, WAVE_NAMES.get(stage.type, "WAVE"), WAVE_COLORS.get(stage.type, Globals.CYAN))
		AudioManager.play_sfx("wave_start", 1.0 + cycle * 0.05, -8.0)
	$Spawner.spawn(stage)
	var wait_scale := pow(0.9, cycle)
	$Spawn.wait_time = maxf(0.3, float(stage.wait) * wait_scale)
	if stage.has("repeat") and int(stage.repeat) > repeat:
		repeat += 1
	else:
		if repeat > 1:
			$Spawn.wait_time = 2.0 * wait_scale
			repeat = 1
		wave = (wave + 1) % stages.size()
		if wave == 0:
			cycle += 1
			$Spawner.speed_mult = 1.0 + 0.12 * cycle
	$Spawn.start()

func increment_score() -> void:
	if dead:
		return
	dodged += 1
	_add_score(1)
	AudioManager.play_sfx("dodge_tick", randf_range(0.9, 1.15), -14.0)

func near_miss(at: Vector2) -> void:
	if dead:
		return
	near_misses += 1
	streak += 1
	streak_timer = STREAK_WINDOW
	var pts := NEAR_MISS_POINTS * streak
	_add_score(pts)
	$HUD.set_streak(streak)
	$HUD.popup("NEAR MISS +%d" % pts, at, Globals.GREEN)
	AudioManager.play_sfx("near_miss", 1.0 + minf(streak, 8) * 0.06, -4.0)
	AudioManager.vibrate(15)

func _add_score(n: int) -> void:
	score += n
	$HUD.set_score(score)

func game_over() -> void:
	if dead or %Player.invulnerable:
		return
	dead = true
	%Player.die()
	$DeathFX.position = %Player.position
	$DeathFX.emitting = true
	$FlashLayer/Flash.color = Color(1, 1, 1, 0.55)
	create_tween().tween_property($FlashLayer/Flash, "color:a", 0.0, 0.4)
	_shake = 1.0
	AudioManager.play_sfx("hit")
	AudioManager.vibrate(80)
	for k in %Knives.get_children():
		k.can_move = false
	$Spawn.stop()
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	# One second wind per run: spend a revive booster or watch an ad.
	if not revived_this_run and (SaveData.booster_count("revive") > 0 or Ads.available("revive")):
		get_tree().paused = true
		_offer = OfferOverlay.open(get_tree(), "revive")
		var ok: bool = await _offer.finished
		_offer = null
		if not is_inside_tree():
			return
		if ok:
			_revive()
			return
		get_tree().paused = false
	Globals.go("lose", {"score": score, "wave": waves_started, "time": elapsed, "near": near_misses, "dodged": dodged})

func _revive() -> void:
	revived_this_run = true
	dead = false
	for k in %Knives.get_children():
		%Knives.remove_child(k)
		k.queue_free()
	get_tree().paused = false
	%Player.revive()
	streak = 0
	$HUD.set_streak(0)
	$Spawn.wait_time = 2.0
	$Spawn.start(2.0)
	$HUD.show_wave(waves_started, "SECOND WIND", Globals.GOLD)
	AudioManager.play_sfx("wave_start", 1.25, -6.0)

## Leaving the screen while the revive dialog is up (menu, restart, debug
## tour) must not leave that dialog floating over the next screen.
func _exit_tree() -> void:
	if is_instance_valid(_offer):
		_offer.queue_free()
		_offer = null

func toggle_pause() -> void:
	if dead:
		return
	paused = not paused
	get_tree().paused = paused
	$Pause.set_open(paused)
	AudioManager.click()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not paused and not dead and is_inside_tree() and elapsed > 0.5:
			toggle_pause()
