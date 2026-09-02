extends Node
## Development helper, inert unless launched with:
##   godot --path . -- --tour=/abs/output/dir [--quick]
## Walks every screen at three aspect ratios (16:9, iPhone 19.5:9, iPad 4:3),
## saves PNG screenshots, runs functional smoke checks on both games and prints
## PASS/FAIL lines. Uses in-memory sample data only (nothing is saved to disk).

var out_dir := ""
var quick := false
var check_only := false
var _fails := 0
var _checks := 0
var _scale := 1.0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			out_dir = arg.trim_prefix("--tour=")
		if arg == "--quick":
			quick = true
		if arg == "--check":
			check_only = true
	if check_only:
		call_deferred("_check_all")
		return
	if out_dir.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveData.read_only = true
	_seed_sample_data()
	call_deferred("_run")

func _seed_sample_data() -> void:
	SaveData.set_player_name("KARANVIR")
	for row in [[142, 9, 171.0, 30], [118, 8, 140.0, 22], [87, 6, 102.0, 12], [64, 5, 70.0, 9], [41, 4, 55.0, 6], [23, 3, 31.0, 2]]:
		SaveData.record_knife_run(row[0], row[1], row[2], row[3])
	for lv in range(1, 7):
		SaveData.record_match_result(lv, 2000 + lv * 900, 3 if lv % 2 == 1 else 2, true)
	SaveData.set_tutorial_done("knife", true)
	SaveData.set_tutorial_done("match", true)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func _sm() -> Node:
	return get_tree().get_first_node_in_group("currentState")

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("PASS  ", msg)
	else:
		_fails += 1
		print("FAIL  ", msg)

func _shot(name: String) -> void:
	await _frames(2)
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT  ", path, "  ", img.get_size())

func _go(state: String, params: Dictionary = {}) -> void:
	await _wait_until(func(): return not _sm().is_busy(), 5.0)
	await _sm().change(state, params)
	await _wait_until(func(): return not _sm().is_busy(), 5.0)
	await _frames(2)

func _run() -> void:
	await _frames(3)
	var screen := DisplayServer.screen_get_size()
	_scale = minf(1.0, (screen.y - 140.0) / 1056.0)
	print("TOUR  screen ", screen, " window scale ", _scale)
	var presets := [["16x9", 1408, 792], ["iphone", 1712, 792], ["ipad", 1408, 1056]]
	if quick:
		presets = [["16x9", 1408, 792]]
	for preset in presets:
		var tag: String = preset[0]
		DisplayServer.window_set_size(Vector2i(int(preset[1] * _scale), int(preset[2] * _scale)))
		await _frames(4)
		var vr := Globals.view_rect()
		print("TOUR  preset ", tag, " visible rect ", vr)
		_check(absf(vr.size.aspect() - float(preset[1]) / preset[2]) < 0.02, "%s: viewport aspect matches window (%.2f)" % [tag, vr.size.aspect()])
		await _go("start")
		await _wait(0.6)
		await _shot("%s_01_menu" % tag)
		var start := _sm().get_node("CurrentState").get_child(0)
		start.get_node("%HowTo").visible = true
		await _shot("%s_02_howto" % tag)
		start.get_node("%HowTo").visible = false
		await _go("leaderboard", {"tab": "knife"})
		await _wait(0.3)
		await _shot("%s_03_leaderboard_knife" % tag)
		_sm().get_node("CurrentState").get_child(0)._select("match", true)
		await _frames(2)
		await _shot("%s_04_leaderboard_match" % tag)
		await _go("settings")
		await _wait(0.3)
		await _shot("%s_05_settings" % tag)
		var settings := _sm().get_node("CurrentState").get_child(0)
		settings._show(settings.get_node("%Confirm"), true)
		await _wait(0.25)
		await _shot("%s_06_settings_confirm" % tag)
		settings._show(settings.get_node("%Confirm"), false)
		settings._info("PRIVACY", settings.PRIVACY_TEXT)
		await _wait(0.25)
		await _shot("%s_07_settings_privacy" % tag)
		await _go("tutorial")
		await _wait(0.5)
		await _shot("%s_08_knife_tutorial" % tag)
		await _go("play")
		var play := _sm().get_node("CurrentState").get_child(0)
		await _keep_alive(play, 2.8)
		await _shot("%s_09_knife_play" % tag)
		play.toggle_pause()
		await _wait(0.3)
		await _shot("%s_10_knife_paused" % tag)
		play.toggle_pause()
		await _go("lose", {"score": 87, "wave": 6, "time": 102.0, "near": 12, "dodged": 75})
		await _wait(1.4)
		await _shot("%s_11_knife_results" % tag)
		await _go("match_levels")
		await _wait(0.5)
		await _shot("%s_12_match_levels" % tag)
		await _go("match_tutorial")
		await _wait(0.6)
		await _shot("%s_13_match_tutorial" % tag)
		await _go("match_play", {"level": 7})
		await _wait(0.9)
		await _shot("%s_14_match_play" % tag)
		var mp := _sm().get_node("CurrentState").get_child(0)
		mp.toggle_pause()
		await _wait(0.3)
		await _shot("%s_15_match_paused" % tag)
		mp.toggle_pause()
		await _go("match_result", {"level": 7, "score": 5860, "cleared": true, "moves_left": 3, "bonus": 300, "stars": 2, "target": 5000})
		await _wait(1.6)
		await _shot("%s_16_match_result" % tag)
		await _go("match_result", {"level": 7, "score": 3100, "cleared": false, "moves_left": 0, "bonus": 0, "stars": 0, "target": 5000})
		await _wait(1.2)
		await _shot("%s_17_match_failed" % tag)
	await _smoke()
	print("TOUR  done: %d checks, %d failures" % [_checks, _fails])
	await _frames(2)
	get_tree().quit(1 if _fails > 0 else 0)

