extends Node2D
## Shuriken Match: reach the target score within the move limit.

const SIDE_WIDTH := 540.0
const MARGIN := 34

var level := 1
var params := {}
var moves_left := 0
var score := 0
var ended := false
var paused := false
var _shown_score := 0.0
var _score_tween: Tween
var _stars_lit := 0
var _combo_tween: Tween

func init(p: Dictionary) -> void:
	level = int(p.get("level", 1))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("match")
	params = MatchLevels.params(level)
	moves_left = int(params.moves)
	Globals.apply_safe_margins(%Root, MARGIN)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var model := BoardModel.new(8, 8, int(params.colors))
	model.fill_random()
	%Board.setup(model)
	%Board.move_made.connect(_on_move)
	%Board.board_settled.connect(_on_settled)
	%Board.tiles_cleared.connect(_on_cleared)
	%Board.special_created.connect(_on_special_created)
	%Board.special_fired.connect(_on_special_fired)
	%Board.shuffled.connect(func(): _toast("NO MOVES LEFT. RESHUFFLING."))
	%PauseBtn.pressed.connect(toggle_pause)
	$Pause.set_title("PAUSED", "The shurikens hold still.", Globals.MAGENTA)
	$Pause.resume.connect(toggle_pause)
	$Pause.restart.connect(func(): Globals.go("match_play", {"level": level}))
	$Pause.menu.connect(func(): Globals.go("match_levels"))
	%LevelLabel.text = "LEVEL %d" % level
	%TargetVal.text = Globals.format_number(int(params.target))
	_place_stars()
	%ComboBanner.modulate.a = 0.0
	%Toast.modulate.a = 0.0
	_update_hud(true)
	_toast("REACH %s IN %d MOVES" % [Globals.format_number(int(params.target)), moves_left], 2.2)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, MARGIN)
	var r := Globals.view_rect()
	var ins := Globals.safe_insets()
	var avail_h: float = r.size.y - 2 * MARGIN - float(ins.top) - float(ins.bottom)
	var avail_w: float = r.size.x - 2 * MARGIN - float(ins.left) - float(ins.right) - SIDE_WIDTH - 40
	var side := floorf(minf(avail_h, avail_w))
	%BoardPanel.custom_minimum_size = Vector2(side, side)
	%Legend.visible = avail_h >= 700

func _place_stars() -> void:
	var top: float = float(params.stars[2])
	var i := 0
	for star in [%Star1, %Star2, %Star3]:
		var f: float = float(params.stars[i]) / top
		star.anchor_left = f
		star.anchor_right = f
		star.offset_left = -17
		star.offset_right = 17
		star.modulate = Globals.LINE2
		i += 1

