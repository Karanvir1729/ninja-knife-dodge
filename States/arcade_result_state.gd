extends CanvasLayer
## Generic end-of-round screen for the arcade games, driven by Globals.GAMES.
## init params: {game: id, score: int, time: float, stats: [[value, CAPS, Color?]...],
##               title: String (optional), detail: String (leaderboard text), quip: String}

var game_id := "draw"
var score := 0
var time_sec := 0.0
var stats: Array = []
var title := ""
var detail := ""
var quip := ""

func init(p: Dictionary) -> void:
	game_id = str(p.get("game", "draw"))
	score = int(p.get("score", 0))
	time_sec = float(p.get("time", 0.0))
	stats = p.get("stats", [])
	title = str(p.get("title", ""))
	detail = str(p.get("detail", ""))
	quip = str(p.get("quip", ""))

func _ready() -> void:
	var g := Globals.game(game_id)
	var accent: Color = g.get("accent", Globals.CYAN)
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	Globals.apply_safe_margins(%Root, 24)
	var result: Dictionary = SaveData.record_game_score(game_id, score, {"detail": detail}, time_sec)
	%GameCaps.text = str(g.get("title", game_id.to_upper()))
	%GameCaps.add_theme_color_override("font_color", accent)
	%Title.text = title if title != "" else "ROUND OVER"
	%Title.add_theme_color_override("font_outline_color", Color(accent, 0.35))
	%ScoreVal.text = "0"
	%ScoreVal.add_theme_color_override("font_outline_color", Color(accent, 0.35))
	%RecordChip.visible = bool(result.new_record) and score > 0
	var rank := int(result.rank)
	%RankChip.visible = rank > 0
	%RankLabel.text = "#%d ON THE BOARD" % rank
	%RankLabel.add_theme_color_override("font_color", accent)
	%BestLine.text = "BEST %s" % Globals.format_number(int(SaveData.game_stats(game_id).best))
	%BestLine.visible = not %RecordChip.visible
	var card_sb: StyleBoxFlat = %Card.get_theme_stylebox("panel").duplicate()
	card_sb.border_color = Color(accent, 0.35)
	card_sb.shadow_color = Color(accent, 0.12)
	%Card.add_theme_stylebox_override("panel", card_sb)
	var chip_sb: StyleBoxFlat = %RankChip.get_theme_stylebox("panel").duplicate()
	chip_sb.border_color = Color(accent, 0.4)
	chip_sb.bg_color = Color(accent, 0.1)
	%RankChip.add_theme_stylebox_override("panel", chip_sb)
	for c in %Stats.get_children():
		c.queue_free()
	for st in stats:
		%Stats.add_child(_stat_tile(str(st[0]), str(st[1]), st[2] if st.size() > 2 else Globals.TEXT))
	%Stats.visible = not stats.is_empty()
	%Quip.visible = false
	if quip != "":
		var who := "sensei" if quip.begins_with("Sensei") or g.get("category", "skill") == "mind" else "pip"
		var text := quip
		var colon := quip.find(":")
		if colon > 0 and colon < 16:
			text = quip.substr(colon + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		GuideCameo.create(self, who, [text], "left" if who == "sensei" else "right")
	%PlayAgain.pressed.connect(func(): AudioManager.click(); Globals.go(str(g.get("play_state", "start"))))
	%PlayAgain.theme_type_variation = &"MagentaButton" if g.get("category", "skill") == "mind" else &"PrimaryButton"
	%Board.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard", {"tab": game_id}))
	%Menu.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	_animate(result)

func _stat_tile(val: String, caps: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"RaisedPanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var n := Label.new()
	n.theme_type_variation = &"NumberLabel"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_color_override("font_color", color)
	n.text = val
	var c := Label.new()
	c.theme_type_variation = &"CapsLabel"
	c.add_theme_font_size_override("font_size", 15)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.text = caps
	v.add_child(n)
	v.add_child(c)
	p.add_child(v)
	return p

func _animate(result: Dictionary) -> void:
	%Card.pivot_offset = %Card.size * 0.5
	%Card.scale = Vector2(0.9, 0.9)
	%Card.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(%Card, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(%Card, "modulate:a", 1.0, 0.25)
	var counter := create_tween()
	counter.tween_method(func(v: float): %ScoreVal.text = Globals.format_number(int(v)), 0.0, float(score), minf(1.2, 0.3 + score * 0.01))
	if bool(result.new_record) and score > 0:
		counter.tween_callback(func(): AudioManager.play_sfx("record"); AudioManager.vibrate(40))