## Functional checks that exercise real gameplay code paths.
func _smoke() -> void:
	DisplayServer.window_set_size(Vector2i(int(1408 * _scale), int(792 * _scale)))
	await _frames(3)
	# --- Shuriken Match: play real moves through the view with the greedy bot.
	await _go("match_play", {"level": 2})
	await _wait(0.8)
	var mp := _sm().get_node("CurrentState").get_child(0)
	var view: BoardView = mp.get_node("%Board")
	var moves_before: int = mp.moves_left
	var score_before: int = mp.score
	var played := 0
	for i in 6:
		if not is_instance_valid(view) or _sm().current_name != "match_play":
			break
		if view.busy:
			await _wait(0.2)
		var mv: Array = view.model.best_move()
		if mv.is_empty():
			break
		view.try_swap(mv[0], mv[1])
		var t0 := Time.get_ticks_msec()
		while is_instance_valid(view) and view.busy and Time.get_ticks_msec() - t0 < 8000:
			await _frames(1)
		played += 1
	_check(played >= 3, "match: bot played %d moves through the board view" % played)
	var ended_early: bool = not is_instance_valid(view) or _sm().current_name != "match_play"
	if ended_early:
		await _wait(1.5)
		_check(_sm().current_name == "match_result", "match: level auto-finished with 3 stars and reached the result screen (state=%s)" % _sm().current_name)
		await _shot("smoke_match_result")
	else:
		_check(mp.moves_left == moves_before - played, "match: moves decremented (%d -> %d)" % [moves_before, mp.moves_left])
		_check(mp.score > score_before, "match: score increased to %d" % mp.score)
		_check(view.model.count_empty() == 0 and not view.model.has_matches(), "match: board full and stable after moves")
		await _shot("smoke_match_after_moves")
		# Drain the remaining moves quickly to reach the result screen.
		var guard := 0
		while _sm().current_name == "match_play" and guard < 40 and is_instance_valid(view):
			guard += 1
			if not view.busy:
				var mv: Array = view.model.best_move()
				if mv.is_empty():
					break
				view.try_swap(mv[0], mv[1])
			var t0 := Time.get_ticks_msec()
			while is_instance_valid(view) and view.busy and Time.get_ticks_msec() - t0 < 8000:
				await _frames(1)
			await _frames(2)
		await _wait(1.5)
		_check(_sm().current_name == "match_result", "match: level ends on the result screen (state=%s)" % _sm().current_name)
		await _shot("smoke_match_result")
	# --- Knife Dodge: run, then die, and land on the results screen with stats recorded.
	var runs_before := int(SaveData.knife_stats().runs)
	await _go("play")
	var play := _sm().get_node("CurrentState").get_child(0)
	var y0: float = play.get_node("%Player").position.y
	await _keep_alive(play, 3.0)
	var knives: int = play.get_node("%Knives").get_child_count()
	_check(knives > 0, "knife: spawner produced daggers (%d)" % knives)
	_check(not play.dead, "knife: simulated taps kept the star alive for 3s")
	_check(play.elapsed > 2.5, "knife: run timer advanced (%.1fs)" % play.elapsed)
	play.game_over()
	await _wait(2.0)
	_check(_sm().current_name == "lose", "knife: death leads to results (state=%s)" % _sm().current_name)
	_check(int(SaveData.knife_stats().runs) == runs_before + 1, "knife: run recorded in stats")
	# --- Shuriken Match tutorial: walk every scripted step to the level.
	await _go("match_tutorial", {"level": 1})
	await _wait(0.6)
	var tut := _sm().get_node("CurrentState").get_child(0)
	var tview: BoardView = tut.get_node("%Board")
	_check(tut.step == 0 and tview.allowed_move.size() == 2, "match tutorial: step 1 armed with a single allowed move")
	tview.try_swap(tview.allowed_move[0], tview.allowed_move[1])
	await _wait_until(func(): return tut.step == 1, 6.0)
	_check(tut.step == 1, "match tutorial: three-in-a-row advances to step 2 (step=%d)" % tut.step)
	await _wait(0.4)
	if tut.step == 1 and tview.allowed_move.size() == 2:
		tview.try_swap(tview.allowed_move[0], tview.allowed_move[1])
	await _wait_until(func(): return tut.step == 2, 8.0)
	_check(tut.step == 2, "match tutorial: forging a Line advances to step 3 (step=%d)" % tut.step)
	await _shot("smoke_match_tutorial_step3")
	await _wait(0.4)
	if tut.step == 2 and tview.allowed_move.size() == 2:
		tview.try_swap(tview.allowed_move[0], tview.allowed_move[1])
	await _wait_until(func(): return tut.step == 3, 8.0)
	_check(tut.step == 3, "match tutorial: firing the Line advances to step 4 (step=%d)" % tut.step)
	tut.get_node("%Next").pressed.emit()
	await _wait_until(func(): return _sm().current_name == "match_play", 4.0)
	_check(_sm().current_name == "match_play", "match tutorial: finishes into level 1 (state=%s)" % _sm().current_name)
	# --- Knife Dodge tutorial: tap the helper through all four steps.
	await _go("tutorial")
	await _wait(0.5)
	var kt := _sm().get_node("CurrentState").get_child(0)
	for expected in [1, 2, 3]:
		_click(kt.get_node("helper").global_position)
		await _wait_until(func(): return kt.step == expected, 4.0)
		_check(kt.step == expected, "knife tutorial: helper tap advances to step %d (step=%d)" % [expected + 1, kt.step])
	await _wait_until(func(): return _sm().current_name == "play", 4.0)
	_check(_sm().current_name == "play", "knife tutorial: finishes into a real run (state=%s)" % _sm().current_name)
	# --- Save round-trip (in memory) and settings.
	SaveData.set_setting("music_volume", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) < 0.01, "audio: music volume setting applied to bus")
	SaveData.set_setting("music_volume", 0.8)

