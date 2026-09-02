extends Node2D
## Quick Draw walkthrough, in the same format as the other tutorials: an
## instruction on top, a glowing helper on the thing to tap, and step dots.

const TARGET_SCENE: PackedScene = preload("res://draw/target.tscn")
const STEPS := [
	"TAP THE TARGET BEFORE ITS RING CLOSES.",
	"NEVER TAP THE RED DAGGERS. LET THEM PASS.",
	"THREE MISSES AND IT'S OVER. CHAIN HITS FOR COMBOS.",
]

var step := -1
var _target: DrawTarget = null
var _done := false
var _flash_tween: Tween

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Skip.pressed.connect(func(): AudioManager.back(); _finish())
	$Helper.visible = false
	var t := create_tween().set_loops()
	t.tween_property($Helper/Glow, "scale", Vector2(0.62, 0.62), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property($Helper/Glow, "scale", Vector2(0.48, 0.48), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_set_step(0)

func _layout() -> void:
	Globals.apply_safe_margins(%Root, 30)
	if _target and is_instance_valid(_target) and _target.alive:
		_target.position = _stage_center()
		$Helper.position = _target.position

## Where the demo target sits: centre of the screen, below the instruction.
func _stage_center() -> Vector2:
	var r := Globals.view_rect()
	return Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.56)

func _process(delta: float) -> void:
	if _target and is_instance_valid(_target) and _target.alive:
		_target.tick(delta)

func _set_step(i: int) -> void:
	step = i
	%L1.text = STEPS[i]
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.3)
	%Step.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	for j in %Dots.get_child_count():
		var d: ColorRect = %Dots.get_child(j)
		d.color = Globals.ORANGE if j == i else Globals.LINE2
	match i:
		0:
			_spawn_demo_target()
		1:
			_spawn_demo_decoy()
			await get_tree().create_timer(1.6).timeout
			if step == 1 and not _done:
				_set_step(2)
		2:
			$Helper.visible = false
			await get_tree().create_timer(1.4).timeout
			if not _done:
				_finish()

## Step 1: one slow target that only expires when tapped.
func _spawn_demo_target() -> void:
	var t: DrawTarget = TARGET_SCENE.instantiate()
	t.lifetime = 3.0
	t.hold = true
	t.color = Globals.CYAN
	t.spin = 0.8
	t.position = _stage_center()
	%Targets.add_child(t)
	_target = t
	$Helper.position = t.position
	$Helper.visible = true
	AudioManager.play_sfx("target_spawn", 1.0, -8.0)

## Step 2: a decoy drifts by; tapping it only flashes the instruction.
func _spawn_demo_decoy() -> void:
	var t: DrawTarget = TARGET_SCENE.instantiate()
	t.is_decoy = true
	t.lifetime = 1.6
	t.drift = Vector2(70.0, -12.0)
	t.position = _stage_center() - t.drift * 0.8
	%Targets.add_child(t)
	_target = t
	$Helper.visible = false
	AudioManager.play_sfx("target_spawn", 0.72, -10.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(event.position)

func tap_at(global_pos: Vector2) -> void:
	if _done or _target == null or not is_instance_valid(_target) or not _target.alive:
		return
	if _target.global_position.distance_to(global_pos) > _target.tap_radius():
		return
	var at: Vector2 = $FX.to_local(_target.global_position)
	if _target.is_decoy:
		AudioManager.play_sfx("decoy_hit", 1.0, -6.0)
		AudioManager.vibrate(40)
		$FX.popup("NOT THAT ONE", at, Globals.RED, 22)
		_flash_text()
		return
	AudioManager.play_sfx("target_hit")
	AudioManager.vibrate(10)
	$FX.burst(at, _target.color, 9, 110.0)
	$FX.ring(at, _target.color, 1.1)
	$FX.popup("+1", at, _target.color)
	_target.pop()
	$Helper.visible = false
	if step == 0:
		_set_step(1)

func _flash_text() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(%L1, "modulate", Color(1, 0.45, 0.55, 1), 0.08)
	_flash_tween.tween_property(%L1, "modulate", Color.WHITE, 0.3)

func _finish() -> void:
	if _done:
		return
	_done = true
	SaveData.set_tutorial_done("draw")
	Globals.go("draw_play")
