extends CharacterBody2D

# Declare member variables here
var gravity = 4
var move = 550
var can_move = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if can_move:
		velocity += Vector2.DOWN * gravity
		if Input.is_action_just_pressed("move"):
			velocity = -(get_global_mouse_position() - position).normalized() * move
			$jump.play()
			
		move_and_slide()
