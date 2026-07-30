extends Area2D

signal clicked

func _on_input_event(viewport, event, shape_idx):
	if (Input.is_action_just_pressed("move")):
		clicked.emit()
