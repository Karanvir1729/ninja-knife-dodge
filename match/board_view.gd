extends Control
class_name BoardView
## Renders a BoardModel and animates its move resolutions. Handles tap-tap and
## swipe input, hints after idling, and reshuffles when no move exists.

signal move_made(result: Dictionary)
signal board_settled
signal swap_rejected
signal special_created(kind: int, at: Vector2)
signal special_fired(kind: int, at: Vector2, combo: String)
signal tiles_cleared(count: int, chain: int, at: Vector2, score: int)
signal shuffled
signal tile_pressed(cell: Vector2i)
signal smashed(result: Dictionary)

const TILE_SCENE := preload("res://match/tile.tscn")
const HINT_DELAY := 5.0

var model: BoardModel
var cell_px := 80.0
var gap := 8.0
var origin := Vector2.ZERO
var busy := false
var interactive := true
var allowed_move: Array = []   # tutorial: only this swap is accepted
var hints_enabled := true
var hammer_mode := false       # next tile press smashes that tile (hammer booster)

var _tiles := {}   # Vector2i -> MatchTile
var _selected: Variant = null
var _press_cell: Variant = null
var _press_pos := Vector2.ZERO
var _dragging := false
var _idle := 0.0
var _hint_tiles: Array = []
var _spark_tex: Texture2D
var _beam_tex: Texture2D
var _ring_tex: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_spark_tex = load("res://graphics/gen/spark.png")
	_beam_tex = load("res://graphics/gen/beam.png")
	_ring_tex = load("res://graphics/gen/ring.png")
	resized.connect(_relayout)

func setup(p_model: BoardModel) -> void:
	model = p_model
	_relayout()
	rebuild()

func _relayout() -> void:
	if model == null:
		return
	var by_w := (size.x - gap * (model.cols - 1)) / model.cols
	var by_h := (size.y - gap * (model.rows - 1)) / model.rows
	cell_px = floorf(minf(by_w, by_h))
	var board_w := model.cols * cell_px + (model.cols - 1) * gap
	var board_h := model.rows * cell_px + (model.rows - 1) * gap
	origin = Vector2((size.x - board_w) * 0.5, (size.y - board_h) * 0.5)
	for cell in _tiles.keys():
		var t: MatchTile = _tiles[cell]
		t.position = cell_center(cell)
		t.setup(t.color_index, t.special, cell_px * 0.8)

func cell_center(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell.x * (cell_px + gap) + cell_px * 0.5, cell.y * (cell_px + gap) + cell_px * 0.5)

func cell_global(cell: Vector2i) -> Vector2:
	return global_position + cell_center(cell)

func cell_at(local: Vector2) -> Variant:
	var p := local - origin
	if p.x < 0 or p.y < 0:
		return null
	var cx := int(p.x / (cell_px + gap))
	var cy := int(p.y / (cell_px + gap))
	if cx >= model.cols or cy >= model.rows:
		return null
	var inner := Vector2(p.x - cx * (cell_px + gap), p.y - cy * (cell_px + gap))
	if inner.x > cell_px or inner.y > cell_px:
		return null
	return Vector2i(cx, cy)

func rebuild() -> void:
	for t in _tiles.values():
		t.queue_free()
	_tiles.clear()
	for r in model.rows:
		for c in model.cols:
			var cell := Vector2i(c, r)
			if model.get_color(cell) != BoardModel.EMPTY:
				_spawn_tile(cell, model.get_color(cell), model.get_special(cell), true)

func _spawn_tile(cell: Vector2i, color: int, special: int, animate_in: bool = false) -> MatchTile:
	var t: MatchTile = TILE_SCENE.instantiate()
	t.cell = cell
	add_child(t)
	t.position = cell_center(cell)
	t.setup(color, special, cell_px * 0.8)
	_tiles[cell] = t
	if animate_in:
		t.appear()
	return t

func _draw() -> void:
	if model == null:
		return
	for r in model.rows:
		for c in model.cols:
			var rect := Rect2(origin + Vector2(c * (cell_px + gap), r * (cell_px + gap)), Vector2(cell_px, cell_px))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(Globals.BG1, 0.9)
			sb.set_border_width_all(1)
			sb.border_color = Globals.LINE
			sb.set_corner_radius_all(int(cell_px * 0.14))
			sb.draw(get_canvas_item(), rect)

