extends CanvasLayer
## The Story journal: the Four Trials as chapters, one per game, each with the
## seal it awards and progress toward it. A seal wheel on the right sums it up,
## the prologue can be re-watched, and the epilogue unlocks with the fourth seal.

const STORY_DIR := "res://graphics/gen/story/"
const ACCENTS := {"knife": Globals.CYAN, "draw": Globals.ORANGE, "match": Globals.MAGENTA, "simon": Globals.VIOLET}
const RING_PX := 140.0
const GLYPH_PX := 52.0
## Height of the right column's bottom band left free for Sensei and his bubble.
const CAMEO_RESERVE := 330.0

var _cards: Array = []
var _seals_shown := 0
var _wheel_radius := 110.0
var _ring: TextureRect
var _center_glow: TextureRect
var _count: Label
var _count_caps: Label
var _wheel_glyphs := {}
var _wheel_glows := {}
var _cameo: GuideCameo
var _tex_cache := {}

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	get_viewport().size_changed.connect(_on_resize)
	%Back.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	%PrologueBtn.pressed.connect(func(): AudioManager.click(); Globals.go("cinematic", {"return": "story"}))
	%Wheel.draw.connect(_draw_wheel)
	%Wheel.resized.connect(_layout_wheel)
	_fit_wheel()
	_build()
	_enter_animation()
	_cameo_line()

func _process(delta: float) -> void:
	if is_instance_valid(_ring):
		_ring.rotation += delta * 0.15

func _on_resize() -> void:
	Globals.apply_safe_margins(%Root, 34)
	_fit_wheel()

## Number of trial chapter cards in the journal (one per Story.ORDER entry).
func chapter_count() -> int:
	return _cards.size()

## Seal count shown on the wheel and in the header.
func seals_shown() -> int:
	return _seals_shown

# ---------------------------------------------------------------- build

func _build() -> void:
	_seals_shown = Story.seals_count()
	var total: int = Story.ORDER.size()
	%SealsLine.text = "STORY JOURNAL  ·  %d / %d SEALS" % [_seals_shown, total]
	_clear(%Journal)
	_cards.clear()
	%Journal.add_child(_prologue_entry())
	for id in Story.ORDER:
		var card := _chapter_card(str(id))
		_cards.append(card)
		%Journal.add_child(card)
	%Journal.add_child(_epilogue_entry())
	_build_wheel()
	var next_id := _next_trial()
	if next_id.is_empty():
		%NextLine.text = "ALL SEALS EARNED"
		%NextLine.add_theme_color_override("font_color", Globals.GOLD)
	else:
		var t := Story.trial(next_id)
		%NextLine.text = "NEXT: %s - %s" % [str(t.trial), str(t.seal_rule).to_upper()]
		%NextLine.add_theme_color_override("font_color", _accent(next_id))

## First trial in story order whose seal is still open ("" when all are earned).
func _next_trial() -> String:
	for id in Story.ORDER:
		if not Story.seal_earned(str(id)):
			return str(id)
	return ""

func _accent(id: String) -> Color:
	return ACCENTS.get(id, Globals.CYAN)

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _load(name: String) -> Texture2D:
	var path := name if name.begins_with("res://") else STORY_DIR + name + ".png"
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]

