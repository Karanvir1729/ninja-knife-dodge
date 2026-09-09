extends CanvasLayer
## The Star Dojo hub: the story as a path of chapters (the prologue, four
## trials, the yard interlude, the turn and the epilogue), the two guides, and
## the beats that play here: films for a new seal, the turn and the ending, and
## the reveal of a chapter that has just opened. A chapter opens when every
## trial before it has its seal (Story.chapter_unlocked).

const MASCOT := preload("res://UI/mascot.gd")
const ACCENTS := {"knife": Color("56f0ff"), "draw": Color("ff8a3d"), "match": Color("ff4fd8"), "simon": Color("9b6bff")}
const CARD_W := 250.0
const FILM_W := 200.0
const LOCKED_TINT := Color(0.5, 0.53, 0.66, 1.0)

var director: GuideDirector
var sensei: Mascot
var pip: Mascot
var _cards := {}              # chapter id -> card Button
var _card_styles := {}
var _seal_icons := {}
var _chips := {}              # chapter id -> status chip (PanelContainer)
var _chip_labels := {}
var _play_buttons := {}
var _locks := {}              # chapter id -> lock overlay (only while locked)
var _pending_launch := ""
var _launch_on_ready := ""
var _current := ""

## {"launch": id} - the journal sends players here so a chapter's film (or its
## opening lines) plays before the first run.
func init(params: Dictionary) -> void:
	_launch_on_ready = str(params.get("launch", ""))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_on_resize)
	%PlayerName.text = SaveData.player_name()
	%Seals.text = "%d / 4 SEALS" % Story.seals_count()
	%Version.text = "V%s  ·  OFFLINE  ·  %s" % [Globals.VERSION, "AD SUPPORTED" if Ads.is_real() else "NO ADS"]
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
	%PathLine.draw.connect(_draw_path)
	%PathLine.resized.connect(func(): %PathLine.queue_redraw())
	%Cards.sort_children.connect(func(): %PathLine.queue_redraw())
	_build_path()
	_build_howto()
	_enter_animation()
	_setup_guides()

func _on_resize() -> void:
	Globals.apply_safe_margins(%Root, 30)
	call_deferred("_place_guides", false)
	call_deferred("_scroll_to", _focus_chapter(), false)

# ---------------------------------------------------------------- the chapter path

## The chapter the path centres on: the current one, else the last.
func _focus_chapter() -> String:
	return _current if not _current.is_empty() else str(Story.chapter_ids().back())

func _build_path() -> void:
	for c in %Cards.get_children():
		%Cards.remove_child(c)
		c.queue_free()
	_cards.clear()
	_seal_icons.clear()
	_chips.clear()
	_chip_labels.clear()
	_play_buttons.clear()
	_locks.clear()
	_current = Story.current_chapter()
	for id in Story.chapter_ids():
		var card := _chapter_card(str(id))
		%Cards.add_child(card)
		_cards[str(id)] = card
		# The first two chapters are always open: never animate their reveal.
		if Story.chapter_index(str(id)) <= 1 and not SaveData.chapter_revealed(str(id)):
			SaveData.set_chapter_revealed(str(id))
	%PathLine.queue_redraw()
	call_deferred("_scroll_to", _focus_chapter(), false)

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

func _accent(id: String) -> Color:
	var c := Story.chapter(id)
	if c.has("accent"):
		return c.accent
	if ACCENTS.has(id):
		return ACCENTS[id]
	return Globals.game(id).get("accent", Globals.GREEN)