func _process(delta: float) -> void:
	if not interactive or busy or model == null or not hints_enabled:
		return
	_idle += delta
	if _idle > HINT_DELAY and _hint_tiles.is_empty() and _selected == null:
		show_hint()

## Light up the best move (or the tutorial's allowed move). Used by the free
## idle hint and by the HINT booster, so it works whether or not the idle
## timer has fired.
func show_hint() -> void:
	if model == null or busy:
		return
	_clear_hint()
	_deselect()
	var mv := allowed_move if not allowed_move.is_empty() else model.best_move()
	if mv.is_empty():
		return
	for cell in mv:
		if _tiles.has(cell):
			_tiles[cell].start_hint()
			_hint_tiles.append(_tiles[cell])

func has_hint() -> bool:
	return not _hint_tiles.is_empty()

func _clear_hint() -> void:
	for t in _hint_tiles:
		if is_instance_valid(t):
			t.stop_hint()
	_hint_tiles.clear()
	_idle = 0.0

func _gui_input(event: InputEvent) -> void:
	if not interactive or model == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_cell = cell_at(event.position)
			_press_pos = event.position
			_dragging = _press_cell != null
			_clear_hint()
			if _press_cell != null:
				tile_pressed.emit(_press_cell)
				if hammer_mode and not busy:
					var target: Vector2i = _press_cell
					_press_cell = null
					_dragging = false
					smash(target)
		else:
			if _dragging and _press_cell != null:
				var d: Vector2 = event.position - _press_pos
				if d.length() < cell_px * 0.35:
					_tap(_press_cell)
			_dragging = false
			_press_cell = null
	elif event is InputEventMouseMotion and _dragging and _press_cell != null:
		var d: Vector2 = event.position - _press_pos
		if d.length() >= cell_px * 0.35:
			var dir := Vector2i(signi(int(round(d.x))), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(round(d.y))))
			var target: Vector2i = _press_cell + dir
			_dragging = false
			if model.in_bounds(target):
				_deselect()
				try_swap(_press_cell, target)
			_press_cell = null

func _tap(cell: Vector2i) -> void:
	if busy:
		return
	if _selected == null:
		_select(cell)
	elif _selected == cell:
		_deselect()
	elif model.is_adjacent(_selected, cell):
		var a: Vector2i = _selected
		_deselect()
		try_swap(a, cell)
	else:
		_deselect()
		_select(cell)

## Tutorial helper: show the selection ring on a tile without selecting it.
func highlight(cell: Vector2i, on: bool) -> void:
	if _tiles.has(cell):
		_tiles[cell].set_selected(on)

func _select(cell: Vector2i) -> void:
	if not _tiles.has(cell):
		return
	_selected = cell
	_tiles[cell].set_selected(true)
	AudioManager.play_sfx("ui_click", 1.3, -10.0)

func _deselect() -> void:
	if _selected != null and _tiles.has(_selected):
		_tiles[_selected].set_selected(false)
	_selected = null

## Attempt a swap. Invalid swaps wiggle back; valid ones resolve fully.
func try_swap(a: Vector2i, b: Vector2i) -> void:
	if busy or not _tiles.has(a) or not _tiles.has(b):
		return
	_clear_hint()
	var allowed: bool = allowed_move.is_empty() or (allowed_move[0] == a and allowed_move[1] == b) or (allowed_move[0] == b and allowed_move[1] == a)
	if not allowed or not model.is_valid_move(a, b):
		busy = true
		AudioManager.play_sfx("swap_fail", 1.0, -6.0)
		await _animate_swap(a, b, 0.13)
		await _animate_swap(a, b, 0.13)
		_tiles[a].wiggle()
		busy = false
		swap_rejected.emit()
		return
	busy = true
	var result := model.resolve_move(a, b)
	AudioManager.play_sfx("swap")
	await _play_steps(result.steps)
	busy = false
	_idle = 0.0
	move_made.emit(result)
	if not model.has_valid_move():
		await _reshuffle()
	board_settled.emit()

