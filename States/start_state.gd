extends CanvasLayer
## The Star Dojo hub: four trial cards (one per game), the two guides, and the
## story beats (intro, seal celebrations, epilogue).

const MASCOT := preload("res://UI/mascot.gd")
const ACCENTS := {"knife": Color("56f0ff"), "draw": Color("ff8a3d"), "match": Color("ff4fd8"), "simon": Color("9b6bff")}

var director: GuideDirector
var sensei: Mascot
var pip: Mascot
var _cards := {}
var _card_styles := {}
var _seal_icons := {}

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_on_resize)
	%PlayerName.text = SaveData.player_name()
	%Seals.text = "%d / 4 SEALS" % Story.seals_count()
	%Version.text = "V%s  ·  OFFLINE  ·  %s" % [Globals.VERSION, "OPTIONAL REWARD ADS" if Ads.is_real() else "NO ADS"]
	%StoryBtn.pressed.connect(func(): AudioManager.click(); Globals.go("story"))
	%TrophyBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%BoardBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%GearBtn.pressed.connect(func(): AudioManager.click(); Globals.go("settings"))
	%HowBtn.pressed.connect(func(): AudioManager.click(); _show_how(true))
	%HowClose.pressed.connect(func(): AudioManager.back(); _show_how(false))
	%HowDim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show_how(false))
	%HowTo.visible = false
	%SkipIntro.visible = false
	%SkipIntro.pressed.connect(func(): AudioManager.back(); director.skip_all())
	_build_cards()
	_build_howto()
	_enter_animation()
	_setup_guides()

func _on_resize() -> void:
	Globals.apply_safe_margins(%Root, 30)
	call_deferred("_place_guides", false)

# ---------------------------------------------------------------- trial cards

func _build_cards() -> void:
	for c in %Cards.get_children():
		c.queue_free()
	for id in Story.ORDER:
		var g := Globals.game(id)
		var card := _trial_card(g)
		%Cards.add_child(card)
		_cards[id] = card

func _card_style(accent: Color, lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Globals.BG1, 0.9 if lit else 0.86)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent, 0.95 if lit else 0.45)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(accent, 0.32 if lit else 0.12)
	sb.shadow_size = 34 if lit else 22
	sb.set_content_margin_all(0)
	return sb