func _update_hud(instant: bool = false) -> void:
	%MovesVal.text = str(moves_left)
	if moves_left <= 3:
		%MovesVal.add_theme_color_override("font_color", Globals.RED if moves_left <= 1 else Globals.ORANGE)
	if instant:
		_shown_score = score
		%ScoreVal.text = Globals.format_number(score)
	else:
		if _score_tween and _score_tween.is_valid():
			_score_tween.kill()
		_score_tween = create_tween()
		_score_tween.tween_method(func(v: float): _shown_score = v; %ScoreVal.text = Globals.format_number(int(v)), _shown_score, float(score), 0.5)
	var top: float = float(params.stars[2])
	var t := create_tween()
	t.tween_property(%TargetBar, "value", clampf(score / top, 0.0, 1.0) * 100.0, 0.5).set_ease(Tween.EASE_OUT)
	var stars := MatchLevels.stars_for(level, score)
	%StarsCaption.text = "%d OF 3 STARS" % stars
	var remaining := int(params.target) - score
	%ToGo.text = ("%s TO GO" % Globals.format_number(remaining)) if remaining > 0 else "TARGET REACHED"
	if remaining <= 0:
		%ToGo.add_theme_color_override("font_color", Globals.GREEN)
	var star_nodes := [%Star1, %Star2, %Star3]
	for i in 3:
		if stars > i and _stars_lit <= i:
			_stars_lit = i + 1
			var s: TextureRect = star_nodes[i]
			s.modulate = Globals.GOLD
			s.pivot_offset = s.size * 0.5
			s.scale = Vector2(1.8, 1.8)
			create_tween().tween_property(s, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			if not instant:
				AudioManager.play_sfx("star_ding", 1.0 + i * 0.15)
				AudioManager.vibrate(25)

func _on_move(result: Dictionary) -> void:
	moves_left -= 1
	score += int(result.score)
	_update_hud()
	if int(result.max_chain) >= 1:
		_show_combo(int(result.max_chain) + 1)

func _on_cleared(count: int, chain: int, at: Vector2, pts: int) -> void:
	var col := Globals.MAGENTA if chain > 0 else Globals.TEXT
	if count >= 8:
		col = Globals.GOLD
	_popup("+%d" % pts, at, col, 26 + mini(chain, 4) * 3)

func _on_special_created(kind: int, at: Vector2) -> void:
	var names := {BoardModel.Special.LINE_H: "LINE", BoardModel.Special.LINE_V: "LINE", BoardModel.Special.BURST: "BURST", BoardModel.Special.PRISM: "PRISM"}
	_popup(str(names.get(kind, "SPECIAL")) + " FORGED", at + Vector2(0, -34), Globals.GOLD, 20)

func _on_special_fired(_kind: int, _at: Vector2, combo: String) -> void:
	if combo != "":
		var names := {"prism_prism": "TOTAL ECLIPSE", "prism_color": "PRISM STRIKE", "prism_special": "PRISM FORGE", "cross": "CROSSFIRE", "triple_cross": "TRIPLE CROSS", "mega_burst": "MEGA BURST"}
		_toast(str(names.get(combo, "COMBO")), 1.6)

func _show_combo(n: int) -> void:
	%ComboLabel.text = "COMBO x%d" % n
	%ComboSub.text = ["Cascade bonus active", "Chain reaction!", "The grid trembles", "Unstoppable"][clampi(n - 2, 0, 3)]
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	%ComboBanner.modulate.a = 1.0
	%ComboBanner.pivot_offset = %ComboBanner.size * 0.5
	%ComboBanner.scale = Vector2(0.94, 0.94)
	_combo_tween = create_tween()
	_combo_tween.tween_property(%ComboBanner, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_combo_tween.tween_interval(1.6)
	_combo_tween.tween_property(%ComboBanner, "modulate:a", 0.0, 0.4)

func _on_settled() -> void:
	if ended:
		return
	if score >= int(params.stars[2]):
		_finish(true, moves_left * 100)
	elif moves_left <= 0:
		_finish(score >= int(params.target))
	elif moves_left == 1:
		_toast("LAST MOVE", 1.4)

func _finish(cleared: bool, bonus: int = 0) -> void:
	ended = true
	%Board.interactive = false
	if bonus > 0:
		_toast("+%d MOVES BONUS" % bonus, 1.6)
		score += bonus
		_update_hud()
		await get_tree().create_timer(0.9).timeout
	AudioManager.play_sfx("level_win" if cleared else "level_fail")
	if cleared:
		AudioManager.vibrate(60)
	await get_tree().create_timer(1.1).timeout
	Globals.go("match_result", {
		"level": level, "score": score, "cleared": cleared, "moves_left": moves_left, "bonus": bonus,
		"stars": MatchLevels.stars_for(level, score), "target": int(params.target),
	})

func toggle_pause() -> void:
	if ended:
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
		if not paused and not ended and is_inside_tree():
			toggle_pause()

func _popup(text: String, at: Vector2, color: Color, font_size: int = 24) -> void:
	var l := Label.new()
	l.theme_type_variation = &"NumberLabel"
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(Globals.BG0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 5
	%Popups.add_child(l)
	l.position = at - Vector2(40, 16)
	l.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "modulate:a", 1.0, 0.1)
	t.tween_property(l, "position:y", l.position.y - 44, 0.8).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(l.queue_free)

var _toast_tween: Tween
func _toast(text: String, hold: float = 1.8) -> void:
	%Toast.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	%Toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(%Toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(%Toast, "modulate:a", 0.0, 0.4)