## `-- --check`: load every script and scene (autoloads present) and quit.
func _check_all() -> void:
	await get_tree().process_frame
	var files := []
	_walk("res://", files)
	files.sort()
	var failures := 0
	for f in files:
		var r = load(f)
		if r == null:
			failures += 1
			printerr("LOAD FAIL ", f)
		elif f.ends_with(".tscn"):
			var inst = (r as PackedScene).instantiate()
			if inst == null:
				failures += 1
				printerr("INSTANTIATE FAIL ", f)
			else:
				inst.free()
	print("CHECK: %d files, %d failure(s)" % [files.size(), failures])
	get_tree().quit(1 if failures > 0 else 0)

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.begins_with(".") or n == "addons" or dir.path_join(n) == "res://tests":
			n = d.get_next()
			continue
		var path := dir.path_join(n)
		if d.current_is_dir():
			_walk(path, out)
		elif n.ends_with(".gd") or n.ends_with(".tscn") or n.ends_with(".tres"):
			out.append(path)
		n = d.get_next()
	d.list_dir_end()

## Simulate taps just below the star every 0.55s so it keeps bouncing.
func _keep_alive(play: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(play) and not play.dead:
		var p: Vector2 = play.get_node("%Player").position + Vector2(randf_range(-30, 30), 70)
		_click(p)
		await _wait(0.55)
		t += 0.55

func _click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)

func _wait_until(pred: Callable, timeout_sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not pred.call() and Time.get_ticks_msec() - t0 < timeout_sec * 1000.0:
		await _frames(1)