## A fixed-size tinted TextureRect (story art is white, tinted by modulate).
func _tex(name: String, color: Color, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _load(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _caps(text: String, px: int, color: Color = Globals.MUTED) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"CapsLabel"
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.text = text
	return l

func _body_label(text: String, px: int, color: Color = Globals.MUTED) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"MutedLabel"
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	return l

# ---------------------------------------------------------------- journal entries

func _prologue_entry() -> Control:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(Globals.GOLD, 0.25)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_caps("PROLOGUE  ·  THE STAR DOJO", 14, Globals.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_caps("WATCHED" if SaveData.story_flag("prologue_seen") else "NOT YET WATCHED", 13, Globals.DIM))
	v.add_child(head)
	var glyphs := HBoxContainer.new()
	glyphs.add_theme_constant_override("separation", 22)
	for id in Story.ORDER:
		glyphs.add_child(_tex("glyph_" + str(Story.trial(str(id)).glyph), _accent(str(id)), 34))
	v.add_child(glyphs)
	v.add_child(_body_label(Story.PROLOGUE_SUMMARY, 19))
	return p

func _chapter_card(id: String) -> Control:
	var t := Story.trial(id)
	var g := Globals.game(id)
	var accent := _accent(id)
	var earned := Story.seal_earned(id)
	var card := PanelContainer.new()
	card.theme_type_variation = &"RaisedPanel"
	# Out of the tree a variation does not resolve yet, so name the type explicitly.
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel", "RaisedPanel").duplicate()
	sb.border_color = Color(accent, 0.4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	if earned:
		sb.shadow_color = Color(Globals.GOLD, 0.08)
		sb.shadow_size = 14
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	card.add_child(h)
	h.add_child(_medallion(id, earned))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	h.add_child(col)
	col.add_child(_caps("TRIAL %s  ·  %s" % [str(t.numeral), str(t.trial)], 14, accent))
	var title := Label.new()
	title.theme_type_variation = &"DisplayLabel"
	title.add_theme_font_size_override("font_size", 26)
	title.text = str(g.get("title", id.to_upper()))
	col.add_child(title)
	col.add_child(_body_label(str(t.lore), 18))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	if earned:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var star := _tex("res://graphics/gen/icon_star.png", Globals.GOLD, 16)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(star)
		row.add_child(_caps("SEAL EARNED", 13, Globals.GOLD))
		col.add_child(row)
		var lines: Array = t.get("seal_lines", [])
		var said: String = str(lines[0].text).replace("{name}", SaveData.player_name()) if not lines.is_empty() else ""
		var seal_text := _caps(said, 14, Globals.GOLD)
		seal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(seal_text)
	else:
		var progress := Story.progress(id)
		var target := Story.seal_target(id)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = clampf(float(progress) / float(maxi(1, target)), 0.0, 1.0) * 100.0
		var fill: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
		fill.bg_color = accent
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var rule := _caps("SEAL: " + str(t.seal_rule).to_upper(), 13)
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rule)
		row.add_child(_caps("%d / %d" % [progress, target], 13, accent))
		col.add_child(row)
	var play := Button.new()
	play.text = "PLAY"
	var variation: StringName = &"MagentaButton" if str(g.get("category", "skill")) == "mind" else &"PrimaryButton"
	play.theme_type_variation = variation
	play.custom_minimum_size = Vector2(118, 44)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_font_size_override("font_size", 20)
	# Compact 44px version of the filled button (the theme's margins make it 59px).
	for style in ["normal", "hover", "pressed", "hover_pressed"]:
		var s: StyleBoxFlat = play.get_theme_stylebox(style, variation).duplicate()
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		s.content_margin_left = 24
		s.content_margin_right = 24
		play.add_theme_stylebox_override(style, s)
	play.pressed.connect(func(): AudioManager.click(); Globals.start_game(id))
	h.add_child(play)
	return card

## The 56px seal medallion: ring and glyph in gold once earned, else dim.
func _medallion(id: String, earned: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(56, 56)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = Globals.GOLD if earned else Globals.DIM
	if earned:
		var glow := _tex("res://graphics/gen/glow.png", Color(Globals.GOLD, 0.45), 88)
		glow.position = Vector2(-16, -16)
		box.add_child(glow)
	box.add_child(_tex("seal_ring", tint, 56))
	var glyph := _tex("glyph_" + str(Story.trial(id).glyph), tint, 26)
	glyph.position = Vector2(15, 15)
	box.add_child(glyph)
	return box

func _epilogue_entry() -> Control:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	if Story.all_sealed():
		sb.border_color = Color(Globals.GOLD, 0.55)
		sb.bg_color = Color(Globals.GOLD, 0.05)
		sb.shadow_color = Color(Globals.GOLD, 0.14)
		sb.shadow_size = 18
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var star := _tex("res://graphics/gen/icon_star.png", Globals.GOLD, 18)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(star)
		head.add_child(_caps("EPILOGUE  ·  THE STAR SHINES", 14, Globals.GOLD))
		v.add_child(head)
		v.add_child(_body_label(Story.EPILOGUE_SUMMARY, 19, Color("c8d0e6")))
		p.add_child(v)
	else:
		sb.border_color = Globals.LINE
		sb.bg_color = Color(Globals.BG1, 0.5)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var lock := _tex("res://graphics/gen/icon_lock.png", Globals.DIM, 30)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lock)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		v.add_child(_caps("EPILOGUE  ·  LOCKED", 14, Globals.DIM))
		v.add_child(_body_label("Earn all four seals to unlock the epilogue.", 18, Globals.DIM))
		h.add_child(v)
		p.add_child(h)
	p.add_theme_stylebox_override("panel", sb)
	return p

# ---------------------------------------------------------------- seal wheel

## Size the wheel from the viewport height so the NEXT line stays clear of the
## band Sensei's bubble occupies, growing a little on taller (iPad) screens.
func _fit_wheel() -> void:
	var s := Globals.safe_insets()
	var body_h: float = Globals.view_rect().size.y - 142.0 - float(s.top) - float(s.bottom)
	var h := clampf(body_h - CAMEO_RESERVE - 64.0, 260.0, 300.0)
	%Wheel.custom_minimum_size = Vector2(0, h)
	_wheel_radius = clampf((h - 60.0) * 0.5, 100.0, 118.0)
	_layout_wheel()

func _build_wheel() -> void:
	_clear(%Wheel)
	_wheel_glyphs.clear()
	_wheel_glows.clear()
	_center_glow = null
	var all := Story.all_sealed()
	if all:
		_center_glow = _tex("res://graphics/gen/glow.png", Color(Globals.GOLD, 0.4), 260)
		%Wheel.add_child(_center_glow)
	_ring = _tex("seal_ring", Globals.GOLD if all else Color("6b7391"), RING_PX)
	_ring.pivot_offset = Vector2(RING_PX, RING_PX) * 0.5
	%Wheel.add_child(_ring)
	_count = Label.new()
	_count.theme_type_variation = &"DisplayLabel"
	_count.add_theme_font_size_override("font_size", 40)
	_count.add_theme_color_override("font_color", Globals.GOLD if all else Globals.TEXT)
	_count.add_theme_color_override("font_outline_color", Color(Globals.GOLD, 0.35))
	_count.add_theme_constant_override("outline_size", 6)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.text = "%d / %d" % [_seals_shown, Story.ORDER.size()]
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Wheel.add_child(_count)
	_count_caps = _caps("SEALS", 13, Globals.GOLD if all else Globals.MUTED)
	_count_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Wheel.add_child(_count_caps)
	for id in Story.ORDER:
		var sid := str(id)
		var earned := Story.seal_earned(sid)
		if earned:
			var glow := _tex("res://graphics/gen/glow.png", Color(_accent(sid), 0.55), 104)
			%Wheel.add_child(glow)
			_wheel_glows[sid] = glow
		var glyph := _tex("glyph_" + str(Story.trial(sid).glyph), _accent(sid) if earned else Color(Globals.DIM, 0.9), GLYPH_PX)
		%Wheel.add_child(glyph)
		_wheel_glyphs[sid] = glyph
	_layout_wheel()

## Glyphs sit on a circle around the ring: Blade top, then clockwise in story order.
func _layout_wheel() -> void:
	var c: Vector2 = %Wheel.size * 0.5
	if is_instance_valid(_center_glow):
		_center_glow.position = c - _center_glow.size * 0.5
	if is_instance_valid(_ring):
		_ring.position = c - Vector2(RING_PX, RING_PX) * 0.5
	if is_instance_valid(_count):
		_count.size = Vector2(RING_PX, 48)
		_count.position = c - Vector2(RING_PX * 0.5, 34)
	if is_instance_valid(_count_caps):
		_count_caps.size = Vector2(RING_PX, 18)
		_count_caps.position = c + Vector2(-RING_PX * 0.5, 14)
	var n: int = Story.ORDER.size()
	for i in n:
		var sid := str(Story.ORDER[i])
		var p := c + Vector2.from_angle(-PI * 0.5 + i * TAU / float(n)) * _wheel_radius
		if _wheel_glyphs.has(sid):
			_wheel_glyphs[sid].position = p - Vector2(GLYPH_PX, GLYPH_PX) * 0.5
		if _wheel_glows.has(sid):
			var glow: TextureRect = _wheel_glows[sid]
			glow.position = p - glow.size * 0.5
	%Wheel.queue_redraw()

## The circle the glyphs sit on, with each earned quarter lit in its accent.
func _draw_wheel() -> void:
	var c: Vector2 = %Wheel.size * 0.5
	%Wheel.draw_arc(c, _wheel_radius, 0.0, TAU, 96, Color(Globals.LINE2, 0.8), 2.0, true)
	var n: int = Story.ORDER.size()
	var half := PI / float(n)
	for i in n:
		var sid := str(Story.ORDER[i])
		if Story.seal_earned(sid):
			var a := -PI * 0.5 + i * TAU / float(n)
			%Wheel.draw_arc(c, _wheel_radius, a - half + 0.1, a + half - 0.1, 40, Color(_accent(sid), 0.75), 3.0, true)

# ---------------------------------------------------------------- polish

func _enter_animation() -> void:
	var i := 0
	for c in %Journal.get_children():
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.08 + i * 0.09)
		i += 1
	%Right.modulate.a = 0.0
	create_tween().tween_property(%Right, "modulate:a", 1.0, 0.5).set_delay(0.25)

func _cameo_line() -> void:
	var n := _seals_shown
	var line := "Every journey starts with a single dodge. Begin with the Blade."
	if n >= Story.ORDER.size():
		line = "Four seals. You have finished what a hundred years began."
	elif n > 0:
		line = "%d seal%s. The star grows brighter. Which trial next?" % [n, "" if n == 1 else "s"]
	_cameo = GuideCameo.create(self, "sensei", [line], "right")
