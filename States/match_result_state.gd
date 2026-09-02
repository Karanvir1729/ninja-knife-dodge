extends CanvasLayer
## Shuriken Match level summary: stars, score breakdown, and where to next.

var level := 1
var score := 0
var cleared := false
var moves_left := 0
var bonus := 0
var stars := 0
var target := 0

func init(p: Dictionary) -> void:
	level = int(p.get("level", 1))
	score = int(p.get("score", 0))
	cleared = bool(p.get("cleared", false))
	moves_left = int(p.get("moves_left", 0))
	bonus = int(p.get("bonus", 0))
	stars = int(p.get("stars", 0))
	target = int(p.get("target", MatchLevels.params(level).target))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	Globals.apply_safe_margins(%Root, 24)
	var prev_best := int(SaveData.match_level_info(level).best)
	var result: Dictionary = SaveData.record_match_result(level, score, stars, cleared)
	%LevelCaps.text = "LEVEL %d" % level
	%Title.text = "CLEARED" if cleared else "OUT OF MOVES"
	if not cleared:
		%Title.add_theme_color_override("font_color", Globals.TEXT)
		%Title.add_theme_color_override("font_outline_color", Color(Globals.RED, 0.35))
	%ScoreVal.text = "0"
	%TargetLine.text = Globals.format_number(target)
	%BonusRow.visible = bonus > 0
	%BonusLine.text = "+%d x 100" % moves_left
	%BestLine.text = Globals.format_number(maxi(prev_best, score))
	if bool(result.new_best) and prev_best > 0:
		%BestLine.text += "  NEW"
		%BestLine.add_theme_color_override("font_color", Globals.GOLD)
	var rank := int(result.rank)
	%RankChip.visible = rank > 0
	%RankLabel.text = "#%d ON THE BOARD" % rank
	%NextBtn.visible = cleared and level < MatchLevels.LEVEL_COUNT
	%NextBtn.pressed.connect(func(): AudioManager.click(); Globals.go("match_play", {"level": level + 1}))
	%RetryBtn.pressed.connect(func(): AudioManager.click(); Globals.go("match_play", {"level": level}))
	%RetryBtn.theme_type_variation = &"MagentaButton" if not cleared else &"Button"
	%LevelsBtn.pressed.connect(func(): AudioManager.back(); Globals.go("match_levels"))
	%Hint.visible = not cleared
	%Hint.text = _hint_text()
	_animate()

func _hint_text() -> String:
	var gap := target - score
	if gap < 600:
		return "So close. One more cascade would have done it."
	return "Look for four-in-a-row swaps: a Line shuriken clears a whole row or column."

func _animate() -> void:
	%Card.pivot_offset = %Card.size * 0.5
	%Card.scale = Vector2(0.9, 0.9)
	%Card.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(%Card, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(%Card, "modulate:a", 1.0, 0.25)
	var counter := create_tween()
	counter.tween_method(func(v: float): %ScoreVal.text = Globals.format_number(int(v)), 0.0, float(score), 0.9).set_ease(Tween.EASE_OUT)
	var star_nodes := [%S1, %S2, %S3]
	for i in 3:
		var s: TextureRect = star_nodes[i]
		s.modulate = Globals.LINE
		s.pivot_offset = s.size * 0.5
		if i < stars:
			var st := create_tween()
			st.tween_interval(0.5 + i * 0.35)
			st.tween_callback(func():
				s.modulate = Globals.GOLD
				s.scale = Vector2(2.0, 2.0)
				AudioManager.play_sfx("star_ding", 1.0 + i * 0.18)
				AudioManager.vibrate(20))
			st.tween_property(s, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_shurikens_confetti()

func _shurikens_confetti() -> void:
	if not cleared:
		return
	var r := Globals.view_rect()
	var tex: Texture2D = load("res://graphics/gen/shuriken.png")
	for i in 14:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = Color(Globals.GEM_COLORS[i % Globals.GEM_COLORS.size()], 0.0)
		s.position = r.position + Vector2(randf_range(0.05, 0.95) * r.size.x, randf_range(0.1, 0.9) * r.size.y)
		s.scale = Vector2.ONE * randf_range(0.3, 0.7)
		s.rotation = randf() * TAU
		$Confetti.add_child(s)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(s, "modulate:a", 0.55, 0.6).set_delay(i * 0.05)
		t.tween_property(s, "rotation", s.rotation + randf_range(-2, 2), 3.0)
		t.tween_property(s, "position:y", s.position.y + randf_range(20, 60), 3.0)