func _animate_swap(a: Vector2i, b: Vector2i, dur: float) -> void:
	var ta: MatchTile = _tiles[a]
	var tb: MatchTile = _tiles[b]
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ta, "position", cell_center(b), dur).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(tb, "position", cell_center(a), dur).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_tiles[a] = tb
	_tiles[b] = ta
	ta.cell = b
	tb.cell = a

func _play_steps(steps: Array) -> void:
	for step in steps:
		match step.type:
			"swap":
				await _animate_swap(step.a, step.b, 0.15)
			"clear":
				await _animate_clear(step)
			"fall":
				await _animate_fall(step)

func _animate_clear(step: Dictionary) -> void:
	var cells: Array = step.cells
	if cells.is_empty():
		return
	var centroid := Vector2.ZERO
	for cell in cells:
		centroid += cell_center(cell)
	centroid /= cells.size()
	for trig in step.triggered:
		_special_fx(trig.cell, trig.special)
		special_fired.emit(trig.special, global_position + cell_center(trig.cell), step.combo)
	var sfx: String = str(step.get("sfx", "combo" if step.chain > 0 else "match"))
	if sfx == "combo":
		AudioManager.play_sfx("combo", 1.0 + minf(step.chain, 6) * 0.08)
	elif sfx != "":
		AudioManager.play_sfx(sfx, 1.0)
	var last: Tween = null
	for cell in cells:
		if _tiles.has(cell):
			var t: MatchTile = _tiles[cell]
			_shards(t.position, t.color_index, t.special != BoardModel.Special.NONE)
			last = t.pop()
			_tiles.erase(cell)
	tiles_cleared.emit(cells.size(), step.chain, global_position + centroid, step.score)
	if last:
		await last.finished
	for cr in step.created:
		var t := _spawn_tile(cr.cell, cr.color, cr.special, true)
		_ring_fx(t.position, Globals.GEM_COLORS[cr.color], 0.9)
		AudioManager.play_sfx("special_create")
		special_created.emit(cr.special, global_position + t.position)
	if not step.created.is_empty():
		await get_tree().create_timer(0.12).timeout

func _animate_fall(step: Dictionary) -> void:
	var moved := {}
	for m in step.moves:
		if _tiles.has(m.from):
			moved[m.to] = _tiles[m.from]
			_tiles.erase(m.from)
	var t := create_tween()
	t.set_parallel(true)
	var any := false
	for to in moved.keys():
		var tile: MatchTile = moved[to]
		_tiles[to] = tile
		tile.cell = to
		var dist := absf(cell_center(to).y - tile.position.y)
		t.tween_property(tile, "position", cell_center(to), 0.12 + dist * 0.0009).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		any = true
	for s in step.spawned:
		var tile := _spawn_tile(s.cell, s.color, BoardModel.Special.NONE)
		tile.position = cell_center(s.cell) - Vector2(0, (s.drop + 0.5) * (cell_px + gap))
		var dist := absf(cell_center(s.cell).y - tile.position.y)
		t.tween_property(tile, "position", cell_center(s.cell), 0.14 + dist * 0.0009).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		any = true
	if any:
		await t.finished
		AudioManager.play_sfx("tile_land", randf_range(0.9, 1.1), -12.0)
	else:
		await get_tree().process_frame

## Shuffle booster: reshuffle right away without spending a move. Unlike the
## automatic dead-board shuffle this does not emit `shuffled` (the caller
## announces it) and changes neither score nor moves.
func reshuffle_now() -> void:
	if busy or model == null:
		return
	_clear_hint()
	_deselect()
	await _reshuffle(false)

