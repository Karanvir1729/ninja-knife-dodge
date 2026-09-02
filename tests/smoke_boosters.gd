extends RefCounted
## Debug-tour smoke checks for the power-ups: Shuriken Match boosters (hint,
## +5 moves, shuffle, hammer, the out-of-moves offer), the winding level map
## with its SKIP pill, the result screen's SKIP LEVEL, and the Knife Dodge
## revive. Run through autoload/DebugTour.gd: `await runner.run(tour)`.

func run(tour) -> void:
	await _match_boosters(tour)
	await _level_map_and_skip(tour)
	await _knife_revive(tour)

func _state(tour) -> Node:
	return tour._sm().get_node("CurrentState").get_child(0)

func _find_offer(tour) -> OfferOverlay:
	for c in tour.get_tree().root.get_children():
		if c is OfferOverlay:
			return c
	return null

func _match_boosters(tour) -> void:
	await tour._go("match_play", {"level": 1})
	await tour._wait(0.8)
	var mp := _state(tour)
	var view: BoardView = mp.get_node("%Board")
	SaveData.data.boosters = {"moves": 1, "shuffle": 1, "hammer": 1, "hint": 1, "skip": 0, "revive": 1, "life": 1}
	SaveData.boosters_changed.emit()
	await tour._frames(1)
	tour._check(mp.get_node("%HintBtn").get_node("Badge").text == "1", "boosters: hint badge shows the inventory count")
	# HINT: spends one and lights up the best move right away.
	mp.get_node("%HintBtn").pressed.emit()
	await tour._frames(2)
	tour._check(SaveData.booster_count("hint") == 0, "boosters: hint booster spent (count=%d)" % SaveData.booster_count("hint"))
	tour._check(view.has_hint(), "boosters: board shows a hint after the HINT button")
	# +5 MOVES.
	var before: int = mp.moves_left
	mp.get_node("%MovesBtn").pressed.emit()
	await tour._frames(2)
	tour._check(mp.moves_left == before + 5, "boosters: +5 moves (%d -> %d)" % [before, mp.moves_left])
	tour._check(SaveData.booster_count("moves") == 0, "boosters: moves booster spent")
	# SHUFFLE: no move spent, board stays full and match-free.
	var moves_before_shuffle: int = mp.moves_left
	mp.get_node("%ShuffleBtn").pressed.emit()
	await tour._frames(1)
	await tour._wait_until(func(): return not view.busy, 6.0)
	tour._check(not view.busy, "boosters: shuffle finished")
	tour._check(view.model.count_empty() == 0 and not view.model.has_matches(), "boosters: board full with no matches after shuffle")
	tour._check(view.model.has_valid_move(), "boosters: shuffled board has a valid move")
	tour._check(mp.moves_left == moves_before_shuffle, "boosters: shuffle did not spend a move")
	# HAMMER: arm it, then smash the top-left tile through the tap path.
	mp.get_node("%HammerBtn").pressed.emit()
	await tour._frames(1)
	tour._check(view.hammer_mode, "boosters: hammer armed after the HAMMER button")
	tour._check(SaveData.booster_count("hammer") == 0, "boosters: hammer booster spent")
	var score_before: int = mp.score
	view.smash(Vector2i(0, 0))
	await tour._frames(1)
	await tour._wait_until(func(): return not view.busy, 8.0)
	await tour._frames(2)
	tour._check(not view.hammer_mode, "boosters: hammer disarmed after the smash")
	tour._check(view.model.count_empty() == 0 and not view.model.has_matches(), "boosters: board full and stable after the smash")
	tour._check(mp.score > score_before, "boosters: smash scored (%d -> %d)" % [score_before, mp.score])
	tour._check(mp.moves_left == moves_before_shuffle, "boosters: smash did not spend a move")
	tour._check(mp.get_node("%HammerBtn").get_node("Badge").text == "AD", "boosters: empty badge offers an ad")
	await tour._shot("smoke_boosters_match")
	# Out of moves below the target: the once-per-attempt +5 offer keeps the level alive.
	SaveData.data.boosters.moves = 1
	mp.moves_left = 1
	mp._update_hud()
	var mv: Array = view.model.best_move()
	tour._check(not mv.is_empty(), "boosters: a move exists for the out-of-moves check")
	if not mv.is_empty():
		view.try_swap(mv[0], mv[1])
	await tour._wait_until(func(): return _find_offer(tour) != null, 8.0)
	var offer := _find_offer(tour)
	tour._check(offer != null and offer.placement == "moves", "boosters: running out of moves offers +5 moves")
	await tour._shot("smoke_boosters_offer")
	if offer:
		offer.choose("use")
	await tour._frames(3)
	tour._check(tour._sm().current_name == "match_play" and is_instance_valid(mp) and not mp.ended and mp.moves_left == 5, "boosters: accepting the offer adds 5 moves and continues (moves=%d)" % (mp.moves_left if is_instance_valid(mp) else -1))

