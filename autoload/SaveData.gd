extends Node
## Local-only persistence: profile, settings, tutorial flags, per-game stats and
## leaderboards, booster inventory and guide state. Everything lives in
## user://save.json and never leaves the device.

signal settings_changed
signal data_reset
signal boosters_changed

const SAVE_PATH := "user://save.json"
const BOARD_SIZE := 10
const MAX_NAME_LENGTH := 10
const DEFAULT_NAME := "NINJA"
## Starter booster gift so players can try every power-up once before any ad.
const DEFAULT_BOOSTERS := {"moves": 1, "shuffle": 1, "hammer": 1, "hint": 3, "skip": 0, "revive": 1, "life": 1}

var data: Dictionary = {}
## When true (debug tour), nothing is written to disk.
var read_only := false

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"version": 3,
		"profile": {"name": DEFAULT_NAME},
		"settings": {"music": true, "music_volume": 0.8, "sfx": true, "sfx_volume": 1.0, "haptics": true},
		"tutorials": {},
		"guides": {"intro_seen": false, "launches": 0},
		"story": {"prologue_seen": false, "epilogue_seen": false, "celebrated": {}},
		"boosters": DEFAULT_BOOSTERS.duplicate(),
		"knife": {"best": 0, "runs": 0, "total_dodged": 0, "near_misses": 0, "time_played": 0.0, "best_wave": 0, "board": []},
		"match": {"next_level": 1, "games": 0, "total_stars": 0, "levels": {}, "board": [], "attempts": {}},
		"games": {},
	}

func _game_defaults() -> Dictionary:
	return {"best": 0, "plays": 0, "total": 0, "time": 0.0, "board": []}

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
		data.tutorials["knife"] = true

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
	data.tutorials = {}
	save()

# ---------------------------------------------------------------- guides

func intro_seen() -> bool:
	return bool(data.guides.get("intro_seen", false))

func set_intro_seen(seen: bool = true) -> void:
	data.guides.intro_seen = seen
	save()

func launches() -> int:
	return int(data.guides.get("launches", 0))

func mark_launch() -> void:
	data.guides.launches = launches() + 1
	save()

# ---------------------------------------------------------------- story

func story_flag(key: String) -> bool:
	return bool(data.story.get(key, false))

func set_story_flag(key: String, value: bool = true) -> void:
	data.story[key] = value
	save()

func seal_celebrated(id: String) -> bool:
	return bool(data.story.celebrated.get(id, false))

func set_seal_celebrated(id: String) -> void:
	data.story.celebrated[id] = true
	save()

# ---------------------------------------------------------------- boosters

func booster_count(kind: String) -> int:
	return int(data.boosters.get(kind, 0))

func add_booster(kind: String, n: int = 1) -> void:
	data.boosters[kind] = booster_count(kind) + n
	save()
	boosters_changed.emit()

## Spend one booster. Returns false if none are left.
func use_booster(kind: String) -> bool:
	if booster_count(kind) <= 0:
		return false
	data.boosters[kind] = booster_count(kind) - 1
	save()
	boosters_changed.emit()
	return true

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

## Leaderboard for any game id.
func game_board(id: String) -> Array:
	match id:
		"knife": return data.knife.board
		"match": return data.match.board
		_: return game_stats(id).board

## Generic per-game stats block (created on demand).
func game_stats(id: String) -> Dictionary:
	if not data.games.has(id):
		data.games[id] = _game_defaults()
	return data.games[id]

## Record a score for a generic game. `extra` is stored on the board entry
## (use "detail" for the leaderboard's right-hand text). Returns {rank, new_record}.
func record_game_score(id: String, score: int, extra: Dictionary = {}, time_sec: float = 0.0) -> Dictionary:
	var g := game_stats(id)
	var new_record := score > int(g.best)
	g.best = maxi(int(g.best), score)
	g.plays = int(g.plays) + 1
	g.total = int(g.total) + score
	g.time = float(g.time) + time_sec
	var rank := 0
	if score > 0:
		rank = _insert(g.board, _entry(player_name(), score, extra))
	save()
	return {"rank": rank, "new_record": new_record}

## The headline number for a game on the menu (see Globals.GAMES stat_label).
func best_for(id: String) -> int:
	match id:
		"knife": return int(data.knife.best)
		"match": return maxi(1, int(data.match.next_level))
		_: return int(game_stats(id).best)

func plays_for(id: String) -> int:
	match id:
		"knife": return int(data.knife.runs)
		"match": return int(data.match.games)
		_: return int(game_stats(id).plays)

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
	if cleared:
		m.attempts.erase(key)
	else:
		m.attempts[key] = int(m.attempts.get(key, 0)) + 1
	var total := 0
	for lk in m.levels.keys():
		total += int(m.levels[lk].stars)
	m.total_stars = total
	var rank := 0
	if score > 0:
		rank = _insert(m.board, _entry(player_name(), score, {"level": level, "stars": stars}))
	save()
	return {"rank": rank, "new_best": new_best, "unlocked_next": unlocked}

## Consecutive failed attempts on a level (reset when it is cleared).
func match_attempts(level: int) -> int:
	return int(data.match.attempts.get(str(level), 0))

## Skip a level (booster or ad): marks it cleared with one star and unlocks the next.
func skip_match_level(level: int) -> void:
	var m: Dictionary = data.match
	var key := str(level)
	var prev: Dictionary = m.levels.get(key, {"stars": 0, "best": 0})
	m.levels[key] = {"stars": maxi(int(prev.stars), 1), "best": int(prev.best), "skipped": true}
	if level >= int(m.next_level):
		m.next_level = level + 1
	m.attempts.erase(key)
	var total := 0
	for lk in m.levels.keys():
		total += int(m.levels[lk].stars)
	m.total_stars = total
	save()

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
	boosters_changed.emit()
