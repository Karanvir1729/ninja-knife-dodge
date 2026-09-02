extends Node2D
## Sensei Says walkthrough, in the shared tutorial format: instruction on top,
## a glowing helper on the pad to tap, step dots at the bottom.

const STEPS := [
	"WATCH THE PADS LIGHT UP. SENSEI SHOWS A PATTERN.",
	"NOW TAP THEM BACK IN THE SAME ORDER.",
	"EACH ROUND ADDS ONE PAD. MISS ONE AND THE ROUND ENDS.",
]
## Fixed demo pattern: the centre pad, then the top-left one.
const DEMO: Array[int] = [4, 0]

var step := -1
var _progress := 0
var _done := false

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("match")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Skip.pressed.connect(func(): AudioManager.back(); _finish())
	%Grid.pad_tapped.connect(press_pad)
	var pulse := create_tween().set_loops()
	pulse.tween_property($UI/Helper/Glow, "scale", Vector2(0.68, 0.68), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property($UI/Helper/Glow, "scale", Vector2(0.5, 0.5), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_set_step(0)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, 30)
	var r := Globals.view_rect()
	var ins := Globals.safe_insets()
	var avail_h: float = r.size.y - 60.0 - float(ins.top) - float(ins.bottom) - 190.0
	var avail_w: float = r.size.x - 60.0 - float(ins.left) - float(ins.right) - 200.0
	var side := floorf(clampf(minf(avail_h, avail_w), 360.0, 760.0))
	%BoardPanel.custom_minimum_size = Vector2(side, side)
	if step == 1:
		call_deferred("_point_next")

func _set_step(i: int) -> void:
	step = i
	%L1.text = STEPS[i]
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.3)
	%Step.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	for j in %Dots.get_child_count():
		var d: ColorRect = %Dots.get_child(j)
		d.color = Globals.VIOLET if j == i else Globals.LINE2
	$UI/Helper.visible = false
	match i:
		0:
			%Grid.input_enabled = false
			await %Grid.sleep(0.8)
			if _done:
				return
			AudioManager.play_sfx("simon_watch")
			await %Grid.play_sequence(DEMO, 0.6)
			if _done:
				return
			await %Grid.sleep(0.4)
			if _done:
				return
			_set_step(1)
		1:
			_progress = 0
			%Grid.input_enabled = true
			_point_next()
		2:
			%Grid.input_enabled = false
			await %Grid.sleep(1.4)
			if _done:
				return
			_finish()

## Same path a real tap takes (the grid routes pad taps here).
func press_pad(index: int) -> void:
	if step != 1 or _done:
		return
	if index == DEMO[_progress]:
		%Grid.light(index, 0.32)
		_progress += 1
		if _progress >= DEMO.size():
			%Grid.input_enabled = false
			$UI/Helper.visible = false
			AudioManager.play_sfx("simon_round")
			AudioManager.vibrate(20)
			_set_step(2)
		else:
			_point_next()
	else:
		AudioManager.play_sfx("simon_fail", 1.0, -8.0)
		%Grid.flash_wrong(index)
		_flash_text()
		_progress = 0
		_point_next()

func _point_next() -> void:
	if step != 1 or _progress >= DEMO.size():
		return
	$UI/Helper.position = %Grid.pad_center(DEMO[_progress])
	$UI/Helper.visible = true

func _flash_text() -> void:
	var t := create_tween()
	t.tween_property(%L1, "modulate", Color(1, 0.6, 0.8, 1), 0.08)
	t.tween_property(%L1, "modulate", Color.WHITE, 0.25)

func _finish() -> void:
	if _done:
		return
	_done = true
	SaveData.set_tutorial_done("simon")
	Globals.go("simon_play")
