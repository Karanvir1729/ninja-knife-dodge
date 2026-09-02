extends Node
## Local-only persistence: profile, settings, tutorial flags, stats and the two
## leaderboards. Everything lives in user://save.json and never leaves the device.

signal settings_changed
signal data_reset

const SAVE_PATH := "user://save.json"
const BOARD_SIZE := 10
const MAX_NAME_LENGTH := 10
const DEFAULT_NAME := "NINJA"

var data: Dictionary = {}
## When true (debug tour), nothing is written to disk.
var read_only := false

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"version": 2,
		"profile": {"name": DEFAULT_NAME},
		"settings": {"music": true, "music_volume": 0.8, "sfx": true, "sfx_volume": 1.0, "haptics": true},
		"tutorials": {"knife": false, "match": false},
		"knife": {"best": 0, "runs": 0, "total_dodged": 0, "near_misses": 0, "time_played": 0.0, "best_wave": 0, "board": []},
		"match": {"next_level": 1, "games": 0, "total_stars": 0, "levels": {}, "board": []},
	}

func load_data() -> void:
	data = _defaults()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				_merge(data, parsed)
	else:
		_migrate_legacy()
		save()

## Deep-merge saved values over the defaults so new keys always exist.
func _merge(base: Dictionary, over: Dictionary) -> void:
	for k in over.keys():
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary:
			_merge(base[k], over[k])
		else:
			base[k] = over[k]

## v1 stored a raw high score and a tutorial flag as bare files.
func _migrate_legacy() -> void:
	if FileAccess.file_exists("user://high_score"):
		var f := FileAccess.open("user://high_score", FileAccess.READ)
		if f:
			var best := int(f.get_32())
			f.close()
			if best > 0:
				data.knife.best = best
				data.knife.runs = 1
				data.knife.total_dodged = best
				data.knife.board.append(_entry(DEFAULT_NAME, best, {"wave": 0, "time": 0.0}))
	if FileAccess.file_exists("user://tutorial_done"):
		data.tutorials.knife = true

func save() -> void:
	if read_only:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

# ---------------------------------------------------------------- profile / settings

func player_name() -> String:
	return str(data.profile.get("name", DEFAULT_NAME))

func set_player_name(n: String) -> void:
	n = n.strip_edges().to_upper().substr(0, MAX_NAME_LENGTH)
	if n.is_empty():
		n = DEFAULT_NAME
	data.profile.name = n
	save()

func setting(key: String):
	return data.settings.get(key)

func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save()
	settings_changed.emit()

func tutorial_done(game: String) -> bool:
	return bool(data.tutorials.get(game, false))

func set_tutorial_done(game: String, done: bool = true) -> void:
	data.tutorials[game] = done
	save()

func reset_tutorials() -> void:
	data.tutorials = {"knife": false, "match": false}
	save()

# ---------------------------------------------------------------- leaderboards

func _entry(pname: String, score: int, extra: Dictionary) -> Dictionary:
	var e := {"name": pname, "score": score, "date": Time.get_date_string_from_system()}
	for k in extra.keys():
		e[k] = extra[k]
	return e

## Insert into a board sorted by score desc. Returns 1-based rank or 0 if it missed the board.
func _insert(board: Array, entry: Dictionary) -> int:
	var rank := 0
	var idx := board.size()
	for i in range(board.size()):
		if entry.score > int(board[i].score):
			idx = i
			break
	board.insert(idx, entry)
	if board.size() > BOARD_SIZE:
		board.resize(BOARD_SIZE)
	if idx < BOARD_SIZE:
		rank = idx + 1
	return rank

func knife_board() -> Array:
	return data.knife.board

func match_board() -> Array:
	return data.match.board

## Record a Knife Dodge run. Returns {rank, new_record}.
func record_knife_run(score: int, wave: int, time_sec: float, near_misses: int) -> Dictionary:
	var k: Dictionary = data.knife
	var new_record := score > int(k.best)
	k.best = maxi(int(k.best), score)
	k.runs = int(k.runs) + 1
	k.total_dodged = int(k.total_dodged) + score
	k.near_misses = int(k.near_misses) + near_misses
	k.time_played = float(k.time_played) + time_sec
	k.best_wave = maxi(int(k.best_wave), wave)
	var rank := 0
	if score > 0:
		rank = _insert(k.board, _entry(player_name(), score, {"wave": wave, "time": time_sec, "near": near_misses}))
	save()
	return {"rank": rank, "new_record": new_record}

## Record a Shuriken Match level attempt. Returns {rank, new_best, unlocked_next}.
func record_match_result(level: int, score: int, stars: int, cleared: bool) -> Dictionary:
	var m: Dictionary = data.match
	m.games = int(m.games) + 1
	var key := str(level)
	var prev: Dictionary = m.levels.get(key, {"stars": 0, "best": 0})
	var new_best := score > int(prev.best)
	var entry := {"stars": maxi(int(prev.stars), stars if cleared else 0), "best": maxi(int(prev.best), score)}
	m.levels[key] = entry
	var unlocked := false
	if cleared and level >= int(m.next_level):
		m.next_level = level + 1
		unlocked = true
	var total := 0
	for lk in m.levels.keys():
		total += int(m.levels[lk].stars)
	m.total_stars = total
	var rank := 0
	if score > 0:
		rank = _insert(m.board, _entry(player_name(), score, {"level": level, "stars": stars}))
	save()
	return {"rank": rank, "new_best": new_best, "unlocked_next": unlocked}

func match_level_info(level: int) -> Dictionary:
	return data.match.levels.get(str(level), {"stars": 0, "best": 0})

func match_next_level() -> int:
	return int(data.match.next_level)

func match_total_stars() -> int:
	return int(data.match.total_stars)

func knife_stats() -> Dictionary:
	return data.knife

func match_stats() -> Dictionary:
	return data.match

func reset_all() -> void:
	var name_keep := player_name()
	var settings_keep: Dictionary = data.settings.duplicate()
	data = _defaults()
	data.profile.name = name_keep
	data.settings = settings_keep
	save()
	data_reset.emit()
