extends Node2D

var knife_scene : PackedScene = preload("res://objects/knife.tscn")
var lose : PackedScene = preload("res://States/lose_state.tscn")

var score = 0
var wave = 0
var repeat = 1

var stages = [
	{"type" : "interval", "params": {"intervals": [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7]}, "wait": 10},
	{"type" : "spray", "params": {}, "wait": 0.5, "repeat": 5},
	{"type" : "circle", "params": {"num_knives": 8, "radius": 400}, "wait": 3, "repeat": 3},
	{"type" : "teeth", "params": {"num_knives": 5}, "wait": 5},
	{"type" : "interval", "params": {"intervals": [1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 7, 7]}, "wait": 10},
	{"type" : "spray", "params": {}, "wait": 0.5, "repeat": 10},
	{"type" : "circle", "params": {"num_knives": 10, "radius": 350}, "wait": 3, "repeat": 5},
	{"type" : "teeth", "params": {"num_knives": 10}, "wait": 5},
	{"type" : "spray", "params": {}, "wait": 0.5, "repeat": 15},
	{"type" : "circle", "params": {"num_knives": 10, "radius": 300}, "wait": 3, "repeat": 7},
	{"type" : "teeth", "params": {"num_knives": 20}, "wait": 5},
	{"type" : "spray", "params": {}, "wait": 0.5, "repeat": 20},
	{"type" : "teeth", "params": {"num_knives": 30}, "wait": 5},
]

func init(params):
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _ready():
	$Spawn.start()
	
func _process(delta):
	if %Player.position.y >= Globals.WINDOW_HEIGHT:
		game_over()
		
	if %Player.position.y <= 0:
		%Player.position.y = 0
		%Player.velocity.y *= -1
		
	if %Player.position.x >= Globals.WINDOW_WIDTH - 10:
		%Player.position.x = Globals.WINDOW_WIDTH - 10
		%Player.velocity.x *= -1
		
	if %Player.position.x <= 0:
		%Player.position.x = 0
		%Player.velocity.x *= -1

func _on_spawn_timeout():
	var stage = stages[wave]
	$Spawner.spawn(stage)
	$Spawn.wait_time = stage["wait"]
	if (stage.get("repeat") and stage["repeat"] > repeat):
		repeat += 1
	else:
		if repeat > 1:
			$Spawn.wait_time = 2
			repeat = 1
		wave = (wave + 1) % len(stages)
	$Spawn.start()
	
	

func game_over():
	get_tree().call_group("currentState", "change", "lose", {"score": score})

func increment_score():
	$play_ui.increment_score()
	score += 1
