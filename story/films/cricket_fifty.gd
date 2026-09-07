extends "res://story/films/cricket.gd"
## The Yard's goal film: fifty in one innings. Pip takes the scorebook to the
## team and tells them a ninja did it. Plays once, on the hub, after the score.

func film_id() -> String:
	return "cricket_fifty"

func _shots() -> Array:
	return [_shot_fifty, _shot_told, _shot_nod, _shot_title]

func _dress() -> void:
	_set_title("STAR CRICKET", "FIFTY", "They might finally listen.", [["glyph_ball", Globals.GOLD]])

func _shot_fifty() -> void:
	_place_yard()
	_field.set_fielders([1, 2, 3])
	_cam(YARD_K, Vector2(-YARD_X * YARD_K, 16.0), 0.0)
	_cam(1.0, Vector2(-YARD_X, 30.0), 10.0)
	await _fade(0.0, 1.0)
	var fifty := _label("50", Vector2(_field.cx, _field.top_y - 90.0), 72, Globals.GOLD, 300.0)
	fifty.add_theme_font_size_override("font_size", 72)
	fifty.scale = Vector2(0.2, 0.2)
	fifty.pivot_offset = fifty.size * 0.5
	create_tween().tween_property(fifty, "scale", Vector2.ONE, 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("record", 1.0, -4.0)
	_burst(Vector2(_field.cx, _field.top_y - 90.0), Globals.GOLD, 50, 340.0)
	_caption("Fifty. In one innings. Out here, where the void does the bowling.")
	_pip.set_mood("excited")
	await _wait(3.2)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_told() -> void:
	_advance = false
	_caption("Pip went straight to the team with the scorebook.")
	var to := Vector2(_field.cx - 400.0, _field.crease_y - 60.0)
	_pip.set_facing(false)
	var pt := create_tween()
	pt.tween_property(_pip, "position", to, 0.9 * PACE).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await _wait(1.0)
	_book = _sprite($Stage/FX, "scorebook", to + Vector2(70.0, -110.0), 0.0)
	create_tween().tween_property(_book, "scale", Vector2(0.9, 0.9), 0.4 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("shuffle", 1.1, -12.0)
	await _wait(1.6)
	_caption("\"A ninja did it,\" Pip told them. They wrote it down.")
	await _wait(1.2)
	_cheer(1.0)
	AudioManager.play_sfx("level_win", 1.0, -10.0)
	_hint(true)
	await _wait(3.0)
	_clear_caption()

func _shot_nod() -> void:
	_advance = false
	_caption("Kuro said nothing. He does not do miracles. He allowed himself one nod.")
	_cam(1.12, Vector2(-YARD_X * 1.12, 60.0), 4.0)
	await _wait(2.4)
	_old.set_mood("happy")
	_old.hop(0.35)
	AudioManager.play_sfx("pad_4", 1.0, -8.0)
	_hint(true)
	await _wait(2.4)
	_clear_caption()
