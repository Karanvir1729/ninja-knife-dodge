extends Node2D

var timer = null
var knife_scene : PackedScene = preload("res://objects/knife.tscn")

func init(params):
	pass

func _ready():
	%Player.can_move = false
	timer = $First
	
func _process(delta):
	if %Player.position.y <= 0:
		%Player.position.y = 0
		%Player.velocity.y *= -1
		
	if %Player.position.x >= Globals.WINDOW_WIDTH - 10:
		%Player.position.x = Globals.WINDOW_WIDTH - 10
		%Player.velocity.x *= -1
		
	if %Player.position.x <= 0:
		%Player.position.x = 0
		%Player.velocity.x *= -1
		
func _on_helper_clicked():
	%Player.can_move = true
	timer.start()
	
	if $CanvasLayer/Knives.get_children():
		$CanvasLayer/Knives.get_children()[0].can_move = true

func _on_first_timeout():
	%Player.can_move = false
	$helper.position.y = %Player.position.y + 50
	$helper.position.x = %Player.position.x + 120
	
	%L1.text = "You can even propel sideways or from above the goal is to not fall down or get hit by the daggers of light"
	timer = $Second
	

func _on_second_timeout():
	var knife = knife_scene.instantiate() as Area2D
	knife.position = Vector2(%Player.position.x + 50, -80)
	knife.direction = Vector2.DOWN
	knife.rotation = knife.direction.angle()
	knife.get_node("Start").wait_time = 0.01
	$CanvasLayer/Knives.add_child(knife)
	$KnifeStop.start()
	
	%Player.can_move = false
	$helper.position.y = %Player.position.y + 150
	$helper.position.x = %Player.position.x + 120
	%L1.text = "Here comes a dagger click to bounce of the wall and evade the dagger, every dagger that goes offscreen increases your score"
	timer = $Third

func _on_third_timeout():
	%Player.can_move = false
	%L1.text = "You are ready, good luck"
	$Fourth.start()


func _on_knife_stop_timeout():
	$CanvasLayer/Knives.get_children()[0].can_move = false


func _on_fourth_timeout():
	get_tree().call_group("currentState", "change", "play", {})