func _level_map_and_skip(tour) -> void:
	var next: int = SaveData.match_next_level()
	SaveData.data.match.attempts[str(next)] = 2
	await tour._go("match_levels")
	await tour._wait(0.6)
	var lv := _state(tour)
	var map: LevelMap = lv.get_node("%Map")
	tour._check(map.next_level == next, "level map: next level is %d" % next)
	tour._check(map.get_child_count() > MatchLevels.LEVEL_COUNT, "level map: one node per level plus the glow")
	var sc: ScrollContainer = lv.get_node("%Scroll")
	var node_x: float = map.level_pos(next).x - sc.scroll_horizontal
	tour._check(absf(node_x - sc.size.x * 0.5) < 80.0, "level map: next level is centred on screen (x=%.0f of %.0f)" % [node_x, sc.size.x])
	tour._check(map._skip != null, "level map: SKIP pill shown after two failed attempts")
	await tour._shot("smoke_boosters_levels")
	# Skip flow: spend a skip booster, the path advances and recentres.
	SaveData.data.boosters.skip = 1
	if map._skip:
		map._skip.pressed.emit()
	await tour._wait_until(func(): return _find_offer(tour) != null, 4.0)
	var offer := _find_offer(tour)
	tour._check(offer != null and offer.placement == "skip", "level map: SKIP pill opens the skip offer")
	if offer:
		offer.choose("use")
	await tour._wait(0.9)
	tour._check(SaveData.match_next_level() == next + 1, "level map: skip unlocks level %d" % (next + 1))
	tour._check(map.next_level == next + 1 and map._skip == null, "level map: rebuilt around the new next level")
	tour._check(int(SaveData.match_level_info(next).stars) == 1, "level map: skipped level holds one star")
	tour._check(SaveData.booster_count("skip") == 0, "level map: skip booster spent")
	await tour._shot("smoke_boosters_levels_skipped")
	# Result screen after a second failure offers SKIP LEVEL.
	SaveData.data.match.attempts[str(next + 1)] = 1
	await tour._go("match_result", {"level": next + 1, "score": 900, "cleared": false, "moves_left": 0, "bonus": 0, "stars": 0, "target": 3000})
	await tour._wait(1.0)
	var rs := _state(tour)
	tour._check(rs.get_node("%SkipBtn").visible, "result: SKIP LEVEL shown after two failed attempts")
	await tour._shot("smoke_boosters_result_skip")
	SaveData.data.match.attempts.erase(str(next + 1))

func _knife_revive(tour) -> void:
	await tour._go("play")
	SaveData.data.boosters.revive = 1
	var play := _state(tour)
	await tour._wait(0.3)
	play.game_over()
	await tour._wait_until(func(): return _find_offer(tour) != null, 4.0)
	var offer := _find_offer(tour)
	tour._check(offer != null and offer.placement == "revive", "revive: offer overlay opened after death")
	await tour._shot("smoke_boosters_revive")
	if offer:
		offer.choose("use")
	await tour._frames(3)
	tour._check(tour._sm().current_name == "play", "revive: still playing after the revive (state=%s)" % tour._sm().current_name)
	tour._check(is_instance_valid(play) and not play.dead, "revive: dead flag reset")
	tour._check(is_instance_valid(play) and play.revived_this_run, "revive: one revive per run recorded")
	tour._check(is_instance_valid(play) and play.get_node("%Player").invulnerable, "revive: star is invulnerable right after the revive")
	tour._check(SaveData.booster_count("revive") == 0, "revive: booster spent")
	await tour._wait(2.5)
	if is_instance_valid(play) and tour._sm().current_name == "play":
		play.game_over()
	await tour._wait_until(func(): return tour._sm().current_name == "lose", 3.0)
	tour._check(tour._sm().current_name == "lose", "revive: second death goes to results (state=%s)" % tour._sm().current_name)
