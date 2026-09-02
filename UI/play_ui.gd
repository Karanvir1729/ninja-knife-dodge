extends CanvasLayer
## Knife Dodge heads-up display.

signal pause_pressed

var _wave_tween: Tween

func _ready() -> void:
	Globals.apply_safe_margins(%Root, 28)
	get_viewport().size_changed.connect(func(): Globals.apply_safe_margins(%Root, 28))
	%WaveBanner.modulate.a = 0.0
	%PauseBtn.pressed.connect(func(): pause_pressed.emit())
	%Streak.visible = false
	var s := Globals.safe_insets()
	%Progress.offset_top = -6 - s.bottom
	%Progress.offset_bottom = -s.bottom

func set_score(n: int) -> void:
	%Score.text = Globals.pad_score(n)

func set_best(n: int) -> void:
	%BestVal.text = str(n)

func set_time(sec: float) -> void:
	%TimeVal.text = Globals.format_time(sec)

func set_streak(n: int) -> void:
	%Streak.visible = n >= 2
	%StreakVal.text = "x%d" % n
	if n >= 2:
		%StreakVal.scale = Vector2(1.4, 1.4)
		create_tween().tween_property(%StreakVal, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)

func set_progress(ratio: float) -> void:
	%Progress.value = clampf(ratio, 0.0, 1.0) * 100.0

func show_wave(index: int, wave_name: String, color: Color) -> void:
	%WaveCaps.text = "WAVE %d" % index
	%WaveCaps.add_theme_color_override("font_color", color)
	%WaveName.text = wave_name
	var sb: StyleBoxFlat = %WaveBanner.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(color, 0.6)
	sb.shadow_color = Color(color, 0.2)
	%WaveBanner.add_theme_stylebox_override("panel", sb)
	if _wave_tween and _wave_tween.is_valid():
		_wave_tween.kill()
	%WaveBanner.modulate.a = 0.0
	%WaveBanner.scale = Vector2(0.9, 0.9)
	%WaveBanner.pivot_offset = %WaveBanner.size * 0.5
	_wave_tween = create_tween()
	_wave_tween.set_parallel(true)
	_wave_tween.tween_property(%WaveBanner, "modulate:a", 1.0, 0.25)
	_wave_tween.tween_property(%WaveBanner, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_wave_tween.chain().tween_interval(2.2)
	_wave_tween.chain().tween_property(%WaveBanner, "modulate:a", 0.0, 0.4)

## Floating score text at a world position (world == screen here: no camera).
func popup(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.theme_type_variation = &"NumberLabel"
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_outline_color", Color(color, 0.35))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 5
	%Popups.add_child(l)
	l.position = at - Vector2(60, 40)
	l.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "modulate:a", 1.0, 0.12)
	t.tween_property(l, "position:y", l.position.y - 46, 0.9).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(l.queue_free)