func _trial_card(g: Dictionary) -> Button:
	var id := str(g.id)
	var t := Story.trial(id)
	var accent: Color = ACCENTS.get(id, g.accent)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var normal := _card_style(accent, false)
	var lit := _card_style(accent, true)
	_card_styles[id] = [normal, lit]
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): AudioManager.click(); Globals.start_game(id))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 14
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	# header: trial numeral + category chip
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := Label.new()
	num.theme_type_variation = &"CapsLabel"
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", accent)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.text = "TRIAL %s" % str(t.get("numeral", ""))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(num)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	var cat_accent: Color = Globals.CATEGORIES[g.category].accent
	csb.bg_color = Color(cat_accent, 0.14)
	csb.set_corner_radius_all(6)
	csb.content_margin_left = 8
	csb.content_margin_right = 8
	csb.content_margin_top = 3
	csb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", csb)
	var cl := Label.new()
	cl.theme_type_variation = &"CapsLabel"
	cl.add_theme_font_size_override("font_size", 13)
	cl.add_theme_color_override("font_color", cat_accent)
	cl.text = "MIND" if g.category == "mind" else "SKILL"
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(cl)
	head.add_child(chip)
	v.add_child(head)
	# illustration
	var art := _art(id, accent)
	art.custom_minimum_size = Vector2(0, 112)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	# names
	var title := Label.new()
	title.theme_type_variation = &"DisplayLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.text = str(g.title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var trial := Label.new()
	trial.theme_type_variation = &"CapsLabel"
	trial.add_theme_font_size_override("font_size", 13)
	trial.add_theme_color_override("font_color", accent)
	trial.text = str(t.get("trial", ""))
	trial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(trial)
	var hook := Label.new()
	hook.theme_type_variation = &"MutedLabel"
	hook.add_theme_font_size_override("font_size", 16)
	hook.text = str(t.get("hook", g.tagline))
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hook)
	# stats
	var stat := Label.new()
	stat.theme_type_variation = &"CapsLabel"
	stat.add_theme_font_size_override("font_size", 13)
	var value := SaveData.best_for(id)
	if id == "match":
		stat.text = "LEVEL %d   ·   %d STARS" % [value, SaveData.match_total_stars()]
	else:
		stat.text = "%s %s   ·   %d PLAYS" % [str(g.stat_label), Globals.format_number(value), SaveData.plays_for(id)]
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stat)
	# seal row
	var seal := HBoxContainer.new()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_theme_constant_override("separation", 8)
	var earned := Story.seal_earned(id)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load("res://graphics/gen/story/seal_ring.png")
	icon.custom_minimum_size = Vector2(22, 22)
	icon.modulate = Globals.GOLD if earned else Globals.LINE2
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(icon)
	_seal_icons[id] = icon
	var glyph := TextureRect.new()
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture = load("res://graphics/gen/story/glyph_%s.png" % str(t.get("glyph", "blade")))
	glyph.custom_minimum_size = Vector2(14, 14)
	glyph.modulate = Globals.GOLD if earned else Globals.LINE2
	glyph.position = Vector2(4, 4)
	glyph.size = Vector2(14, 14)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(glyph)
	var seal_text := VBoxContainer.new()
	seal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_text.add_theme_constant_override("separation", 3)
	var sl := Label.new()
	sl.theme_type_variation = &"CapsLabel"
	sl.add_theme_font_size_override("font_size", 12)
	sl.add_theme_color_override("font_color", Globals.GOLD if earned else Globals.MUTED)
	sl.text = "SEAL EARNED" if earned else "SEAL: " + str(t.get("seal_rule", "")).to_upper()
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_text.add_child(sl)
	if not earned:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.show_percentage = false
		bar.value = clampf(float(Story.progress(id)) / float(Story.seal_target(id)), 0.0, 1.0) * 100.0
		var fill: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
		fill.bg_color = accent
		bar.add_theme_stylebox_override("fill", fill)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal_text.add_child(bar)
	seal.add_child(seal_text)
	v.add_child(seal)
	# play
	var play := Button.new()
	play.custom_minimum_size = Vector2(0, 44)
	play.theme_type_variation = &"MagentaButton" if g.category == "mind" else &"PrimaryButton"
	play.add_theme_font_size_override("font_size", 20)
	play.text = "PLAY"
	play.pressed.connect(func(): AudioManager.click(); Globals.start_game(id))
	v.add_child(play)
	return b

