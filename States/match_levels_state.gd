extends CanvasLayer
## Shuriken Match level select: continue where you left off, or replay any
## unlocked level for a better star rating.

const TILE := 104

func init(_p: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	%Back.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	var next := mini(SaveData.match_next_level(), MatchLevels.LEVEL_COUNT)
	%ContinueBtn.text = "CONTINUE  ·  LEVEL %d" % next if next > 1 else "START  ·  LEVEL 1"
	%ContinueBtn.pressed.connect(func(): _play(next))
	%StarsVal.text = "%d / %d" % [SaveData.match_total_stars(), MatchLevels.LEVEL_COUNT * 3]
	var p := MatchLevels.params(next)
	%NextInfo.text = "TARGET %s  ·  %d MOVES  ·  %d COLOURS" % [Globals.format_number(int(p.target)), int(p.moves), int(p.colors)]
	_build_grid(next)

func _play(level: int) -> void:
	AudioManager.click()
	if SaveData.tutorial_done("match"):
		Globals.go("match_play", {"level": level})
	else:
		Globals.go("match_tutorial", {"level": level})

func _build_grid(next: int) -> void:
	for c in %Grid.get_children():
		c.queue_free()
	var star_tex: Texture2D = load("res://graphics/gen/icon_star.png")
	var lock_tex: Texture2D = load("res://graphics/gen/icon_lock.png")
	for lv in range(1, MatchLevels.LEVEL_COUNT + 1):
		var info := SaveData.match_level_info(lv)
		var stars := int(info.stars)
		var unlocked := lv <= next
		var is_next := lv == next
		var b := Button.new()
		b.custom_minimum_size = Vector2(TILE, TILE)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Globals.BG2, 1.0) if unlocked else Color(Globals.BG1, 0.6)
		sb.set_border_width_all(1)
		sb.border_color = Globals.MAGENTA if is_next else (Color(Globals.GOLD, 0.45) if stars == 3 else Globals.LINE)
		sb.set_corner_radius_all(14)
		if is_next:
			sb.shadow_color = Color(Globals.MAGENTA, 0.25)
			sb.shadow_size = 16
		var sbp: StyleBoxFlat = sb.duplicate()
		sbp.bg_color = Color(Globals.MAGENTA, 0.18)
		sbp.border_color = Globals.MAGENTA
		for s in ["normal", "hover", "disabled", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_stylebox_override("pressed", sbp)
		b.add_theme_stylebox_override("hover_pressed", sbp)
		b.disabled = not unlocked
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		b.add_child(v)
		if unlocked:
			var n := Label.new()
			n.theme_type_variation = &"DisplayLabel"
			n.add_theme_font_size_override("font_size", 34)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.text = str(lv)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if is_next:
				n.add_theme_color_override("font_color", Globals.MAGENTA)
			v.add_child(n)
			var h := HBoxContainer.new()
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			h.add_theme_constant_override("separation", 2)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for i in 3:
				var st := TextureRect.new()
				st.texture = star_tex
				st.custom_minimum_size = Vector2(16, 16)
				st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				st.modulate = Globals.GOLD if i < stars else Globals.LINE2
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				h.add_child(st)
			v.add_child(h)
			b.pressed.connect(func(): _play(lv))
		else:
			var lk := TextureRect.new()
			lk.texture = lock_tex
			lk.custom_minimum_size = Vector2(26, 26)
			lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lk.modulate = Globals.DIM
			lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(lk)
			var n := Label.new()
			n.theme_type_variation = &"CapsLabel"
			n.add_theme_font_size_override("font_size", 15)
			n.add_theme_color_override("font_color", Globals.DIM)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.text = str(lv)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(n)
		%Grid.add_child(b)
