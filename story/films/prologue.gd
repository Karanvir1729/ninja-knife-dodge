extends Film
## The prologue: Sensei Kuro and the fallen star, in seven shots. Plays on
## first launch and from the Story journal.

var _young: Mascot
var _old: Mascot
var _pip: Mascot

func film_id() -> String:
	return "prologue"

func _shots() -> Array:
	return [_shot_void, _shot_training, _shot_starfall, _shot_daggers, _shot_years, _shot_trials, _shot_title]

func _dress() -> void:
	_set_title("NINJA KNIFE DODGE", "THE FOUR TRIALS", "So he waited for a ninja. Tonight the waiting ends.",
		[["glyph_blade", Globals.CYAN], ["glyph_eye", Globals.ORANGE], ["glyph_mind", Globals.MAGENTA], ["glyph_memory", Globals.VIOLET]])

func _shot_void() -> void:
	_cam(1.06, Vector2.ZERO, 0.0)
	_cam(1.0, Vector2.ZERO, 9.0)
	await _fade(0.0, 1.2)
	var mist: Sprite2D = $Stage/Far/Mist
	_tween_alpha(mist, 0.35, 2.0)
	create_tween().tween_property(mist, "position:x", mist.position.x + 60, 6.0)
	_caption("The void came first. The dojo named it the Quiet. It unmakes things.")
	await _wait(3.6)
	_tween_alpha($Stage/Far/Torii, 0.55, 1.6)
	await _wait(1.6)
	_hint(true)
	await _wait(1.6)
	_clear_caption()