## A small illustration per trial, built from the generated sprites.
func _art(id: String, accent: Color) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	var glow := _tex("res://graphics/gen/glow.png", Color(accent, 0.35), 150)
	glow.name = "Glow"
	box.add_child(glow)
	match id:
		"knife":
			var star := _tex("res://graphics/gen/player_star.png", Color(1, 0.96, 0.88), 58)
			star.name = "Star"
			box.add_child(star)
			for i in 3:
				var dg := _tex("res://graphics/skeleton_sword.png", Color(1, 1, 1, 1).lerp([Globals.CYAN, Globals.RED, Globals.GOLD][i], 0.3), 44)
				dg.name = "Dagger%d" % i
				dg.pivot_offset = Vector2(22, 22)
				dg.rotation = [-0.6, 2.2, 0.9][i]
				box.add_child(dg)
		"draw":
			for i in 2:
				var ring := _tex("res://graphics/gen/ring.png", Color(accent, 0.9 - i * 0.4), 108 + i * 44)
				ring.name = "Ring%d" % i
				box.add_child(ring)
			var sh := _tex("res://graphics/gen/shuriken.png", accent, 44)
			sh.name = "Target"
			box.add_child(sh)
			var dec := _tex("res://graphics/skeleton_sword.png", Globals.RED, 38)
			dec.name = "Decoy"
			dec.pivot_offset = Vector2(19, 19)
			dec.rotation = 2.4
			box.add_child(dec)
		"match":
			for i in 9:
				var sh := _tex("res://graphics/gen/shuriken.png", Globals.GEM_COLORS[(i * 5 + (i / 3)) % 6], 32)
				sh.name = "Gem%d" % i
				box.add_child(sh)
		"simon":
			for i in 9:
				var lit := i in [1, 4, 5]
				var dot := _tex("res://graphics/gen/dot.png", Color.from_hsv(fmod(0.72 + i * 0.11, 1.0), 0.7, 1.0, 1.0 if lit else 0.35), 28 if lit else 20)
				dot.name = "Pad%d" % i
				box.add_child(dot)
				if lit:
					var pg := _tex("res://graphics/gen/glow.png", Color(Color.from_hsv(fmod(0.72 + i * 0.11, 1.0), 0.7, 1.0), 0.6), 70)
					pg.name = "PadGlow%d" % i
					box.add_child(pg)
	box.resized.connect(_layout_art.bind(box, id))
	call_deferred("_layout_art", box, id)
	return box

