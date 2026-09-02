extends CanvasLayer
## Main menu: two categories (Mind games, Skill games) built from Globals.GAMES,
## plus the two animated guides who introduce the app and hand out tips.

const MASCOT := preload("res://UI/mascot.gd")

var director: GuideDirector
var sensei: Mascot
var pip: Mascot
var _col_styles := {}
var _cols := {}

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	get_viewport().size_changed.connect(_on_resize)
	%PlayerName.text = SaveData.player_name()
	%Version.text = "V%s  ·  OFFLINE  ·  %s  ·  NO TRACKING" % [Globals.VERSION, "OPTIONAL REWARD ADS" if Ads.is_real() else "NO ADS"]
	%TrophyBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%BoardBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%GearBtn.pressed.connect(func(): AudioManager.click(); Globals.go("settings"))
	%HowBtn.pressed.connect(func(): AudioManager.click(); _show_how(true))
	%HowClose.pressed.connect(func(): AudioManager.back(); _show_how(false))
	%HowDim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show_how(false))
	%HowTo.visible = false
	%SkipIntro.visible = false
	%SkipIntro.pressed.connect(func(): AudioManager.back(); director.skip_all())
	_build_categories()
	_build_howto()
	_enter_animation()
	_setup_guides()

func _on_resize() -> void:
	Globals.apply_safe_margins(%Root, 34)
	call_deferred("_place_guides", false)

# ---------------------------------------------------------------- categories

func _build_categories() -> void:
	for c in %Cats.get_children():
		c.queue_free()
	for cat_id in ["mind", "skill"]:
		var cat: Dictionary = Globals.CATEGORIES[cat_id]
		var accent: Color = cat.accent
		var col := PanelContainer.new()
		col.custom_minimum_size = Vector2(392, 0)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var normal := _col_style(accent, false)
		_col_styles[cat_id] = [normal, _col_style(accent, true)]
		col.add_theme_stylebox_override("panel", normal)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		col.add_child(v)
		var head := VBoxContainer.new()
		head.add_theme_constant_override("separation", 2)
		var title := Label.new()
		title.theme_type_variation = &"DisplayLabel"
		title.add_theme_font_size_override("font_size", 30)
		title.add_theme_color_override("font_color", accent)
		title.add_theme_color_override("font_outline_color", Color(accent, 0.3))
		title.add_theme_constant_override("outline_size", 6)
		title.text = str(cat.title)
		head.add_child(title)
		var blurb := Label.new()
		blurb.theme_type_variation = &"MutedLabel"
		blurb.add_theme_font_size_override("font_size", 18)
		blurb.text = str(cat.blurb)
		head.add_child(blurb)
		v.add_child(head)
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(0, 1)
		rule.color = Color(accent, 0.25)
		v.add_child(rule)
		for g in Globals.games_in(cat_id):
			v.add_child(_game_row(g))
		%Cats.add_child(col)
		_cols[cat_id] = col

func _col_style(accent: Color, lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Globals.BG1, 0.86)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent, 0.9 if lit else 0.4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(accent, 0.3 if lit else 0.1)
	sb.shadow_size = 36 if lit else 24
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

