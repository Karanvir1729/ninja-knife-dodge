extends Area2D
# https://opengameart.org/users/inog

var speed : int = 450
var direction : Vector2 = Vector2.RIGHT
var increment = false
var can_move = true
var lose : PackedScene = preload("res://States/lose_state.tscn")
signal offScreen()

func _ready():
	$Start.start()

func _process(delta):
	if increment and can_move:
		position += direction * speed * delta


func _on_start_timeout():
	increment = true


func _on_body_entered(body):
	if (body.name == "Player"):
		get_tree().call_group("playstate", "game_over")

func _on_off_screen_screen_exited():
	get_tree().call_group("playstate", "increment_score")
	queue_free()