## Hammer booster: clear just this one tile (no move spent), then drop, refill
## and resolve any cascades exactly like the tail of a normal move.
func smash(cell: Vector2i) -> void:
	if busy or model == null or not _tiles.has(cell):
		return
	busy = true
	hammer_mode = false
	_clear_hint()
	_deselect()
	var tile: MatchTile = _tiles[cell]
	_hammer_fx(tile.position, tile.color_index)
	# Smashing a special fires it, like matching it would.
	var exp: Dictionary = model.expand_specials({cell: true})
	var cells: Dictionary = exp.cells
	model.clear_cells(cells)
	var base_score: int = cells.size() * BoardModel.BASE_TILE_SCORE
	var clear_step := {"type": "clear", "cells": cells.keys(), "created": [], "triggered": exp.triggered, "combo": "", "score": base_score, "chain": 0, "sfx": "hammer"}
	await _play_steps([clear_step])
	var cascade: Dictionary = model.resolve_cascades()
	await _play_steps(cascade.steps)
	busy = false
	_idle = 0.0
	smashed.emit({"cell": cell, "score": base_score + int(cascade.score), "max_chain": int(cascade.max_chain)})
	if not model.has_valid_move():
		await _reshuffle()
	board_settled.emit()

func _reshuffle(announce: bool = true) -> void:
	busy = true
	if announce:
		shuffled.emit()
	AudioManager.play_sfx("shuffle")
	var t := create_tween()
	t.set_parallel(true)
	for tile in _tiles.values():
		t.tween_property(tile, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN)
	await t.finished
	model.shuffle()
	rebuild()
	await get_tree().create_timer(0.35).timeout
	busy = false

# ------------------------------------------------------------------ effects

func _hammer_fx(at: Vector2, color_index: int) -> void:
	AudioManager.vibrate(35)
	_ring_fx(at, Color.WHITE, 1.4)
	for i in 3:
		_shards(at, color_index, true)

func _shards(at: Vector2, color_index: int, bright: bool) -> void:
	var col: Color = Globals.GEM_COLORS[color_index % Globals.GEM_COLORS.size()]
	var n := 5 if bright else 3
	for i in n:
		var s := Sprite2D.new()
		s.texture = _spark_tex
		s.material = _add_material()
		s.modulate = col.lightened(0.3) if bright else col
		s.position = at
		s.scale = Vector2.ONE * randf_range(0.5, 1.1) * (cell_px / 80.0)
		s.z_index = 4
		add_child(s)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(cell_px * 0.5, cell_px * 1.4)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(s, "position", at + dir, 0.42).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
		t.tween_property(s, "scale", Vector2.ZERO, 0.42)
		t.chain().tween_callback(s.queue_free)

var _add_mat: CanvasItemMaterial
func _add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

func _ring_fx(at: Vector2, color: Color, size_mult: float = 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = _ring_tex
	s.material = _add_material()
	s.modulate = Color(color, 0.9)
	s.position = at
	s.scale = Vector2.ONE * 0.1
	s.z_index = 4
	add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * (cell_px / 256.0) * 2.4 * size_mult, 0.45).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(s.queue_free)

func _special_fx(cell: Vector2i, special: int) -> void:
	var at := cell_center(cell)
	var col: Color = Color.WHITE
	if _tiles.has(cell):
		col = Globals.GEM_COLORS[_tiles[cell].color_index % Globals.GEM_COLORS.size()]
	match special:
		BoardModel.Special.LINE_H:
			_beam(Vector2(size.x * 0.5, at.y), 0.0, size.x, col)
			AudioManager.play_sfx("line_blast")
		BoardModel.Special.LINE_V:
			_beam(Vector2(at.x, size.y * 0.5), PI / 2, size.y, col)
			AudioManager.play_sfx("line_blast")
		BoardModel.Special.BURST:
			_ring_fx(at, col, 1.6)
			AudioManager.play_sfx("burst")
			AudioManager.vibrate(30)
		BoardModel.Special.PRISM:
			_ring_fx(at, Color.WHITE, 3.0)
			AudioManager.play_sfx("prism")
			AudioManager.vibrate(45)

func _beam(at: Vector2, rot: float, length: float, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _beam_tex
	s.material = _add_material()
	s.modulate = Color(color.lightened(0.4), 1.0)
	s.position = at
	s.rotation = rot
	s.scale = Vector2(length / 256.0, cell_px / 32.0 * 0.9)
	s.z_index = 4
	add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale:y", cell_px / 32.0 * 0.2, 0.35).set_ease(Tween.EASE_IN)
	t.tween_property(s, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(s.queue_free)
