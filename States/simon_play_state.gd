extends Node2D
## Sensei Says: watch the pads light up, then play the pattern back. Every
## round appends one pad. A wrong tap, or six idle seconds on your turn, ends
## the game unless the player spends an extra life (offered once per game).

const SIDE_WIDTH := 540.0
const MARGIN := 34
const IDLE_LIMIT := 6.0
const GAP := 0.12
const TAP_LIGHT := 0.32
const QUIPS := [
	"Sensei Kuro: \"The pattern was there. Your mind wandered.\"",
	"Sensei Kuro: \"Watch with the eyes. Answer with the hands.\"",
	"Sensei Kuro: \"Nine pads. One path. Walk it again.\"",
	"Sensei Kuro: \"A calm mind holds many colours.\"",
	"Sensei Kuro: \"You blinked. The sequence did not.\"",
	"Sensei Kuro: \"Good. Tomorrow, one pad more.\"",
]
const WATCH_SUBS := ["Sensei shows the pattern", "Eyes on the pads", "Memorise the order", "Breathe. Watch."]

var sequence: Array[int] = []
var round: int = 0
var rounds_completed: int = 0
var phase: String = "between"   # watch / input / between / over
var longest_sequence := 0
var taps := 0
var correct_taps := 0
var elapsed := 0.0
var paused := false

var _progress := 0        # next index in `sequence` the player must tap
var _idle := 0.0
var _life_offered := false
var _offering := false
var _gen := 0             # bumps whenever a new flow starts; stale coroutines bail
var _best := 0
var _rng := RandomNumberGenerator.new()
var _status_tween: Tween

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("match")
	_rng.randomize()
	Globals.apply_safe_margins(%Root, MARGIN)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Grid.pad_tapped.connect(press_pad)
	%PauseBtn.pressed.connect(toggle_pause)
	$Pause.set_title("PAUSED", "Sensei waits.", Globals.VIOLET)
	$Pause.resume.connect(toggle_pause)
	$Pause.restart.connect(func(): Globals.go("simon_play"))
	$Pause.menu.connect(func(): Globals.go("start"))
	SaveData.boosters_changed.connect(_update_lives)
	_best = int(SaveData.game_stats("simon").best)
	_update_lives()
	_update_hud()
	_start_round()

func _layout() -> void:
	Globals.apply_safe_margins(%Root, MARGIN)
	var r := Globals.view_rect()
	var ins := Globals.safe_insets()
	var avail_h: float = r.size.y - 2 * MARGIN - float(ins.top) - float(ins.bottom)
	var avail_w: float = r.size.x - 2 * MARGIN - float(ins.left) - float(ins.right) - SIDE_WIDTH - 40
	var side := floorf(minf(avail_h, avail_w))
	%BoardPanel.custom_minimum_size = Vector2(side, side)

# ------------------------------------------------------------------ rounds

func _start_round() -> void:
	round += 1
	sequence.append(_rng.randi_range(0, SimonPadGrid.COUNT - 1))
	longest_sequence = maxi(longest_sequence, sequence.size())
	_update_hud()
	_playback(0.9 if round == 1 else 0.35)

## Show the whole sequence, then hand control to the player.
func _playback(lead_in: float) -> void:
	var gen := _new_flow()
	phase = "watch"
	%Grid.input_enabled = false
	_set_status("WATCH", WATCH_SUBS[_rng.randi_range(0, WATCH_SUBS.size() - 1)], Globals.VIOLET)
	AudioManager.play_sfx("simon_watch")
	await _sleep(lead_in)
	if gen != _gen:
		return
	var interval := maxf(0.28, 0.62 - 0.025 * round)
	for i in sequence:
		%Grid.light(i, interval)
		await _sleep(interval + GAP)
		if gen != _gen:
			return
	phase = "input"
	_progress = 0
	_idle = 0.0
	%Grid.input_enabled = true
	_set_status("YOUR TURN", "Tap the pads in the same order", Globals.GREEN)

## The same path a real tap takes (pads route their gui_input here).
func press_pad(index: int) -> void:
	if phase != "input" or paused or index < 0 or index >= SimonPadGrid.COUNT:
		return
	taps += 1
	_idle = 0.0
	if index == sequence[_progress]:
		correct_taps += 1
		_progress += 1
		%Grid.light(index, TAP_LIGHT)
		if _progress >= sequence.size():
			_round_complete()
		else:
			%StatusSub.text = "%d OF %d" % [_progress, sequence.size()]
	else:
		_fail(index)

func _round_complete() -> void:
	var gen := _new_flow()
	phase = "between"
	%Grid.input_enabled = false
	rounds_completed += 1
	AudioManager.play_sfx("simon_round")
	AudioManager.vibrate(20)
	_set_status("PERFECT", "ROUND %d CLEARED" % round, Globals.GOLD)
	_update_hud()
	await _sleep(0.8)
	if gen != _gen:
		return
	_start_round()

