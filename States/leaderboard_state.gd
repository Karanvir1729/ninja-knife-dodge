extends CanvasLayer
## Local top-10 boards for both games, with lifetime stats and the next milestone.

var tab := "knife"
var _tabs := {}

func init(params: Dictionary) -> void:
	tab = str(params.get("tab", "knife"))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	%Back.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	for c in %TabsBox.get_children():
		c.queue_free()
	for g in Globals.GAMES:
		var b := Button.new()
		b.theme_type_variation = &"TabButton"
		b.toggle_mode = true
		b.text = str(g.title)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_select.bind(str(g.id), false))
		%TabsBox.add_child(b)
		_tabs[str(g.id)] = b
	if not _tabs.has(tab):
		tab = "knife"
	_select(tab, true)

func _select(which: String, silent: bool = false) -> void:
	if not silent:
		AudioManager.click()
	tab = which
	var g := Globals.game(which)
	var accent: Color = g.get("accent", Globals.CYAN)
	for id in _tabs.keys():
		_tabs[id].set_pressed_no_signal(id == which)
		_tabs[id].add_theme_color_override("font_pressed_color", accent)
	_build_rows(accent)
	_build_stats(accent)

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_rows(accent: Color) -> void:
	_clear(%Rows)
	var board: Array = SaveData.game_board(tab)
	%Rows.add_child(_header())
	var rank_colors := [Globals.GOLD, Color("c8d0e6"), Globals.ORANGE]
	for i in board.size():
		var e: Dictionary = board[i]
		var detail := ""
		if tab == "knife":
			detail = "WAVE %d  ·  %s" % [int(e.get("wave", 0)), Globals.format_time(float(e.get("time", 0.0)))]
		elif tab == "match":
			detail = "LEVEL %d  ·  %d STAR%s" % [int(e.get("level", 0)), int(e.get("stars", 0)), "" if int(e.get("stars", 0)) == 1 else "S"]
		else:
			detail = str(e.get("detail", ""))
		var top := i < 3
		%Rows.add_child(_row(i + 1, str(e.get("name", "NINJA")), int(e.get("score", 0)), detail, rank_colors[i] if top else Globals.MUTED, top, accent))
	var note := Label.new()
	note.theme_type_variation = &"CapsLabel"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Globals.DIM)
	if board.is_empty():
		note.text = "NO LEVELS PLAYED YET. THE BOARD IS YOURS." if tab == "match" else "NO ROUNDS YET. PLAY TO CLAIM THE TOP SPOT."
	elif board.size() < SaveData.BOARD_SIZE:
		var left := SaveData.BOARD_SIZE - board.size()
		note.text = "%d MORE %s TO FILL THE BOARD" % [left, ("RUN" if tab == "knife" else ("GAME" if tab == "match" else "ROUND")) + ("" if left == 1 else "S")]
	else:
		note.text = "TOP %d  ·  BEAT %d TO GET ON THE BOARD" % [SaveData.BOARD_SIZE, int(board[board.size() - 1].score)]
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_child(note)
	%Rows.add_child(pad)

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_child(h)
	for spec in [["RANK", 90, 0], ["NINJA", 0, 3], ["SCORE", 170, 2], [("RUN" if tab == "knife" else ("LEVEL" if tab == "match" else "ROUND")), 250, 2]]:
		var l := Label.new()
		l.theme_type_variation = &"CapsLabel"
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Globals.DIM)
		l.text = spec[0]
		if spec[1] > 0:
			l.custom_minimum_size.x = spec[1]
		if spec[2] == 3:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if spec[2] == 2:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return m

func _row(rank: int, pname: String, score: int, detail: String, rank_color: Color, top: bool, accent: Color) -> Control:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel", "RaisedPanel").duplicate()
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12 if top else 9
	sb.content_margin_bottom = 12 if top else 9
	sb.bg_color = Color(0.0549, 0.0588, 0.0863, 0.86)
	if top:
		sb.border_color = Color(rank_color, 0.5)
		if rank == 1:
			sb.bg_color = Color(rank_color, 0.06)
			sb.shadow_color = Color(rank_color, 0.12)
			sb.shadow_size = 14
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var r := Label.new()
	r.theme_type_variation = &"DisplayLabel" if top else &"NumberLabel"
	r.add_theme_font_size_override("font_size", 30 if top else 24)
	r.add_theme_color_override("font_color", rank_color)
	r.custom_minimum_size.x = 90
	r.text = str(rank)
	h.add_child(r)
	var n := Label.new()
	n.theme_type_variation = &"NumberLabel"
	n.add_theme_font_size_override("font_size", 26 if top else 23)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text = pname
	h.add_child(n)
	var s := Label.new()
	s.theme_type_variation = &"NumberLabel"
	s.add_theme_font_size_override("font_size", 30 if top else 26)
	s.custom_minimum_size.x = 170
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.text = Globals.format_number(score)
	if rank == 1:
		s.add_theme_color_override("font_color", accent)
	h.add_child(s)
	var d := Label.new()
	d.theme_type_variation = &"CapsLabel"
	d.add_theme_font_size_override("font_size", 15)
	d.custom_minimum_size.x = 250
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.text = detail
	h.add_child(d)
	return p

