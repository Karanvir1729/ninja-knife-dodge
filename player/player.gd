extends CharacterBody2D
## The lone star. Tapping anywhere propels it directly away from the tap.

signal jumped

const GRAVITY := 240.0      # px/s^2 (matches the original 4 px/frame at 60 fps)
const MOVE := 550.0
const MAX_FALL := 1400.0

var can_move := true

func _process(delta: float) -> void:
	if not can_move:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	$Trail.direction = -velocity.normalized() if velocity.length() > 5 else Vector2.DOWN
	$Star.rotation += delta * (0.6 + velocity.length() * 0.001)

## Taps that no UI control consumed reach us here, so the pause button no
## longer launches the star. Works for touch (emulated as mouse) and for
## synthetic events from the debug tour.
func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := make_input_local(event) as InputEventMouseButton
		jump_away_from_local(local.position)

## Propel away from a point given relative to the star.
func jump_away_from_local(offset: Vector2) -> void:
	if offset.length() < 1.0:
		offset = Vector2.DOWN
	velocity = -offset.normalized() * MOVE
	AudioManager.play_sfx("jump", randf_range(0.95, 1.08), -6.0)
	_pulse()
	jumped.emit()

func jump_away_from(global_point: Vector2) -> void:
	jump_away_from_local(global_point - global_position)

func _pulse() -> void:
	var t := create_tween()
	$Glow.scale = Vector2(0.95, 0.95)
	t.tween_property($Glow, "scale", Vector2(0.55, 0.55), 0.35).set_ease(Tween.EASE_OUT)

func die() -> void:
	can_move = false
	$Trail.emitting = false
	$Star.visible = false
	$Glow.visible = false
