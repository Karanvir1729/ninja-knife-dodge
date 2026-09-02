class_name TutorialLayouts
extends RefCounted
## Hand-built boards for the Shuriken Match walkthrough. The base pattern
## (c + 2r) mod 5 has no matches and no valid moves; each step plants the move
## it wants to teach, then _isolate() recolours stray cells until that move is
## the only one on the board (verified in tests/test_board.gd).

const COLS := 8
const ROWS := 6

static func base() -> Array:
	var layout := []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append((c + 2 * r) % 5)
		layout.append(row)
	return layout

## Step 1: a single three-in-a-row by swapping (3,3) with (4,3).
static func step_match3() -> Dictionary:
	var l := base()
	l[3][1] = 4; l[3][2] = 4; l[3][3] = 0; l[3][4] = 4
	var protected := [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var intended := [Vector2i(3, 3), Vector2i(4, 3)]
	return {"layout": _isolate(l, protected, intended), "from": intended[0], "to": intended[1]}

## Step 2: swapping (3,2) down into (3,3) makes four in a row -> a LINE shuriken.
static func step_line() -> Dictionary:
	var l := base()
	l[3][1] = 4; l[3][2] = 4; l[3][3] = 0; l[3][4] = 4
	l[2][3] = 4
	var protected := [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(0, 3), Vector2i(5, 3)]
	var intended := [Vector2i(3, 2), Vector2i(3, 3)]
	return {"layout": _isolate(l, protected, intended), "from": intended[0], "to": intended[1]}

static func _same_move(a: Array, b: Array) -> bool:
	return (a[0] == b[0] and a[1] == b[1]) or (a[0] == b[1] and a[1] == b[0])

## Recolour unprotected cells until `intended` is the only valid move and the
## board has no matches. Returns the resulting layout.
static func _isolate(layout: Array, protected: Array, intended: Array) -> Array:
	var m := BoardModel.new(COLS, ROWS, 5, 1)
	m.load_layout(layout)
	for _iter in 400:
		var extra := []
		for mv in m.find_valid_moves():
			if not _same_move(mv, intended):
				extra.append(mv)
		if extra.is_empty() and not m.has_matches():
			break
		var mv: Array = extra[0] if not extra.is_empty() else intended
		# Candidate cells: the two swapped cells, plus the run cells the swap would create.
		var candidates: Array = [mv[0], mv[1]]
		m.swap(mv[0], mv[1])
		for run in m.find_runs():
			for cell in run.cells:
				if not candidates.has(cell):
					candidates.append(cell)
		m.swap(mv[0], mv[1])
		var fixed := false
		for cell in candidates:
			if protected.has(cell):
				continue
			var orig: int = m.get_color(cell)
			for color in 5:
				if color == orig:
					continue
				m.set_color(cell, color)
				if not m.has_matches() and not m.is_valid_move(mv[0], mv[1]) and m.is_valid_move(intended[0], intended[1]):
					fixed = true
					break
				m.set_color(cell, orig)
			if fixed:
				break
		if not fixed:
			push_warning("TutorialLayouts: could not isolate move %s" % [mv])
			break
	var out := []
	for r in ROWS:
		out.append(m.grid[r].duplicate())
	return out