func _game_row(g: Dictionary) -> Button:
	var accent: Color = g.accent
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 86)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Globals.BG2, 0.55)
	sb.set_border_width_all(1)
	sb.border_color = Globals.LINE
	sb.set_corner_radius_all(12)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.border_color = Color(accent, 0.8)
	sbh.bg_color = Color(accent, 0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("hover_pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	b.add_child(h)
	var icon := _game_icon(g)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.theme_type_variation = &"DisplayLabel"
	t.add_theme_font_size_override("font_size", 26)
	t.text = str(g.title)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var stat := Label.new()
	stat.theme_type_variation = &"CapsLabel"
	stat.add_theme_font_size_override("font_size", 14)
	var value := SaveData.best_for(str(g.id))
	var plays := SaveData.plays_for(str(g.id))
	stat.text = "%s  %s      %s  %d" % [str(g.stat_label), Globals.format_number(value), "LEVELS" if g.id == "match" else "PLAYS", plays] if g.id != "match" else "%s  %d      STARS  %d" % [str(g.stat_label), value, SaveData.match_total_stars()]
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stat)
	h.add_child(v)
	var chevron := TextureRect.new()
	chevron.texture = load("res://graphics/gen/icon_play.png")
	chevron.custom_minimum_size = Vector2(22, 22)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.modulate = accent
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(chevron)
	b.pressed.connect(func(): AudioManager.click(); Globals.start_game(str(g.id)))
	return b

func _game_icon(g: Dictionary) -> Control:
	var accent: Color = g.accent
	var box := PanelContainer.new()
	box.theme_type_variation = &"RaisedPanel"
	box.custom_minimum_size = Vector2(58, 58)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = box.get_theme_stylebox("panel").duplicate()
	sb.set_content_margin_all(6)
	sb.border_color = Color(accent, 0.35)
	box.add_theme_stylebox_override("panel", sb)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	match str(g.id):
		"match":
			for i in 4:
				var s := _icon_tex("shuriken", Globals.GEM_COLORS[[1, 0, 2, 3][i]], 20)
				s.position = Vector2(2 + (i % 2) * 24, 2 + (i / 2) * 24)
				inner.add_child(s)
		"simon":
			for i in 9:
				var s := _icon_tex("dot", Color.from_hsv(fmod(0.72 + i * 0.11, 1.0), 0.7, 1.0), 12)
				s.position = Vector2(2 + (i % 3) * 16, 2 + (i / 3) * 16)
				inner.add_child(s)
		"knife":
			var glow := _icon_tex("glow", Color(Globals.ORANGE, 0.9), 46)
			glow.position = Vector2(0, 0)
			inner.add_child(glow)
			var s := _icon_tex("player_star", Color(1, 0.96, 0.88), 30)
			s.position = Vector2(8, 8)
			inner.add_child(s)
		"draw":
			var ring := _icon_tex("ring", accent, 46)
			ring.position = Vector2(0, 0)
			inner.add_child(ring)
			var s := _icon_tex("shuriken", accent, 24)
			s.position = Vector2(11, 11)
			inner.add_child(s)
	return box

func _icon_tex(name: String, color: Color, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load("res://graphics/gen/%s.png" % name)
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _highlight(cat_id: String, on: bool) -> void:
	for id in _cols.keys():
		var lit: bool = on and id == cat_id
		var col: PanelContainer = _cols[id]
		col.add_theme_stylebox_override("panel", _col_styles[id][1 if lit else 0])
		col.pivot_offset = col.size * 0.5
		var t := create_tween()
		t.tween_property(col, "scale", Vector2(1.03, 1.03) if lit else Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)

func _category_rect(cat_id: String) -> Rect2:
	if _cols.has(cat_id):
		return _cols[cat_id].get_global_rect()
	return Globals.view_rect()

# ---------------------------------------------------------------- guides

func _setup_guides() -> void:
	sensei = MASCOT.new()
	sensei.character = "sensei"
	pip = MASCOT.new()
	pip.character = "pip"
	%Actors.add_child(sensei)
	%Actors.add_child(pip)
	sensei.tapped.connect(func(): _tip("sensei"))
	pip.tapped.connect(func(): _tip("pip"))
	director = GuideDirector.new()
	add_child(director)
	director.setup(sensei, pip, %Bubble)
	director.target_rect = _category_rect
	director.highlighter = _highlight
	director.bubble_bounds = func(): return %Stage.get_global_rect().grow_individual(0, 40, 0, 0)
	director.finished.connect(_on_script_finished)
	SaveData.mark_launch()
	await get_tree().process_frame
	await get_tree().process_frame
	_place_guides(true)
	await get_tree().create_timer(0.9).timeout
	if not SaveData.intro_seen():
		%SkipIntro.visible = true
		%Version.visible = false
		director.run(GuideDirector.intro(SaveData.player_name()))
	else:
		director.run(GuideDirector.greeting(SaveData.player_name()))

## Home positions sit on the stage floor; entrances slide in from the left.
func _place_guides(animate: bool) -> void:
	if sensei == null:
		return
	var r: Rect2 = %Stage.get_global_rect()
	var floor_y := r.end.y - 16.0
	var home_s := Vector2(r.position.x + 130.0, floor_y - 118.0 * sensei.base_scale)
	var home_p := Vector2(r.position.x + 330.0, floor_y - 92.0 * pip.base_scale)
	if animate:
		sensei.enter(home_s + Vector2(-500, 0), home_s, 0.1)
		pip.enter(home_p + Vector2(-700, 0), home_p, 0.35)
	else:
		sensei.position = home_s
		pip.position = home_p

func _tip(who: String) -> void:
	if director.running:
		return
	AudioManager.click()
	director.run(GuideDirector.tip(who))

func _on_script_finished() -> void:
	%SkipIntro.visible = false
	%Version.visible = true
	if not SaveData.intro_seen():
		SaveData.set_intro_seen()
		sensei.set_mood("happy")
		pip.set_mood("happy")

func replay_intro() -> void:
	_show_how(false)
	%SkipIntro.visible = true
	%Version.visible = false
	director.skip_all()
	director.run(GuideDirector.intro(SaveData.player_name()))

# ---------------------------------------------------------------- how to play

func _build_howto() -> void:
	for c in %HowButtons.get_children():
		c.queue_free()
	for g in Globals.GAMES:
		var b := Button.new()
		b.text = str(g.title)
		b.theme_type_variation = &"MagentaButton" if g.category == "mind" else &"PrimaryButton"
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): AudioManager.click(); Globals.go(str(g.tutorial_state), {"return": "levels"} if g.id == "match" else {}))
		%HowButtons.add_child(b)
	var meet := Button.new()
	meet.text = "MEET THE GUIDES"
	meet.add_theme_font_size_override("font_size", 22)
	meet.pressed.connect(func(): AudioManager.click(); replay_intro())
	%HowButtons.add_child(meet)

func _show_how(open: bool) -> void:
	%HowTo.visible = open

func _enter_animation() -> void:
	%TitleBlock.modulate.a = 0.0
	create_tween().tween_property(%TitleBlock, "modulate:a", 1.0, 0.45)
	var i := 0
	for col in %Cats.get_children():
		col.modulate.a = 0.0
		var ct := create_tween()
		ct.tween_property(col, "modulate:a", 1.0, 0.4).set_delay(0.1 + i * 0.12)
		i += 1