func _tex(path: String, color: Color, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(path)
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _center(node: Control, box: Control, offset: Vector2 = Vector2.ZERO) -> void:
	node.position = box.size * 0.5 - node.size * 0.5 + offset

func _layout_art(box: Control, id: String) -> void:
	if not is_instance_valid(box):
		return
	_center(box.get_node("Glow"), box)
	match id:
		"knife":
			_center(box.get_node("Star"), box)
			_center(box.get_node("Dagger0"), box, Vector2(-84, -30))
			_center(box.get_node("Dagger1"), box, Vector2(78, 24))
			_center(box.get_node("Dagger2"), box, Vector2(26, -46))
		"draw":
			_center(box.get_node("Ring0"), box)
			_center(box.get_node("Ring1"), box)
			_center(box.get_node("Target"), box)
			_center(box.get_node("Decoy"), box, Vector2(100, -30))
		"match":
			for i in 9:
				_center(box.get_node("Gem%d" % i), box, Vector2((i % 3 - 1) * 40, (i / 3 - 1) * 38))
		"simon":
			for i in 9:
				var off := Vector2((i % 3 - 1) * 42, (i / 3 - 1) * 36)
				_center(box.get_node("Pad%d" % i), box, off)
				if box.has_node("PadGlow%d" % i):
					_center(box.get_node("PadGlow%d" % i), box, off)

func _highlight(name: String, on: bool) -> void:
	var ids := []
	if name in ["mind", "skill"]:
		for g in Globals.games_in(name):
			ids.append(str(g.id))
	elif _cards.has(name):
		ids = [name]
	for id in _cards.keys():
		var lit: bool = on and ids.has(id)
		var card: Button = _cards[id]
		card.add_theme_stylebox_override("normal", _card_styles[id][1 if lit else 0])
		card.pivot_offset = card.size * 0.5
		var t := create_tween()
		t.tween_property(card, "scale", Vector2(1.03, 1.03) if lit else Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)

func _target_rect(name: String) -> Rect2:
	if _cards.has(name):
		return _cards[name].get_global_rect()
	var ids := []
	for g in Globals.games_in(name):
		ids.append(str(g.id))
	var r := Rect2()
	for id in ids:
		if _cards.has(id):
			r = _cards[id].get_global_rect() if r.size == Vector2.ZERO else r.merge(_cards[id].get_global_rect())
	return r if r.size != Vector2.ZERO else Globals.view_rect()

# ---------------------------------------------------------------- guides and story beats

func _setup_guides() -> void:
	sensei = MASCOT.new()
	sensei.character = "sensei"
	sensei.base_scale = 0.56
	pip = MASCOT.new()
	pip.character = "pip"
	pip.base_scale = 0.56
	%Actors.add_child(sensei)
	%Actors.add_child(pip)
	sensei.tapped.connect(func(): _tip("sensei"))
	pip.tapped.connect(func(): _tip("pip"))
	director = GuideDirector.new()
	add_child(director)
	director.setup(sensei, pip, %Bubble)
	director.beside = true
	director.target_rect = _target_rect
	director.highlighter = _highlight
	director.bubble_bounds = func():
		var r: Rect2 = %Stage.get_global_rect()
		return Rect2(r.position + Vector2(330, -6), Vector2(r.size.x - 330 + 380, r.size.y + 12))
	director.finished.connect(_on_script_finished)
	SaveData.mark_launch()
	await get_tree().process_frame
	await get_tree().process_frame
	_place_guides(true)
	await get_tree().create_timer(0.9).timeout
	var pending := Story.pending_celebrations()
	if not pending.is_empty():
		_celebrate(str(pending[0]))
	elif Story.all_sealed() and not SaveData.story_flag("epilogue_seen"):
		SaveData.set_story_flag("epilogue_seen")
		director.run(Story.epilogue_scene(SaveData.player_name()))
	elif not SaveData.intro_seen():
		%SkipIntro.visible = true
		%Version.visible = false
		director.run(GuideDirector.intro(SaveData.player_name()))
	else:
		director.run(GuideDirector.greeting(SaveData.player_name()))

func _celebrate(id: String) -> void:
	SaveData.set_seal_celebrated(id)
	AudioManager.play_sfx("seal")
	AudioManager.vibrate(40)
	if _seal_icons.has(id):
		var icon: TextureRect = _seal_icons[id]
		icon.pivot_offset = icon.size * 0.5
		icon.scale = Vector2(2.4, 2.4)
		create_tween().tween_property(icon, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	%Seals.text = "%d / 4 SEALS" % Story.seals_count()
	director.run(Story.seal_scene(id, SaveData.player_name()))

func _place_guides(animate: bool) -> void:
	if sensei == null:
		return
	var r: Rect2 = %Stage.get_global_rect()
	var floor_y := r.end.y - 6.0
	var home_s := Vector2(r.position.x + 90.0, floor_y - 118.0 * sensei.base_scale)
	var home_p := Vector2(r.position.x + 235.0, floor_y - 92.0 * pip.base_scale)
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
	var pending := Story.pending_celebrations()
	if not pending.is_empty():
		await get_tree().create_timer(0.6).timeout
		_celebrate(str(pending[0]))
	elif Story.all_sealed() and not SaveData.story_flag("epilogue_seen"):
		SaveData.set_story_flag("epilogue_seen")
		await get_tree().create_timer(0.6).timeout
		director.run(Story.epilogue_scene(SaveData.player_name()))

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
	var pro := Button.new()
	pro.text = "WATCH THE PROLOGUE"
	pro.theme_type_variation = &"PrimaryButton"
	pro.add_theme_font_size_override("font_size", 22)
	pro.pressed.connect(func(): AudioManager.click(); Globals.go("cinematic", {"return": "start"}))
	%HowButtons.add_child(pro)
	for g in Globals.GAMES:
		var b := Button.new()
		b.text = str(g.title)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): AudioManager.click(); Globals.go(str(g.tutorial_state), {"return": "levels"} if g.id == "match" else {}))
		%HowButtons.add_child(b)
	var meet := Button.new()
	meet.text = "MEET THE GUIDES"
	meet.add_theme_font_size_override("font_size", 20)
	meet.pressed.connect(func(): AudioManager.click(); replay_intro())
	%HowButtons.add_child(meet)

func _show_how(open: bool) -> void:
	%HowTo.visible = open

func _enter_animation() -> void:
	%TitleBlock.modulate.a = 0.0
	create_tween().tween_property(%TitleBlock, "modulate:a", 1.0, 0.45)
	var i := 0
	for card in %Cards.get_children():
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.4).set_delay(0.1 + i * 0.1)
		i += 1
