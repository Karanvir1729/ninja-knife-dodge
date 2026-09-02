extends Area2D
## Tutorial tap target: a pulsing glow the player is asked to tap.

signal clicked

func _ready() -> void:
	var t := create_tween().set_loops()
	t.tween_property($Glow, "scale", Vector2(0.62, 0.62), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property($Glow, "scale", Vector2(0.48, 0.48), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
