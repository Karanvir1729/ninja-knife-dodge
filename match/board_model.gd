class_name BoardModel
extends RefCounted
## Pure match-3 logic with no rendering: grid state, match detection, special
## shurikens, gravity/refill, valid-move search and shuffling. Deterministic
## when given a seeded RNG, so it is unit-testable and usable by a bot.

enum Special { NONE, LINE_H, LINE_V, BURST, PRISM }

const EMPTY := -1
const BASE_TILE_SCORE := 60
const BONUS_LINE := 150
const BONUS_BURST := 250
const BONUS_PRISM := 400

var cols := 8
var rows := 8
var num_colors := 6
var grid: Array = []      # grid[r][c] -> color index or EMPTY
var specials: Array = []  # specials[r][c] -> Special
var rng := RandomNumberGenerator.new()

func _init(p_cols: int = 8, p_rows: int = 8, p_colors: int = 6, p_seed: int = -1) -> void:
	cols = p_cols
	rows = p_rows
	num_colors = p_colors
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	clear()

func clear() -> void:
	grid = []
	specials = []
	for r in rows:
		var row := []
		var srow := []
		for c in cols:
			row.append(EMPTY)
			srow.append(Special.NONE)
		grid.append(row)
		specials.append(srow)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows

func get_color(p: Vector2i) -> int:
	return grid[p.y][p.x]

func set_color(p: Vector2i, color: int) -> void:
	grid[p.y][p.x] = color

func get_special(p: Vector2i) -> int:
	return specials[p.y][p.x]

func set_special(p: Vector2i, s: int) -> void:
	specials[p.y][p.x] = s

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return (absi(a.x - b.x) + absi(a.y - b.y)) == 1

func swap(a: Vector2i, b: Vector2i) -> void:
	var tc = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = tc
	var ts = specials[a.y][a.x]
	specials[a.y][a.x] = specials[b.y][b.x]
	specials[b.y][b.x] = ts

## Fill every cell with random colours such that no match exists initially,
## then reshuffle until at least one valid move exists.
func fill_random() -> void:
	for r in rows:
		for c in cols:
			var p := Vector2i(c, r)
			var color := rng.randi_range(0, num_colors - 1)
			var tries := 0
			while _would_match(p, color) and tries < 20:
				color = rng.randi_range(0, num_colors - 1)
				tries += 1
			grid[r][c] = color
			specials[r][c] = Special.NONE
	if not has_valid_move():
		shuffle()

## Load an explicit layout (rows of colour indices). -1 keeps a cell empty.
func load_layout(layout: Array) -> void:
	rows = layout.size()
	cols = layout[0].size()
	clear()
	for r in rows:
		for c in cols:
			grid[r][c] = int(layout[r][c])

func _would_match(p: Vector2i, color: int) -> bool:
	# horizontal: two same to the left, or vertical: two same above (fill order is row-major)
	if p.x >= 2 and grid[p.y][p.x - 1] == color and grid[p.y][p.x - 2] == color:
		return true
	if p.y >= 2 and grid[p.y - 1][p.x] == color and grid[p.y - 2][p.x] == color:
		return true
	return false

## Find all runs of 3+ in rows and columns. Returns [{cells: [Vector2i], color, horizontal: bool}].
func find_runs() -> Array:
	var runs := []
	for r in rows:
		var c := 0
		while c < cols:
			var color: int = grid[r][c]
			var start := c
			while c < cols and grid[r][c] == color:
				c += 1
			if color != EMPTY and c - start >= 3:
				var cells := []
				for x in range(start, c):
					cells.append(Vector2i(x, r))
				runs.append({"cells": cells, "color": color, "horizontal": true})
	for c in cols:
		var r := 0
		while r < rows:
			var color: int = grid[r][c]
			var start := r
			while r < rows and grid[r][c] == color:
				r += 1
			if color != EMPTY and r - start >= 3:
				var cells := []
				for y in range(start, r):
					cells.append(Vector2i(c, y))
				runs.append({"cells": cells, "color": color, "horizontal": false})
	return runs