## `index` is the wrong pad, or -1 when the player idled too long.
func _fail(index: int) -> void:
	var gen := _new_flow()
	phase = "between"
	%Grid.input_enabled = false
	AudioManager.play_sfx("simon_fail")
	AudioManager.vibrate(60)
	%Grid.shake()
	%Grid.flash_wrong(index if index >= 0 else sequence[_progress])
	if index >= 0:
		_set_status("WRONG PAD", "That was not the pattern", Globals.RED)
	else:
		_set_status("TOO SLOW", "The pattern faded", Globals.RED)
	await _sleep(0.9)
	if gen != _gen:
		return
	if not _life_offered and (SaveData.booster_count("life") > 0 or Ads.available("life")):
		_life_offered = true
		_offering = true
		_update_lives()
		var o := OfferOverlay.open(get_tree(), "life")
		var ok: bool = await o.finished
		_offering = false
		if gen != _gen or not is_inside_tree():
			return
		if ok:
			_update_lives()
			_set_status("SECOND CHANCE", "Watch the pattern once more", Globals.VIOLET)
			await _sleep(0.6)
			if gen != _gen:
				return
			_playback(0.3)
			return
	_game_over()

func _game_over() -> void:
	var gen := _new_flow()
	phase = "over"
	%Grid.input_enabled = false
	_set_status("GAME OVER", "Sensei bows", Globals.MUTED)
	await _sleep(1.0)
	if gen != _gen:
		return
	var accuracy := 100 if taps == 0 else int(100.0 * float(correct_taps) / float(taps) + 0.5)
	var title := "THE SENSEI NODS"
	if rounds_completed >= 15:
		title = "PHOTOGRAPHIC"
	elif rounds_completed >= 10:
		title = "SHARP MIND"
	elif rounds_completed >= 5:
		title = "GOOD MEMORY"
	Globals.go("arcade_result", {
		"game": "simon", "score": rounds_completed, "time": elapsed, "title": title,
		"detail": "%d PADS  ·  %s" % [longest_sequence, Globals.format_time(elapsed)],
		"stats": [
			[str(rounds_completed), "ROUNDS", Globals.VIOLET],
			[str(taps), "TAPS", Globals.TEXT],
			["%d%%" % accuracy, "ACCURACY", Globals.GREEN],
			[Globals.format_time(elapsed), "TIME", Globals.TEXT],
		],
		"quip": QUIPS[_rng.randi_range(0, QUIPS.size() - 1)],
	})

func _process(delta: float) -> void:
	if phase == "over" or paused or _offering:
		return
	elapsed += delta
	if phase == "input":
		_idle += delta
		%IdleBar.value = 100.0 * clampf(1.0 - _idle / IDLE_LIMIT, 0.0, 1.0)
		if _idle >= IDLE_LIMIT:
			_fail(-1)

# ------------------------------------------------------------------ hud

func _set_status(text: String, sub: String, color: Color) -> void:
	%StatusLabel.text = text
	%StatusLabel.add_theme_color_override("font_color", color)
	%StatusSub.text = sub
	var sb: StyleBoxFlat = %StatusPanel.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(color, 0.45)
	sb.bg_color = Color(color, 0.08)
	%StatusPanel.add_theme_stylebox_override("panel", sb)
	%IdleBar.visible = phase == "input"
	%IdleBar.value = 100.0
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	%StatusPanel.pivot_offset = %StatusPanel.size * 0.5
	%StatusPanel.scale = Vector2(0.96, 0.96)
	_status_tween = create_tween()
	_status_tween.tween_property(%StatusPanel, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _update_hud() -> void:
	%RoundLabel.text = "ROUND %d" % maxi(round, 1)
	%SeqVal.text = str(sequence.size())
	if rounds_completed > _best:
		%BestVal.text = str(rounds_completed)
		%BestVal.add_theme_color_override("font_color", Globals.GOLD)
		%BestCaps.text = "NEW BEST"
	else:
		%BestVal.text = str(_best)

func _update_lives() -> void:
	var n := SaveData.booster_count("life")
	%LifeVal.text = str(n)
	%LifeIcon.modulate = Globals.VIOLET if n > 0 else Globals.LINE2
	%LifeNote.text = "RETRY USED" if _life_offered else "ONE RETRY PER GAME"

# ------------------------------------------------------------------ pause

func toggle_pause() -> void:
	if phase == "over" or _offering:
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
		if not paused and phase != "over" and not _offering and is_inside_tree():
			toggle_pause()

# ------------------------------------------------------------------ helpers

## Node-bound pause: it pauses with the tree and dies with this state, so a
## restart or exit mid-sequence never resumes a freed coroutine.
func _sleep(sec: float) -> void:
	var t := create_tween()
	t.tween_interval(sec)
	await t.finished

func _new_flow() -> int:
	_gen += 1
	return _gen
