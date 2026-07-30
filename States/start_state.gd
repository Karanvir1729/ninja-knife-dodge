extends CanvasLayer
var knife_scene : PackedScene = preload("res://objects/knife.tscn")

func _ready():
	resize()
	get_tree().get_root().size_changed.connect(resize)
	
func init(params):
	pass
	
func resize():
	for child in $Knives.get_children():
		child.queue_free()
	for child in $Lights.get_children():
		child.queue_free()
		
	var knife_texture = load("res://graphics/skeleton_sword.png")
	var circle_texture = load("res://graphics/circle.png")
	
	var player = $HFlowContainer
	for i in range(6):
		var angle = 2 * PI * i / 6
		
		# Calculate the position of each dot
		var x = 200 * cos(angle) + (player.position.x + 40)
		var y = 200 * sin(angle) + (player.position.y + 40)
		# Create a new Sprite2D node
		var knife_sprite = Sprite2D.new()
		# Assign the texture to the sprite
		knife_sprite.texture = knife_texture
		knife_sprite.position = Vector2(x, y)
		knife_sprite.rotation = (player.position - knife_sprite.position).angle()
		$Knives.add_child(knife_sprite)
		
		var light = PointLight2D.new()
		light.texture = circle_texture
		light.energy = 8
		
		x = 400 * cos(angle) + (player.position.x + 40)
		y = 400 * sin(angle) + (player.position.y + 40)
		light.position = Vector2(x, y)  # Adjust as needed
		light.range_layer_max = 1
		light.color = "#a90090"
		# Add the light to the scene
		$Lights.add_child(light)

func _on_button_pressed():
	if FileAccess.file_exists("user://tutorial_done"):
		get_tree().call_group("currentState", "change", "play", {})
	else:
		var f = FileAccess.open("user://tutorial_done", FileAccess.WRITE)
		f.store_8(1)
		f.close()
		get_tree().call_group("currentState", "change", "tutorial", {})