func _shot_training() -> void:
	_advance = false
	var platform: Sprite2D = $Stage/Mid/Platform
	platform.position.y += 40
	_tween_alpha(platform, 1.0, 0.8)
	create_tween().tween_property(platform, "position:y", platform.position.y - 40, 0.9).set_ease(Tween.EASE_OUT)
	for i in 2:
		_tween_alpha(_lantern(i), 1.0, 0.8)
		_tween_alpha(_lantern_glow(i), 0.55, 1.2)
	_tween_alpha($Stage/Far/Torii, 1.0, 0.8)
	_cam(1.16, Vector2(0, 30), 9.0)
	_young = MASCOT.new()
	_young.character = "young"
	_young.base_scale = 0.72
	$Stage/Actors.add_child(_young)
	var home := _home_sensei()
	_young.enter(home + Vector2(-520, 0), home, 0.2)
	_caption("The Star Dojo trained four arts against it. Kuro was the ninth master.")
	await _wait(1.4)
	_orbit.position = home + Vector2(0, -40)
	var cols := [Globals.CYAN, Globals.MAGENTA, Globals.GOLD, Globals.GREEN]
	for i in 4:
		var s := _sprite(_orbit, "res://graphics/gen/shuriken.png", Vector2.from_angle(i * TAU / 4) * 130.0, 0.0, cols[i])
		create_tween().tween_property(s, "scale", Vector2(0.3, 0.3), 0.3 * PACE).set_delay(i * 0.12 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_sprite(s, "res://graphics/gen/glow.png", Vector2.ZERO, 0.5, Color(cols[i], 0.5), true)
	AudioManager.play_sfx("whoosh", 1.1, -6.0)
	_orbit_on = true
	_young.hop(1.2)
	await _wait(2.4)
	var glyphs := ["blade", "eye", "mind", "memory"]
	var words := ["Blade.", "Eye.", "Mind.", "Name."]
	_caption("")
	%Caption.modulate.a = 1.0
	for i in 4:
		var g := _sprite($Stage/FX, "glyph_" + glyphs[i], _c + Vector2(-270 + i * 180, -250), 0.0, Globals.CYAN, true)
		g.name = "TrainGlyph%d" % i
		_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.9, Color(Globals.CYAN, 0.5), true)
		create_tween().tween_property(g, "scale", Vector2(0.55, 0.55), 0.35 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		AudioManager.play_sfx("pad_%d" % [i * 2 + 1], 1.0, -6.0)
		_caption_now(" ".join(words.slice(0, i + 1)))
		_young.hop(0.6)
		await _wait(0.55)
	_hint(true)
	await _wait(2.0)
	for i in 4:
		var g: Sprite2D = $Stage/FX.get_node("TrainGlyph%d" % i)
		create_tween().tween_property(g, "modulate:a", 0.0, 0.4).set_delay(i * 0.05)
	var ot := create_tween()
	for s in _orbit.get_children():
		ot.parallel().tween_property(s, "scale", Vector2.ZERO, 0.3)
	_clear_caption()

func _shot_starfall() -> void:
	_advance = false
	_orbit_on = false
	_young.set_facing(true)
	_young.set_mood("think")
	_caption("Then a star fell into the dojo, still burning. That had never happened.")
	_cam(1.08, Vector2(0, 40), 1.6)
	AudioManager.play_sfx("star_fall", 1.0, -4.0)
	var star := _sprite($Stage/FX, "res://graphics/gen/player_star.png", _c + Vector2(760, -520), 0.5, Globals.GOLD)
	_sprite(star, "res://graphics/gen/glow.png", Vector2.ZERO, 0.9, Color(Globals.GOLD, 0.7), true)
	var trail := CPUParticles2D.new()
	trail.amount = 50
	trail.lifetime = 0.7
	trail.texture = _t("res://graphics/gen/spark.png")
	trail.material = _add_material()
	trail.direction = Vector2(1, -1)
	trail.spread = 20.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 60.0
	trail.initial_velocity_max = 140.0
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	trail.color = Color(Globals.GOLD, 0.9)
	star.add_child(trail)
	var land := _c + Vector2(170, 70)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(star, "position:x", land.x, 1.5 * PACE)
	t.tween_property(star, "position:y", land.y, 1.5 * PACE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(star, "rotation", TAU * 1.5, 1.5 * PACE)
	await _wait(1.5)
	star.visible = false
	_flash(0.75)
	_burst(land, Globals.GOLD, 70, 420.0)
	AudioManager.play_sfx("impact")
	AudioManager.vibrate(60)
	_young.hop(1.4)
	await _wait(0.5)
	_pip = MASCOT.new()
	_pip.character = "pip"
	_pip.base_scale = 0.0
	$Stage/Actors.add_child(_pip)
	_pip.position = land + Vector2(0, -20)
	_pip.set_mood("neutral")
	var pt := create_tween()
	pt.tween_method(func(v: float): _pip.base_scale = v; _pip.scale = Vector2(v, v), 0.0, 0.62, 0.5 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await _wait(0.8)
	_young.set_facing(true)
	_hint(true)
	await _wait(2.8)
	_clear_caption()

func _shot_daggers() -> void:
	_advance = false
	_caption("The daggers came for it. Kuro stood between. That night they lost.")
	_cam(1.22, Vector2(0, 60), 2.6)
	var pip_pos: Vector2 = _pip.position
	var between := pip_pos + Vector2(-120, -10)
	var kt := create_tween()
	kt.tween_property(_young, "position", between, 0.35).set_ease(Tween.EASE_OUT)
	_young.hop(1.6)
	_young.set_mood("excited")
	var daggers: Array = []
	for i in 6:
		var d := Node2D.new()
		d.position = _c + Vector2(-380 + i * 150 + randf_range(-30, 30), 520 + i * 30)
		d.rotation = -PI / 2
		var sw := Sprite2D.new()
		sw.texture = load("res://graphics/skeleton_sword.png")
		sw.position = Vector2(40, 0)
		sw.rotation = 0.785398
		sw.scale = Vector2(1.6, 1.6)
		d.add_child(sw)
		var col: Color = Globals.RED if i % 2 == 0 else Globals.CYAN
		sw.modulate = Color(1, 1, 1, 1).lerp(col, 0.3)
		_sprite(d, "res://graphics/gen/tip_glow.png", Vector2(60, 0), 3.0, Color(col, 0.9), true)
		$Stage/FX.add_child(d)
		daggers.append(d)
	AudioManager.play_sfx("rise", 1.0, -8.0)
	for i in daggers.size():
		var d: Node2D = daggers[i]
		var target := between + Vector2(randf_range(-40, 40), randf_range(-60, 40))
		d.look_at(target)
		var dt := create_tween()
		dt.tween_property(d, "position", target, 0.9 * PACE).set_delay(i * 0.22 * PACE).set_ease(Tween.EASE_IN)
		dt.tween_callback(func():
			_burst(d.position, Globals.RED if i % 2 == 0 else Globals.CYAN, 26, 260.0)
			AudioManager.play_sfx("shatter", randf_range(0.9, 1.2), -8.0)
			d.queue_free()
			_young.hop(0.9))
	# Kuro spins as the daggers arrive
	var spin := create_tween()
	spin.tween_interval(0.8 * PACE)
	spin.tween_property(_young, "rotation", TAU, 0.7 * PACE).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(_young, "rotation", 0.0, 0.0)
	spin.tween_interval(0.5 * PACE)
	spin.tween_property(_young, "rotation", -TAU, 0.7 * PACE).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(_young, "rotation", 0.0, 0.0)
	await _wait(3.2)
	_pip.set_mood("happy")
	_young.set_mood("happy")
	_hint(true)
	await _wait(2.0)
	_clear_caption()

func _shot_years() -> void:
	_advance = false
	_caption("A hundred years. The dojo shrank. One lantern began to go out.")
	_cam(1.1, Vector2(0, 30), 6.0)
	_swirl.position = _c + Vector2(0, -40)
	for i in 28:
		var a := i * TAU / 28.0
		var r := 380.0 + (i % 3) * 60.0
		var dot := _sprite(_swirl, "res://graphics/gen/dot.png", Vector2.from_angle(a) * r, 0.0, Color(0.9, 0.93, 1.0, 0.8), true)
		create_tween().tween_property(dot, "scale", Vector2(1.6, 1.6), 0.5 * PACE).set_delay(i * 0.03 * PACE)
	_swirl_on = true
	AudioManager.play_sfx("whoosh", 0.7, -8.0)
	await _wait(1.6)
	_old = MASCOT.new()
	_old.character = "sensei"
	_old.base_scale = 0.72
	$Stage/Actors.add_child(_old)
	_old.position = _young.position
	_old.set_facing(_young.scale.x > 0)
	_old.modulate.a = 0.0
	_old.set_mood("happy")
	# One lantern begins to go out: the line in the caption, made visible.
	_tween_alpha(_lantern(0), 0.75, 1.4 * PACE)
	_tween_alpha(_lantern_glow(0), 0.36, 1.4 * PACE)
	var xf := create_tween()
	xf.set_parallel(true)
	xf.tween_property(_old, "modulate:a", 1.0, 1.4 * PACE)
	xf.tween_property(_young, "modulate:a", 0.0, 1.4 * PACE)
	var grow := create_tween()
	grow.tween_method(func(v: float): _pip.base_scale = v; _pip.scale = Vector2(v, v), 0.62, 0.74, 1.4 * PACE)
	_pip.set_mood("excited")
	await _wait(1.8)
	var st := create_tween()
	for dot in _swirl.get_children():
		st.parallel().tween_property(dot, "modulate:a", 0.0, 0.8)
	_hint(true)
	await _wait(2.6)
	_swirl_on = false
	if is_instance_valid(_young):
		_young.queue_free()
	_clear_caption()

func _shot_trials() -> void:
	_advance = false
	_caption("Four trials left. His hands are old. The second lantern goes tonight.")
	var glyphs := ["blade", "eye", "mind", "memory"]
	var accents := [Globals.CYAN, Globals.ORANGE, Globals.MAGENTA, Globals.VIOLET]
	_cam(1.0, Vector2.ZERO, 1.2)
	_tween_alpha(_lantern(1), 0.0, 0.5)
	_tween_alpha(_lantern_glow(1), 0.0, 0.5)
	create_tween().tween_property($Stage/Mid/Platform, "scale", Vector2(1.3, 1.0), 0.8).set_ease(Tween.EASE_OUT)
	var om := create_tween()
	om.tween_property(_old, "position", _c + Vector2(-330, 62), 0.6).set_ease(Tween.EASE_OUT)
	var pm := create_tween()
	pm.tween_property(_pip, "position", _c + Vector2(-195, 92), 0.6).set_ease(Tween.EASE_OUT)
	for i in 4:
		var x: float = -40.0 + i * 126.0
		var pillar := _sprite($Stage/Mid, "pillar", _c + Vector2(x, 420), 0.62, Color(1, 1, 1, 1))
		pillar.name = "Pillar%d" % i
		var slot := pillar.position + Vector2(0, -44 * 0.62 - 0)
		var g := _sprite($Stage/FX, "glyph_" + glyphs[i], slot, 0.0, accents[i], true)
		g.name = "TrialGlyph%d" % i
		_sprite(g, "res://graphics/gen/glow.png", Vector2.ZERO, 0.8, Color(accents[i], 0.55), true)
		var rise := create_tween()
		rise.tween_property(pillar, "position:y", _c.y + 70, 0.7 * PACE).set_delay(i * 0.18 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.parallel().tween_property(g, "position:y", _c.y + 70 - 44 * 0.62, 0.7 * PACE).set_delay(i * 0.18 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.tween_property(g, "scale", Vector2(0.4, 0.4), 0.3 * PACE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		rise.tween_callback(func(): AudioManager.play_sfx("pad_%d" % [i * 2 + 2], 1.0, -6.0))
	AudioManager.play_sfx("rise", 0.8, -10.0)
	await _wait(1.2)
	_old.point_at(_c + Vector2(130, 60))
	await _wait(2.4)
	_hint(true)
	await _wait(2.4)
	_old.unpoint()
	_clear_caption()