func _caps(text: String, px: int, color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"CapsLabel"
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## One chapter on the path. Trials and the yard show their game's art, seal
## progress and PLAY; film chapters show a glyph and WATCH. Locked chapters are
## tinted down with a lock over the art, and tapping them asks Pip.
func _chapter_card(id: String) -> Button:
	var c := Story.chapter(id)
	var kind := str(c.get("kind", "trial"))
	var is_film := kind == "film"
	var g := Globals.game(id) if not is_film else {}
	var t := Story.trial(id)
	var accent := _accent(id)
	var unlocked := Story.chapter_unlocked(id)
	var done := Story.chapter_done(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(FILM_W if is_film else CARD_W, 0)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var normal := _card_style(accent, false)
	var lit := _card_style(accent, true)
	if done and kind != "film":
		normal.border_color = Color(Globals.GOLD, 0.5)
		normal.shadow_color = Color(Globals.GOLD, 0.1)
	_card_styles[id] = [normal, lit]
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): AudioManager.click(); _launch(id))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	# head: chapter label, status chip, film replay
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 6)
	var num := _caps(Story.chapter_label(id), 12, accent)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.clip_text = true
	num.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(num)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(accent, 0.14)
	csb.set_corner_radius_all(6)
	csb.content_margin_left = 8
	csb.content_margin_right = 8
	csb.content_margin_top = 3
	csb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", csb)
	var cl := _caps("", 11, accent)
	chip.add_child(cl)
	head.add_child(chip)
	_chips[id] = chip
	_chip_labels[id] = cl
	v.add_child(head)
	# illustration (with a lock over it while the chapter is closed)
	var art: Control = _film_art(id, accent) if is_film else _art(id, accent)
	art.custom_minimum_size = Vector2(0, 104)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	var lock := _tex("res://graphics/gen/icon_lock.png", Color(Globals.TEXT, 0.9), 40)
	lock.set_anchors_preset(Control.PRESET_CENTER)
	lock.position = Vector2(-20, -20)
	lock.visible = not unlocked
	art.add_child(lock)
	_locks[id] = lock
	# names
	var title := Label.new()
	title.theme_type_variation = &"DisplayLabel"
	title.add_theme_font_size_override("font_size", 19 if is_film else 22)
	title.text = str(g.get("title", Story.chapter_title(id))) if not is_film else Story.chapter_title(id)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_film:
		# An autowrapped label reports no minimum height in this column: give it two lines.
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.max_lines_visible = 2
		title.custom_minimum_size = Vector2(0, 50)
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var sub := _caps(Story.chapter_title(id) if not is_film else str(c.get("label", "")), 12, accent)
	_fit(sub)
	if is_film:
		sub.visible = false
	v.add_child(sub)
	var hook := Label.new()
	hook.theme_type_variation = &"MutedLabel"
	hook.add_theme_font_size_override("font_size", 14)
	hook.text = Story.chapter_hook(id)
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hook)
	# status row
	match kind:
		"trial":
			v.add_child(_seal_row(id, t, accent))
		"yard":
			v.add_child(_goal_row(id, accent))
		_:
			var w := _caps("WATCHED" if done else ("A NEW FILM" if unlocked else "LOCKED"), 12, Globals.GOLD if done else (accent if unlocked else Globals.MUTED))
			_fit(w)
			v.add_child(w)
	# the way in
	var play := Button.new()
	play.custom_minimum_size = Vector2(0, 42)
	play.theme_type_variation = &"MagentaButton" if str(g.get("category", "")) == "mind" else &"PrimaryButton"
	play.add_theme_font_size_override("font_size", 18)
	play.focus_mode = Control.FOCUS_NONE
	play.pressed.connect(func(): AudioManager.click(); _launch(id))
	v.add_child(play)
	_play_buttons[id] = play
	if not unlocked:
		b.modulate = LOCKED_TINT
	_style_state(id)
	return b

## Chip, play button and tint for a chapter's current state (called again after a reveal).
func _style_state(id: String) -> void:
	var c := Story.chapter(id)
	var kind := str(c.get("kind", "trial"))
	var unlocked := Story.chapter_unlocked(id)
	var done := Story.chapter_done(id)
	var accent := _accent(id)
	var chip: PanelContainer = _chips[id]
	var cl: Label = _chip_labels[id]
	var play: Button = _play_buttons[id]
	var csb: StyleBoxFlat = chip.get_theme_stylebox("panel")
	if not unlocked:
		cl.text = "LOCKED"
		cl.add_theme_color_override("font_color", Globals.MUTED)
		csb.bg_color = Color(Globals.LINE2, 0.3)
	elif id == _current:
		cl.text = "NEXT"
		cl.add_theme_color_override("font_color", accent)
		csb.bg_color = Color(accent, 0.18)
	elif done:
		cl.text = "SEALED" if kind == "trial" else "DONE"
		cl.add_theme_color_override("font_color", Globals.GOLD)
		csb.bg_color = Color(Globals.GOLD, 0.14)
	else:
		cl.text = "OPEN"
		cl.add_theme_color_override("font_color", accent)
		csb.bg_color = Color(accent, 0.12)
	chip.visible = true
	play.disabled = not unlocked
	if not unlocked:
		play.text = "LOCKED"
	elif kind == "film":
		play.text = "WATCH AGAIN" if done else "WATCH"
	else:
		play.text = "PLAY"