func has_matches() -> bool:
	return not find_runs().is_empty()

## Turn runs into a resolution plan:
##  cleared - Dictionary set of Vector2i to clear (specials on them also trigger)
##  created - [{cell, special, color}] specials to create after clearing
##  score   - points for the tiles + creation bonuses
## `focus` is the cell the player moved (specials spawn there when part of the run).
func plan_from_runs(runs: Array, focus: Vector2i = Vector2i(-1, -1), focus_b: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var cleared := {}
	var created := []
	var score := 0
	var cell_runs := {}  # cell -> [run indices]
	for i in runs.size():
		for cell in runs[i].cells:
			cleared[cell] = true
			if not cell_runs.has(cell):
				cell_runs[cell] = []
			cell_runs[cell].append(i)
	# Intersections (L / T) -> BURST
	var consumed := {}
	for cell in cell_runs.keys():
		if cell_runs[cell].size() >= 2:
			var ok := true
			for i in cell_runs[cell]:
				if consumed.has(i): ok = false
			if ok:
				for i in cell_runs[cell]:
					consumed[i] = true
				created.append({"cell": cell, "special": Special.BURST, "color": runs[cell_runs[cell][0]].color})
				score += BONUS_BURST
	for i in runs.size():
		if consumed.has(i):
			continue
		var run: Dictionary = runs[i]
		var n: int = run.cells.size()
		if n >= 5:
			created.append({"cell": _pick_special_cell(run.cells, focus, focus_b), "special": Special.PRISM, "color": run.color})
			score += BONUS_PRISM
		elif n == 4:
			var kind: int = Special.LINE_V if run.horizontal else Special.LINE_H
			created.append({"cell": _pick_special_cell(run.cells, focus, focus_b), "special": kind, "color": run.color})
			score += BONUS_LINE
	score += cleared.size() * BASE_TILE_SCORE
	return {"cleared": cleared, "created": created, "score": score}

func _pick_special_cell(cells: Array, focus: Vector2i, focus_b: Vector2i) -> Vector2i:
	if cells.has(focus):
		return focus
	if cells.has(focus_b):
		return focus_b
	return cells[cells.size() / 2]

## Expand a set of cleared cells by triggering any specials inside it (chain reaction).
## Returns {cells: set, triggered: [{cell, special}]}.
func expand_specials(cleared: Dictionary, prism_color: int = -1) -> Dictionary:
	var result := cleared.duplicate()
	var triggered := []
	var queue: Array = cleared.keys()
	var seen := {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if seen.has(cell):
			continue
		seen[cell] = true
		var s: int = get_special(cell)
		if s == Special.NONE:
			continue
		triggered.append({"cell": cell, "special": s})
		var extra := special_area(cell, s, prism_color)
		for e in extra:
			if not result.has(e):
				result[e] = true
				queue.append(e)
	return {"cells": result, "triggered": triggered}

## Cells a special affects when it fires.
func special_area(cell: Vector2i, s: int, prism_color: int = -1) -> Array:
	var out := []
	match s:
		Special.LINE_H:
			for c in cols:
				out.append(Vector2i(c, cell.y))
		Special.LINE_V:
			for r in rows:
				out.append(Vector2i(cell.x, r))
		Special.BURST:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := cell + Vector2i(dx, dy)
					if in_bounds(p):
						out.append(p)
		Special.PRISM:
			var target := prism_color
			if target < 0:
				target = _most_common_color()
			for r in rows:
				for c in cols:
					if grid[r][c] == target:
						out.append(Vector2i(c, r))
	return out

func _most_common_color() -> int:
	var counts := {}
	for r in rows:
		for c in cols:
			var col: int = grid[r][c]
			if col >= 0:
				counts[col] = counts.get(col, 0) + 1
	var best := -1
	var best_n := -1
	for k in counts.keys():
		if counts[k] > best_n:
			best_n = counts[k]
			best = k
	return best

## Swapping two specials, or a prism with a colour, has its own rules.
## Returns null if the swap is a normal one, else {cells: set, score, kind}.
func combo_swap(a: Vector2i, b: Vector2i) -> Variant:
	var sa := get_special(a)
	var sb := get_special(b)
	if sa == Special.NONE and sb == Special.NONE:
		return null
	var cells := {}
	var kind := ""
	if sa == Special.PRISM and sb == Special.PRISM:
		for r in rows:
			for c in cols:
				cells[Vector2i(c, r)] = true
		kind = "prism_prism"
	elif sa == Special.PRISM or sb == Special.PRISM:
		var prism := a if sa == Special.PRISM else b
		var other := b if sa == Special.PRISM else a
		var other_special := get_special(other)
		var color := get_color(other)
		cells[prism] = true
		if other_special == Special.NONE:
			for p in special_area(prism, Special.PRISM, color):
				cells[p] = true
			kind = "prism_color"
		else:
			# Prism + special: every tile of that colour becomes that special and fires.
			for r in rows:
				for c in cols:
					if grid[r][c] == color:
						var p := Vector2i(c, r)
						cells[p] = true
						for q in special_area(p, other_special):
							cells[q] = true
			kind = "prism_special"
	elif _is_line(sa) and _is_line(sb):
		for p in special_area(b, Special.LINE_H): cells[p] = true
		for p in special_area(b, Special.LINE_V): cells[p] = true
		kind = "cross"
	elif (_is_line(sa) and sb == Special.BURST) or (sa == Special.BURST and _is_line(sb)):
		for dy in range(-1, 2):
			for p in special_area(b + Vector2i(0, dy), Special.LINE_H):
				if in_bounds(p): cells[p] = true
		for dx in range(-1, 2):
			for p in special_area(b + Vector2i(dx, 0), Special.LINE_V):
				if in_bounds(p): cells[p] = true
		kind = "triple_cross"
	elif sa == Special.BURST and sb == Special.BURST:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var p := b + Vector2i(dx, dy)
				if in_bounds(p): cells[p] = true
		kind = "mega_burst"
	else:
		return null
	cells[a] = true
	cells[b] = true
	return {"cells": cells, "score": cells.size() * BASE_TILE_SCORE + 200, "kind": kind}

func _is_line(s: int) -> bool:
	return s == Special.LINE_H or s == Special.LINE_V

func clear_cells(cells: Dictionary) -> void:
	for cell in cells.keys():
		grid[cell.y][cell.x] = EMPTY
		specials[cell.y][cell.x] = Special.NONE

## Drop tiles down. Returns [{from: Vector2i, to: Vector2i}] for animation.
func apply_gravity() -> Array:
	var moves := []
	for c in cols:
		var write := rows - 1
		for r in range(rows - 1, -1, -1):
			if grid[r][c] != EMPTY:
				if write != r:
					grid[write][c] = grid[r][c]
					specials[write][c] = specials[r][c]
					grid[r][c] = EMPTY
					specials[r][c] = Special.NONE
					moves.append({"from": Vector2i(c, r), "to": Vector2i(c, write)})
				write -= 1
	return moves

## Fill empty cells from the top with random colours. Returns [{cell, color, drop}] where
## drop is how many rows above the board the tile should start for animation.
func refill() -> Array:
	var spawned := []
	for c in cols:
		var empties := 0
		for r in range(rows - 1, -1, -1):
			if grid[r][c] == EMPTY:
				empties += 1
		var k := 0
		for r in range(rows - 1, -1, -1):
			if grid[r][c] == EMPTY:
				var color := rng.randi_range(0, num_colors - 1)
				grid[r][c] = color
				specials[r][c] = Special.NONE
				spawned.append({"cell": Vector2i(c, r), "color": color, "drop": empties - k})
				k += 1
	return spawned

## Would swapping a and b produce a match (or a special combo)?
func is_valid_move(a: Vector2i, b: Vector2i) -> bool:
	if not in_bounds(a) or not in_bounds(b) or not is_adjacent(a, b):
		return false
	if get_color(a) == EMPTY or get_color(b) == EMPTY:
		return false
	if combo_swap(a, b) != null:
		return true
	if get_special(a) != Special.NONE or get_special(b) != Special.NONE:
		return true
	swap(a, b)
	var ok := _cell_in_run(a) or _cell_in_run(b)
	swap(a, b)
	return ok

func _cell_in_run(p: Vector2i) -> bool:
	var color := get_color(p)
	if color == EMPTY:
		return false
	var n := 1
	var x := p.x - 1
	while x >= 0 and grid[p.y][x] == color: n += 1; x -= 1
	x = p.x + 1
	while x < cols and grid[p.y][x] == color: n += 1; x += 1
	if n >= 3:
		return true
	n = 1
	var y := p.y - 1
	while y >= 0 and grid[y][p.x] == color: n += 1; y -= 1
	y = p.y + 1
	while y < rows and grid[y][p.x] == color: n += 1; y += 1
	return n >= 3

func find_valid_moves() -> Array:
	var out := []
	for r in rows:
		for c in cols:
			var p := Vector2i(c, r)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var q: Vector2i = p + d
				if in_bounds(q) and is_valid_move(p, q):
					out.append([p, q])
	return out

func has_valid_move() -> bool:
	for r in rows:
		for c in cols:
			var p := Vector2i(c, r)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var q: Vector2i = p + d
				if in_bounds(q) and is_valid_move(p, q):
					return true
	return false

func find_valid_move() -> Array:
	var moves := find_valid_moves()
	if moves.is_empty():
		return []
	return moves[rng.randi_range(0, moves.size() - 1)]

## Score the immediate result of a swap (used by hints and the tuning bot).
func score_move(a: Vector2i, b: Vector2i) -> int:
	var combo = combo_swap(a, b)
	if combo != null:
		return int(combo.score)
	swap(a, b)
	var plan := plan_from_runs(find_runs(), a, b)
	swap(a, b)
	return int(plan.score)

## Reshuffle existing colours until the board has no matches and at least one move.
func shuffle() -> void:
	var colors := []
	for r in rows:
		for c in cols:
			if grid[r][c] != EMPTY:
				colors.append(grid[r][c])
	for attempt in 200:
		for i in range(colors.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = colors[i]; colors[i] = colors[j]; colors[j] = t
		var k := 0
		for r in rows:
			for c in cols:
				if grid[r][c] != EMPTY:
					grid[r][c] = colors[k]
					k += 1
		if not has_matches() and has_valid_move():
			return
	# Fallback: regenerate entirely.
	fill_random()

func count_empty() -> int:
	var n := 0
	for r in rows:
		for c in cols:
			if grid[r][c] == EMPTY:
				n += 1
	return n

func to_string_grid() -> String:
	var s := ""
	for r in rows:
		var line := ""
		for c in cols:
			var v: int = grid[r][c]
			line += ("." if v == EMPTY else str(v))
			var sp: int = specials[r][c]
			line += ["", "-", "|", "o", "*"][sp] if sp != Special.NONE else " "
		s += line + "\n"
	return s

## Cascade multiplier for the n-th chain reaction (0 = the player's own match).
static func chain_multiplier(chain: int) -> float:
	return 1.0 + 0.5 * chain

## Perform a complete move: swap, clear, chain-react, drop and refill until stable.
## Returns {valid, score, max_chain, steps} where steps alternate
##   {type:"swap", a, b}
##   {type:"clear", cells:[Vector2i], created:[{cell,special,color}], triggered:[{cell,special}], combo:String, score:int, chain:int}
##   {type:"fall", moves:[{from,to}], spawned:[{cell,color,drop}]}
## The grid is fully updated when this returns; the steps let a view replay it.
func resolve_move(a: Vector2i, b: Vector2i) -> Dictionary:
	if not is_valid_move(a, b):
		return {"valid": false, "score": 0, "max_chain": 0, "steps": []}
	var steps := []
	var total := 0
	var chain := 0
	var combo = combo_swap(a, b)
	swap(a, b)
	steps.append({"type": "swap", "a": a, "b": b})
	var first_cells := {}
	var first_created := []
	var first_score := 0
	var combo_kind := ""
	if combo != null:
		var exp := expand_specials(combo.cells)
		first_cells = exp.cells
		first_score = int(combo.score) + (first_cells.size() - int(combo.cells.size())) * BASE_TILE_SCORE
		combo_kind = str(combo.kind)
		clear_cells(first_cells)
		steps.append({"type": "clear", "cells": first_cells.keys(), "created": [], "triggered": exp.triggered, "combo": combo_kind, "score": first_score, "chain": 0})
	else:
		var runs := find_runs()
		var plan := {"cleared": {}, "created": [], "score": 0}
		if not runs.is_empty():
			plan = plan_from_runs(runs, a, b)
		var seed_cells: Dictionary = plan.cleared.duplicate()
		# A special that was moved but not matched still fires.
		for p in [a, b]:
			if get_special(p) != Special.NONE and not seed_cells.has(p):
				seed_cells[p] = true
		var exp := expand_specials(seed_cells)
		first_cells = exp.cells
		first_score = int(plan.score) + (first_cells.size() - int(plan.cleared.size())) * BASE_TILE_SCORE
		clear_cells(first_cells)
		for cr in plan.created:
			set_color(cr.cell, cr.color)
			set_special(cr.cell, cr.special)
		first_created = plan.created
		steps.append({"type": "clear", "cells": first_cells.keys(), "created": first_created, "triggered": exp.triggered, "combo": "", "score": first_score, "chain": 0})
	total += first_score
	var cascade := resolve_cascades()
	steps.append_array(cascade.steps)
	total += int(cascade.score)
	chain = int(cascade.max_chain)
	return {"valid": true, "score": total, "max_chain": chain, "steps": steps}

## Drop, refill and chain-react until the board is stable. This is the tail of
## resolve_move after its first clear, exposed so other single-clear actions
## (the hammer booster) can reuse it. Returns {score, max_chain, steps} where
## steps alternate "fall" and "clear" entries in the same shape as resolve_move
## (the first entry is always a "fall", even if nothing moved). Cascade clears
## are scored with chain_multiplier starting at chain 1.
func resolve_cascades() -> Dictionary:
	var steps := []
	var total := 0
	var chain := 0
	while true:
		var moves := apply_gravity()
		var spawned := refill()
		steps.append({"type": "fall", "moves": moves, "spawned": spawned})
		var runs := find_runs()
		if runs.is_empty():
			break
		chain += 1
		var plan := plan_from_runs(runs)
		var exp := expand_specials(plan.cleared)
		var raw: int = int(plan.score) + (int(exp.cells.size()) - int(plan.cleared.size())) * BASE_TILE_SCORE
		var s := int(round(raw * chain_multiplier(chain)))
		clear_cells(exp.cells)
		for cr in plan.created:
			set_color(cr.cell, cr.color)
			set_special(cr.cell, cr.special)
		steps.append({"type": "clear", "cells": exp.cells.keys(), "created": plan.created, "triggered": exp.triggered, "combo": "", "score": s, "chain": chain})
		total += s
		if chain > 40:
			break
	return {"score": total, "max_chain": chain, "steps": steps}

## Best immediate move by score (used for hints and the tuning bot). Returns [a, b] or [].
func best_move() -> Array:
	var best := []
	var best_score := -1
	for m in find_valid_moves():
		var s := score_move(m[0], m[1])
		if s > best_score:
			best_score = s
			best = m
	return best
