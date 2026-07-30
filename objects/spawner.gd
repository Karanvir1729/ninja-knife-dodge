extends Node2D

var knife_scene : PackedScene = preload("res://objects/knife.tscn")
var knives = null

func _ready():
	knives = get_tree().get_nodes_in_group("knives")[0]
	
func circle(params):
	var player = get_tree().get_nodes_in_group("player")[0]
	for i in range(params.num_knives):
		# Calculate the angle for each dot
		var angle = 2 * PI * i / params.num_knives
		
		# Calculate the position of each dot
		var x = params.radius * cos(angle) + player.position.x
		var y = params.radius * sin(angle) + player.position.y
		var knife = knife_scene.instantiate() as Area2D
		knife.position = Vector2(x, y)
		knife.direction = (player.position - knife.position).normalized()
		knife.rotation = knife.direction.angle()
		knife.get_node("Start").wait_time = 0.5 * (i + 1)
		knives.add_child(knife)

func interval(params):	
	var left_right = [-80, Globals.WINDOW_WIDTH + 80]
	var up_down = [-80, Globals.WINDOW_HEIGHT + 80]
	
	for i in params.intervals:
		var knife = knife_scene.instantiate() as Area2D
		var horizontal = randi() % 2
		if horizontal:
			var left = randi() % 2
			knife.position = Vector2(left_right[left], (randi() % Globals.WINDOW_HEIGHT- 200) + 100)
			knife.direction = Vector2.LEFT if left else Vector2.RIGHT
		else:
			var up = randi() % 2
			knife.position = Vector2((randi() % Globals.WINDOW_WIDTH - 200) + 100, up_down[up])
			knife.direction = Vector2.UP if up else Vector2.DOWN
			
		knife.rotation = knife.direction.angle()
		knife.get_node("Start").wait_time = i
		knife.get_node("PointLight2D").color = "#5afaff"
		knives.add_child(knife)

func spray(params):
	var player = get_tree().get_nodes_in_group("player")[0]
	var knife = knife_scene.instantiate() as Area2D
	knife.position = Vector2(0, 0)
	knife.direction = (player.position - knife.position).normalized()
	knife.rotation = knife.direction.angle()
	knife.get_node("Start").wait_time = 0.5
	knife.get_node("PointLight2D").color = "#e20037"
	knives.add_child(knife)
	
	knife = knife_scene.instantiate() as Area2D
	knife.position = Vector2(Globals.WINDOW_WIDTH, 0)
	knife.direction = (player.position - knife.position).normalized()
	knife.rotation = knife.direction.angle()
	knife.get_node("Start").wait_time = 0.5
	knife.get_node("PointLight2D").color = "#e20037"
	knives.add_child(knife)

func teeth(params):	
	for i in range(params.num_knives):
		var knife = knife_scene.instantiate() as Area2D
		knife.position = Vector2((Globals.WINDOW_WIDTH - 100) / params.num_knives * (i + 1) + 50, -80)
		knife.direction = Vector2.DOWN
			
		knife.rotation = knife.direction.angle()
		knife.speed = 600
		knife.get_node("Start").wait_time = (i * 0.3)
		knife.get_node("PointLight2D").color = "#e5ec45"
		knives.add_child(knife)
		
		knife = knife_scene.instantiate() as Area2D
		knife.position = Vector2((Globals.WINDOW_WIDTH - 100) / params.num_knives * (i + 1) + 40, Globals.WINDOW_HEIGHT + 80)
		knife.direction = Vector2.UP
			
		knife.rotation = knife.direction.angle()
		knife.speed = 600
		knife.get_node("Start").wait_time = (i * 0.3)
		knife.get_node("PointLight2D").color = "#e5ec45"
		knives.add_child(knife)
			
func spawn(data):
	match data.type:
		"circle":
			circle(data.params)
		"interval":
			interval(data.params)
		"spray":
			spray(data.params)
		"teeth":
			teeth(data.params)