func _build_stats(accent: Color) -> void:
	_clear(%StatsGrid)
	var tiles := []
	var next_val := 0
	var next_title := ""
	var progress := 0.0
	var current := 0
	var g := Globals.game(tab)
	var milestones: Array = g.get("milestones", [])
	if tab != "knife" and tab != "match":
		var st: Dictionary = SaveData.game_stats(tab)
		var plays := int(st.plays)
		var avg := int(round(float(st.total) / plays)) if plays > 0 else 0
		var board: Array = st.board
		var top_detail := str(board[0].get("detail", "")) if not board.is_empty() else "—"
		tiles = [
			[Globals.format_number(int(st.best)), "BEST", accent], [str(plays), "ROUNDS", Globals.TEXT],
			[Globals.format_number(int(st.total)), "TOTAL SCORE", Globals.TEXT], [str(avg), "AVERAGE", Globals.TEXT],
			[top_detail, "TOP ROUND", Globals.GOLD], [_duration(float(st.time)), "PLAYED", Globals.TEXT],
		]
		current = int(st.best)
		for m in milestones:
			if current < int(m[0]):
				next_val = int(m[0]); next_title = m[1]; break
		var fmt := str(g.get("milestone_text", "Reach %d to earn the %s title."))
		%MilestoneText.text = (fmt % [next_val, next_title.capitalize()]).replace(str(next_val), "[color=#%s]%d[/color]" % [accent.to_html(false), next_val]) if next_val > 0 else "Every title is yours."
	elif tab == "knife":
		var k: Dictionary = SaveData.knife_stats()
		var runs := int(k.runs)
		var avg := int(round(float(k.total_dodged) / runs)) if runs > 0 else 0
		tiles = [
			[str(int(k.best)), "BEST", accent], [str(runs), "RUNS", Globals.TEXT],
			[Globals.format_number(int(k.total_dodged)), "DAGGERS DODGED", Globals.TEXT], [str(avg), "AVERAGE", Globals.TEXT],
			[Globals.format_number(int(k.near_misses)), "NEAR MISSES", Globals.GREEN], [_duration(float(k.time_played)), "IN THE VOID", Globals.TEXT],
		]
		current = int(k.best)
		for m in milestones:
			if current < int(m[0]):
				next_val = int(m[0]); next_title = m[1]; break
		%MilestoneText.text = "Dodge [color=#56f0ff]%d[/color] daggers in one run to earn the %s title." % [next_val, next_title.capitalize()] if next_val > 0 else "Every title is yours. The void bows."
	else:
		var m: Dictionary = SaveData.match_stats()
		var levels: Dictionary = m.levels
		var three := 0
		var best := 0
		for key in levels.keys():
			if int(levels[key].stars) >= 3: three += 1
			best = maxi(best, int(levels[key].best))
		tiles = [
			[str(maxi(0, int(m.next_level) - 1)), "LEVELS CLEARED", accent], [str(int(m.total_stars)), "STARS", Globals.GOLD],
			[Globals.format_number(best), "BEST SCORE", Globals.TEXT], [str(int(m.games)), "GAMES", Globals.TEXT],
			[str(three), "PERFECT LEVELS", Globals.TEXT], [str(levels.size()), "LEVELS PLAYED", Globals.TEXT],
		]
		current = int(m.total_stars)
		for ms in milestones:
			if current < int(ms[0]):
				next_val = int(ms[0]); next_title = ms[1]; break
		%MilestoneText.text = "Collect [color=#ff4fd8]%d[/color] stars to earn the %s title." % [next_val, next_title.capitalize()] if next_val > 0 else "Every title is yours. The grid bows."
	for t in tiles:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var num := Label.new()
		num.theme_type_variation = &"NumberLabel"
		num.add_theme_font_size_override("font_size", 34)
		num.add_theme_color_override("font_color", t[2])
		num.text = t[0]
		var cap := Label.new()
		cap.theme_type_variation = &"CapsLabel"
		cap.add_theme_font_size_override("font_size", 14)
		cap.text = t[1]
		v.add_child(num)
		v.add_child(cap)
		%StatsGrid.add_child(v)
	progress = clampf(float(current) / float(next_val), 0.0, 1.0) if next_val > 0 else 1.0
	%MilestoneBar.value = progress * 100.0
	var fill: StyleBoxFlat = %MilestoneBar.get_theme_stylebox("fill").duplicate()
	fill.bg_color = accent
	%MilestoneBar.add_theme_stylebox_override("fill", fill)
	var msb: StyleBoxFlat = %MilestonePanel.get_theme_stylebox("panel").duplicate()
	msb.border_color = Color(accent, 0.3)
	%MilestonePanel.add_theme_stylebox_override("panel", msb)

func _duration(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 60:
		return "%dm" % m
	return "%dh %dm" % [m / 60, m % 60]
