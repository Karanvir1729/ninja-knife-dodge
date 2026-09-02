extends SceneTree
## Headless unit tests + level-curve tuning bot for the Shuriken Match model.
## Run: godot --headless --path . -s tests/test_board.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		printerr("  FAIL ", msg)

func _init() -> void:
	print("== BoardModel tests ==")
	test_fill_has_no_matches_and_a_move()
	test_swap_makes_match_and_resolves()
	test_invalid_swap_rejected()
	test_four_creates_line_and_fires()
	test_five_creates_prism()
	test_prism_swap_clears_color()
	test_gravity_and_refill()
	test_shuffle_keeps_colors()
	test_tutorial_layouts()
	test_level_curve()
	print("RESULT: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func test_fill_has_no_matches_and_a_move() -> void:
	for s in range(5):
		var m := BoardModel.new(8, 8, 6, s)
		m.fill_random()
		check(not m.has_matches(), "seed %d: fresh board has no matches" % s)
		check(m.has_valid_move(), "seed %d: fresh board has a valid move" % s)
		check(m.count_empty() == 0, "seed %d: board is full" % s)

func test_swap_makes_match_and_resolves() -> void:
	var m := BoardModel.new(8, 6, 5, 1)
	m.load_layout(TutorialLayouts.step_match3().layout)
	var moves := m.find_valid_moves()
	check(moves.size() == 1, "tutorial step 1 has exactly one valid move (got %d)" % moves.size())
	var res := m.resolve_move(Vector2i(3, 3), Vector2i(4, 3))
	check(res.valid, "swap resolves as valid")
	check(res.score >= 3 * BoardModel.BASE_TILE_SCORE, "score counts three tiles (got %d)" % res.score)
	check(m.count_empty() == 0, "board refilled after resolve")
	check(not m.has_matches(), "no matches remain after resolve")
	check(res.steps[0].type == "swap" and res.steps[1].type == "clear" and res.steps[2].type == "fall", "step order swap/clear/fall")

func test_invalid_swap_rejected() -> void:
	var m := BoardModel.new(8, 6, 5, 1)
	m.load_layout(TutorialLayouts.base())
	check(not m.has_valid_move(), "base pattern has no valid move")
	var res := m.resolve_move(Vector2i(0, 0), Vector2i(1, 0))
	check(not res.valid, "swap without a match is rejected")
	check(m.get_color(Vector2i(0, 0)) == 0, "rejected swap leaves the board untouched")

func test_four_creates_line_and_fires() -> void:
	var m := BoardModel.new(8, 6, 5, 2)
	var d := TutorialLayouts.step_line()
	m.load_layout(d.layout)
	# A four-in-a-row gap can always also be closed sideways, so step 2 only
	# guarantees the intended move exists and is the highest-scoring one.
	var best := m.best_move()
	check(not m.has_matches(), "tutorial step 2 starts with no matches")
	check(m.is_valid_move(d.from, d.to), "tutorial step 2 intended move is valid")
	check(TutorialLayouts._same_move(best, [d.from, d.to]), "tutorial step 2 intended move is the best move")
	var res := m.resolve_move(d.from, d.to)
	check(res.valid, "four-swap valid")
	var created: Array = res.steps[1].created
	check(created.size() == 1 and created[0].special == BoardModel.Special.LINE_V, "four in a row creates a vertical LINE")
	var cell: Vector2i = created[0].cell
	check(cell == d.to, "special spawns on the moved tile")
	# The line survives gravity: find it and fire it by swapping with a neighbour.
	var found := Vector2i(-1, -1)
	for r in m.rows:
		for c in m.cols:
			if m.get_special(Vector2i(c, r)) == BoardModel.Special.LINE_V:
				found = Vector2i(c, r)
	check(found.x >= 0, "line shuriken is on the board after the drop")
	var nb := found + (Vector2i(1, 0) if found.x < m.cols - 1 else Vector2i(-1, 0))
	check(m.is_valid_move(found, nb), "swapping a special is always a valid move")
	var res2 := m.resolve_move(found, nb)
	var fired := false
	for t in res2.steps[1].triggered:
		if t.special == BoardModel.Special.LINE_V:
			fired = true
	check(fired, "moved line shuriken fires")
	check(res2.steps[1].cells.size() >= m.rows, "line clears a full column (%d cells)" % res2.steps[1].cells.size())

func test_five_creates_prism() -> void:
	var m := BoardModel.new(8, 6, 5, 3)
	var l := TutorialLayouts.base()
	# row 3 base: 1 2 3 4 0 1 2 3 -> cols 0,1 = A ; col2 = B ; cols 3,4 = A ; A above col2
	l[3][0] = 4; l[3][1] = 4; l[3][2] = 0; l[3][3] = 4; l[3][4] = 4; l[2][2] = 4
	l[2][0] = 1; l[2][1] = 3; l[2][3] = 2; l[2][4] = 1
	l[4][0] = 2; l[4][1] = 0; l[4][3] = 1; l[4][4] = 3
	l[1][2] = 1
	m.load_layout(l)
	var res := m.resolve_move(Vector2i(2, 2), Vector2i(2, 3))
	check(res.valid, "five-swap valid")
	var kinds := []
	for cr in res.steps[1].created:
		kinds.append(cr.special)
	check(kinds.has(BoardModel.Special.PRISM), "five in a row creates a PRISM")

func test_prism_swap_clears_color() -> void:
	var m := BoardModel.new(8, 8, 6, 4)
	m.fill_random()
	m.set_special(Vector2i(3, 3), BoardModel.Special.PRISM)
	var target := m.get_color(Vector2i(4, 3))
	var count := 0
	for r in m.rows:
		for c in m.cols:
			if m.get_color(Vector2i(c, r)) == target:
				count += 1
	var res := m.resolve_move(Vector2i(3, 3), Vector2i(4, 3))
	check(res.valid, "prism swap valid")
	check(res.steps[1].combo == "prism_color", "prism + colour combo recognised")
	check(res.steps[1].cells.size() >= count, "prism clears every tile of that colour (%d >= %d)" % [res.steps[1].cells.size(), count])

func test_gravity_and_refill() -> void:
	var m := BoardModel.new(4, 4, 3, 5)
	m.load_layout([[0, 1, 2, 0], [1, 2, 0, 1], [2, 0, 1, 2], [0, 1, 2, 0]])
	m.clear_cells({Vector2i(1, 1): true, Vector2i(1, 2): true})
	var moves := m.apply_gravity()
	check(moves.size() == 1 and moves[0].from == Vector2i(1, 0) and moves[0].to == Vector2i(1, 2), "gravity drops the top tile two rows")
	var spawned := m.refill()
	check(spawned.size() == 2, "refill spawns two tiles")
	check(m.count_empty() == 0, "no empties after refill")

func test_shuffle_keeps_colors() -> void:
	var m := BoardModel.new(8, 8, 6, 6)
	m.fill_random()
	var before := {}
	for r in m.rows:
		for c in m.cols:
			var col := m.get_color(Vector2i(c, r))
			before[col] = before.get(col, 0) + 1
	m.shuffle()
	var after := {}
	for r in m.rows:
		for c in m.cols:
			var col := m.get_color(Vector2i(c, r))
			after[col] = after.get(col, 0) + 1
	check(before == after, "shuffle preserves the colour histogram")
	check(not m.has_matches() and m.has_valid_move(), "shuffled board is playable")

func test_tutorial_layouts() -> void:
	var m := BoardModel.new(8, 6, 5, 7)
	m.load_layout(TutorialLayouts.base())
	check(not m.has_matches(), "base layout has no matches")

## Greedy bot: plays each level with best-immediate-score moves. Reports how the
## curve feels so the formulas in MatchLevels can be tuned. Not a pass/fail test.
func test_level_curve() -> void:
	print("== Level curve (greedy bot, 12 games each) ==")
	print("  lvl  colors moves  target   mean   clear%  3star%")
	var clear_rates := []
	for level in [1, 2, 3, 5, 8, 12, 16, 20, 30, 40, 50]:
		var p := MatchLevels.params(level)
		var games := 12
		var sum := 0
		var cleared := 0
		var three := 0
		for g in games:
			var m := BoardModel.new(8, 8, p.colors, level * 100 + g)
			m.fill_random()
			var score := 0
			var moves_left: int = p.moves
			while moves_left > 0:
				var mv := m.best_move()
				if mv.is_empty():
					m.shuffle()
					continue
				var res := m.resolve_move(mv[0], mv[1])
				score += int(res.score)
				moves_left -= 1
				if score >= int(p.stars[2]):
					score += moves_left * 100
					break
			sum += score
			if score >= int(p.target): cleared += 1
			if score >= int(p.stars[2]): three += 1
		var mean := sum / games
		clear_rates.append(float(cleared) / games)
		print("  %3d    %d     %2d   %6d  %6d   %3d%%    %3d%%" % [level, p.colors, p.moves, p.target, mean, cleared * 100 / games, three * 100 / games])
	var early: float = clear_rates[0]
	check(early >= 0.75, "greedy bot clears level 1 most of the time (%.0f%%)" % (early * 100))
