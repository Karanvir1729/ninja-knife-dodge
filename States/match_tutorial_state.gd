extends Node2D
## Shuriken Match walkthrough, in the same format as Knife Dodge's: instruction
## on top, a glowing helper on the tile to tap, an arrow to its partner, step dots.

const STEPS := [
	"TAP A SHURIKEN, THEN TAP ITS NEIGHBOUR TO SWAP THEM.\nTHREE IN A LINE CLEARS THEM.",
	"FOUR IN A LINE FORGES A LINE SHURIKEN.\nSWAP THE HIGHLIGHTED ONE DOWN TO MAKE FOUR.",
	"NOW SWAP THE LINE SHURIKEN WITH ANY NEIGHBOUR.\nIT BLASTS ITS WHOLE ROW OR COLUMN.",
	"EVERY LEVEL HAS A TARGET SCORE AND A MOVE LIMIT.\nCHAIN REACTIONS MULTIPLY YOUR SCORE.",
	"YOU'RE READY. LINE THEM UP.",
]

var level := 1
var return_to := ""
var step := -1

func init(p: Dictionary) -> void:
	level = int(p.get("level", 1))
	return_to = str(p.get("return", ""))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("match")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Skip.pressed.connect(func(): AudioManager.back(); _finish())
	%Next.pressed.connect(func(): AudioManager.click(); _set_step(step + 1))
	%Board.hints_enabled = false
	%Board.board_settled.connect(_on_settled)
	%Board.special_created.connect(_on_special_created)
	%Board.special_fired.connect(_on_special_fired)
	%Board.swap_rejected.connect(func(): _flash_text())
	_set_step(0)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, 30)
	var r := Globals.view_rect()
	var avail_h := r.size.y - 60 - 170 - 80
	var side := minf(avail_h / 0.78, r.size.x - 60 - 240)
	%BoardPanel.custom_minimum_size = Vector2(side, side * 0.78)

func _set_step(i: int) -> void:
	step = i
	%L1.text = STEPS[i]
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.3)
	%Step.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	for j in %Dots.get_child_count():
		var d: ColorRect = %Dots.get_child(j)
		d.color = Globals.MAGENTA if j == i else Globals.LINE2
	%Next.visible = false
	$UI/Arrow.visible = false
	$UI/Helper.visible = false
	match i:
		0:
			_load(TutorialLayouts.step_match3())
		1:
			_load(TutorialLayouts.step_line())
		2:
			pass  # set up by _on_special_created
		3:
			%Board.interactive = false
			%Next.visible = true
		4:
			%Board.interactive = false
			await get_tree().create_timer(1.4).timeout
			_finish()

func _load(d: Dictionary) -> void:
	var model := BoardModel.new(8, 6, 5, 11)
	model.load_layout(d.layout)
	%Board.setup(model)
	%Board.interactive = true
	%Board.allowed_move = [d.from, d.to]
	await get_tree().process_frame
	_point(d.from, d.to)

func _point(a: Vector2i, b: Vector2i) -> void:
	var pa: Vector2 = %Board.cell_global(a)
	var pb: Vector2 = %Board.cell_global(b)
	$UI/Helper.position = pa
	$UI/Helper.visible = true
	%Board.highlight(b, true)
	$UI/Arrow.point(pa, pb)
	$UI/Arrow.visible = true

func _flash_text() -> void:
	var t := create_tween()
	t.tween_property(%L1, "modulate", Color(1, 0.6, 0.8, 1), 0.08)
	t.tween_property(%L1, "modulate", Color.WHITE, 0.25)

func _on_settled() -> void:
	if step == 0:
		_set_step(1)

func _on_special_created(kind: int, _at: Vector2) -> void:
	if step != 1:
		return
	# Find where the line shuriken ends up after the drop (the board is settled
	# when board_settled fires; defer until then).
	await %Board.board_settled
	var model: BoardModel = %Board.model
	for r in model.rows:
		for c in model.cols:
			var cell := Vector2i(c, r)
			if model.get_special(cell) != BoardModel.Special.NONE:
				var nb := cell + (Vector2i(1, 0) if c < model.cols - 1 else Vector2i(-1, 0))
				%Board.allowed_move = [cell, nb]
				_set_step(2)
				_point(cell, nb)
				return
	_set_step(3)

func _on_special_fired(_kind: int, _at: Vector2, _combo: String) -> void:
	if step == 2:
		%Board.allowed_move = []
		await %Board.board_settled
		_set_step(3)

func _finish() -> void:
	SaveData.set_tutorial_done("match")
	if return_to == "levels":
		Globals.go("match_levels")
	else:
		Globals.go("match_play", {"level": level})