## A film chapter's illustration: its glyph on a glow.
func _film_art(id: String, accent: Color) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	var glow := _tex("res://graphics/gen/glow.png", Color(accent, 0.35), 150)
	glow.name = "Glow"
	box.add_child(glow)
	var glyph := _tex(str(Story.chapter(id).get("glyph", "res://graphics/gen/player_star.png")), Color(1, 1, 1, 1).lerp(accent, 0.35), 62)
	glyph.name = "Glyph"
	if id == "midpoint":
		glyph.pivot_offset = Vector2(31, 31)
		glyph.rotation = -0.7
	box.add_child(glyph)
	box.resized.connect(func():
		_center(box.get_node("Glow"), box)
		_center(box.get_node("Glyph"), box))
	return box

## Seal ring, seal name or rule, and progress toward it.
func _seal_row(id: String, t: Dictionary, accent: Color) -> Control:
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
	var sl := _caps(("SEAL EARNED" if earned else "SEAL: " + str(t.get("seal_rule", "")).to_upper()), 11, Globals.GOLD if earned else Globals.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seal_text.add_child(sl)
	if not earned:
		seal_text.add_child(_bar(float(Story.progress(id)) / float(maxi(1, Story.seal_target(id))), accent))
	seal.add_child(seal_text)
	return seal

## The yard's goal: the best innings against fifty.
func _goal_row(id: String, accent: Color) -> Control:
	var y := Story.yard(id)
	var best: int = SaveData.best_for(id)
	var target: int = int(y.get("goal_target", 0))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	if target > 0 and best >= target:
		var l := _caps("BEST %s  ·  PIP TOLD THEM" % Globals.format_number(best), 11, Globals.GOLD)
		_fit(l)
		col.add_child(l)
	else:
		var l := _caps("BEST %s  ·  GOAL %d" % [Globals.format_number(best), target], 11, Globals.MUTED)
		_fit(l)
		col.add_child(l)
		col.add_child(_bar(float(best) / float(maxi(1, target)), accent))
	return col

func _bar(fraction: float, accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	bar.value = clampf(fraction, 0.0, 1.0) * 100.0
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
	fill.bg_color = accent
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

## Single-line caps labels must never widen a card.
func _fit(l: Label) -> void:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

## The path itself: a dashed line between the cards, gold as far as the story has opened.
func _draw_path() -> void:
	var line: Control = %PathLine
	var ids := Story.chapter_ids()
	var prev: Control = null
	for id in ids:
		if not _cards.has(str(id)):
			continue
		var card: Control = _cards[str(id)]
		if card.size.y < 10.0 or (prev != null and card.position.x <= prev.position.x):
			return   # not laid out yet; sort_children redraws us
		if prev != null:
			var y := card.position.y + card.size.y * 0.5
			var a := Vector2(prev.position.x + prev.size.x, y)
			var b := Vector2(card.position.x, y)
			var open := Story.chapter_unlocked(str(id))
			line.draw_dashed_line(a + Vector2(6, 0), b - Vector2(6, 0), Color(Globals.GOLD, 0.75) if open else Color(Globals.LINE2, 0.9), 3.0, 9.0)
			line.draw_circle(a + Vector2(6, 0), 4.0, Color(Globals.GOLD, 0.9) if open else Globals.LINE2)
			line.draw_circle(b - Vector2(6, 0), 4.0, Color(Globals.GOLD, 0.9) if open else Globals.LINE2)
		prev = card

## Scroll the path so a chapter sits in the middle of the screen.
func _scroll_to(id: String, animate: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not _cards.has(id):
		return
	var card: Control = _cards[id]
	var scroll: ScrollContainer = %PathScroll
	var box: Control = %PathBox
	var cards: Control = %Cards
	var target: float = cards.position.x + card.position.x + card.size.x * 0.5 - scroll.size.x * 0.5
	target = clampf(target, 0.0, maxf(0.0, box.size.x - scroll.size.x))
	if animate:
		create_tween().tween_property(scroll, "scroll_horizontal", int(target), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		scroll.scroll_horizontal = int(target)

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
		"cricket":
			var pitch := ColorRect.new()
			pitch.name = "Pitch"
			pitch.color = Color(Globals.GREEN, 0.12)
			pitch.size = Vector2(46, 110)
			pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(pitch)
			for i in 3:
				var st := ColorRect.new()
				st.name = "Stump%d" % i
				st.color = Globals.TEXT
				st.size = Vector2(3, 18)
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(st)
			var ball := _tex("res://graphics/gen/glow.png", Color(Globals.GREEN, 0.95), 26)
			ball.name = "Ball"
			box.add_child(ball)
			for i in 3:
				var f := _tex("res://graphics/gen/dot.png", Globals.ORANGE, 14)
				f.name = "Fielder%d" % i
				box.add_child(f)
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

## Art grows with its panel (tall iPad cards) up to 1.8x.
func _art_k(box: Control) -> float:
	return clampf(box.size.y / 118.0, 1.0, 1.8)

func _center(node: Control, box: Control, offset: Vector2 = Vector2.ZERO) -> void:
	var k := _art_k(box)
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(k, k)
	node.position = box.size * 0.5 - node.size * 0.5 + offset * k

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
		"cricket":
			var k := _art_k(box)
			var pitch: Control = box.get_node("Pitch")
			pitch.pivot_offset = pitch.size * 0.5
			pitch.scale = Vector2(k, k)
			pitch.position = box.size * 0.5 - pitch.size * 0.5 + Vector2(0, -6) * k
			for i in 3:
				_center(box.get_node("Stump%d" % i), box, Vector2((i - 1) * 7, 40))
			_center(box.get_node("Ball"), box, Vector2(2, -30))
			for i in 3:
				_center(box.get_node("Fielder%d" % i), box, Vector2([-72, -40, 66][i], [18, 50, 30][i]))
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

## Open a chapter: a locked one asks Pip; a film chapter plays its film; a
## trial or the yard plays its opening film the first time, then the game.
## Ids that are not chapters (the how-to list) start the game directly.
func _launch(id: String) -> void:
	if director.running:
		director.skip_all()
	var c := Story.chapter(id)
	if c.is_empty():
		Globals.start_game(id)
		return
	if not Story.chapter_unlocked(id):
		_locked_line(id)
		return
	if str(c.kind) == "film":
		Globals.go("film", {"film": str(c.film), "return": "start"})
		return
	var film := Story.opening_film(id)
	if not film.is_empty() and not Story.film_seen(film):
		SaveData.set_trial_opened(id)
		Globals.go("film", {"film": film, "play": id})
		return
	if Story.has_opening(id) and not SaveData.trial_opened(id):
		# No film for this chapter yet: the guides open it here instead.
		SaveData.set_trial_opened(id)
		_pending_launch = id
		%SkipIntro.text = "SKIP"
		%SkipIntro.visible = true
		%Version.visible = false
		director.run(Story.opening_scene(id, SaveData.player_name()))
		return
	Globals.start_game(id)

## Replay a chapter's opening film from the hub.
func _watch(id: String) -> void:
	var film := Story.opening_film(id)
	if film.is_empty():
		return
	if director.running:
		director.skip_all()
	Globals.go("film", {"film": film, "return": "start"})

## "Chapter II", "The interlude", "The turn": a chapter label for a sentence.
func _pretty_label(id: String) -> String:
	var c := Story.chapter(id)
	if str(c.get("kind", "")) == "trial":
		return "Chapter %s" % str(Story.trial(id).get("numeral", ""))
	return Story.chapter_label(id).capitalize()

func _locked_line(id: String) -> void:
	AudioManager.play_sfx("swap_fail", 1.0, -10.0)
	var need := Story.unlock_seal(id)
	var text := "That chapter is still closed, %s." % SaveData.player_name()
	if not need.is_empty():
		var t := Story.trial(need)
		text = "%s opens with the %s. %s, %s." % [_pretty_label(id), str(t.seal_name), str(t.seal_rule), SaveData.player_name()]
	director.run([{"who": "pip", "mood": "think", "gesture": "point", "target": need if not need.is_empty() else id, "text": text}])

## Films due on the hub (a new seal, the turn, the ending, the yard's fifty),
## chained into one sitting. Seals are marked celebrated as the chain starts.
func _play_films(due: Array) -> void:
	for e in due:
		var ch := str(e.get("chapter", ""))
		if Story.ORDER.has(ch):
			SaveData.set_seal_celebrated(ch)
	AudioManager.play_sfx("seal")
	Globals.go("film", Story.chain_films(due))

## Chapters that opened since the player last saw the path.
func _reveals_due() -> Array:
	var out := []
	for id in Story.chapter_ids():
		if Story.chapter_unlocked(str(id)) and not SaveData.chapter_revealed(str(id)):
			out.append(str(id))
	return out

## Unlock a chapter on screen: scroll to it, lift the tint, break the lock.
func _reveal(ids: Array) -> void:
	for id in ids:
		SaveData.set_chapter_revealed(id)
		if not _cards.has(id):
			continue
		var card: Button = _cards[id]
		_scroll_to(id, true)
		await get_tree().create_timer(0.7).timeout
		if not is_inside_tree():
			return
		AudioManager.play_sfx("unlock")
		AudioManager.vibrate(30)
		create_tween().tween_property(card, "modulate", Color.WHITE, 0.5)
		card.pivot_offset = card.size * 0.5
		var t := create_tween()
		t.tween_property(card, "scale", Vector2(1.06, 1.06), 0.18).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if _locks.has(id):
			var lock: TextureRect = _locks[id]
			lock.pivot_offset = lock.size * 0.5
			var lt := create_tween()
			lt.set_parallel(true)
			lt.tween_property(lock, "scale", Vector2(1.8, 1.8), 0.35)
			lt.tween_property(lock, "modulate:a", 0.0, 0.35)
			lt.chain().tween_callback(func(): lock.visible = false)
		_style_state(id)
		await get_tree().create_timer(0.8).timeout
	_current = Story.current_chapter()
	for id in _cards.keys():
		_style_state(id)
	%PathLine.queue_redraw()
	if not is_inside_tree():
		return
	var last := str(ids.back())
	var c := Story.chapter(last)
	var line := "%s is open, %s! Tap it when you are ready." % [_pretty_label(last), SaveData.player_name()]
	if str(c.get("kind", "")) == "yard":
		line = "Someone is climbing the steps, %s. The Yard is open." % SaveData.player_name()
	elif str(c.get("kind", "")) == "film":
		line = "%s is ready to watch, %s." % [Story.chapter_title(last).capitalize(), SaveData.player_name()]
	director.run([{"who": "pip", "mood": "excited", "gesture": "point", "target": last, "text": line}])

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
		return Rect2(r.position + Vector2(330, -6), Vector2(maxf(r.size.x - 330, 300), r.size.y + 12))
	director.finished.connect(_on_script_finished)
	SaveData.mark_launch()
	await get_tree().process_frame
	await get_tree().process_frame
	_place_guides(true)
	if _launch_on_ready != "":
		await get_tree().create_timer(0.35).timeout
		_launch(_launch_on_ready)
		return
	var due := Story.pending_films()
	if not due.is_empty():
		await get_tree().create_timer(0.5).timeout
		_play_films(due)
		return
	await get_tree().create_timer(0.9).timeout
	var reveals := _reveals_due()
	var pending := Story.pending_celebrations()
	if not reveals.is_empty():
		_reveal(reveals)
	elif not pending.is_empty():
		_celebrate(str(pending[0]))
	elif Story.midpoint_due():
		_play_midpoint()
	elif Story.all_sealed() and not SaveData.story_flag("epilogue_seen"):
		SaveData.set_story_flag("epilogue_seen")
		director.run(Story.epilogue_scene(SaveData.player_name()))
	elif not SaveData.intro_seen():
		%SkipIntro.visible = true
		%Version.visible = false
		director.run(GuideDirector.intro(SaveData.player_name()))
	else:
		director.run(GuideDirector.greeting(SaveData.player_name()))

func _play_midpoint() -> void:
	SaveData.set_story_flag("midpoint_seen")
	AudioManager.play_sfx("rise", 1.0, -8.0)
	director.run(Story.midpoint_scene(SaveData.player_name()))

## The spoken celebration, used only while a seal has no film of its own.
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
	%SkipIntro.text = "SKIP INTRO"
	%Version.visible = true
	if not SaveData.intro_seen():
		SaveData.set_intro_seen()
	if not _pending_launch.is_empty():
		var id := _pending_launch
		_pending_launch = ""
		Globals.start_game(id)
		return
	var reveals := _reveals_due()
	var pending := Story.pending_celebrations()
	if not reveals.is_empty():
		await get_tree().create_timer(0.5).timeout
		_reveal(reveals)
	elif not pending.is_empty():
		await get_tree().create_timer(0.6).timeout
		_celebrate(str(pending[0]))
	elif Story.midpoint_due():
		await get_tree().create_timer(0.6).timeout
		_play_midpoint()
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
		# A walkthrough is a way into the game, so a closed chapter stays closed.
		var cid := str(g.id)
		if not Story.chapter(cid).is_empty() and not Story.chapter_unlocked(cid):
			continue
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
