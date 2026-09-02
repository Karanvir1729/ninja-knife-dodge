extends Node2D
## Knife Dodge walkthrough. Same format as the Shuriken Match one: a line of
## instruction at the top, a glowing helper to tap, and a step counter.

const STEPS := [
	"WELCOME TO THE VOID. THE ONLY RULE: STAY AFLOAT.\nTAP BELOW THE STAR, WHERE THE LIGHT IS, TO PROPEL IT UP.",
	"YOU CAN PUSH IT SIDEWAYS OR FROM ABOVE.\nDON'T FALL, AND DON'T TOUCH THE DAGGERS OF LIGHT.",
	"HERE COMES A DAGGER. TAP TO BOUNCE OFF THE WALL AND SLIP PAST.\nEVERY DAGGER THAT LEAVES THE SCREEN SCORES A POINT.",
	"YOU'RE READY. GOOD LUCK.",
]

var knife_scene: PackedScene = preload("res://objects/knife.tscn")
var timer: Timer = null
var step := 0

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	var r := Globals.view_rect()
	%Player.position = Vector2(r.position.x + 260, r.end.y - 200)
	%Player.can_move = false
	$helper.position = %Player.position + Vector2(-64, 72)
	timer = $First
	%Skip.pressed.connect(_finish)
	_set_step(0)

func _set_step(i: int) -> void:
	step = i
	%L1.text = STEPS[i]
	%L1.modulate.a = 0.0
	create_tween().tween_property(%L1, "modulate:a", 1.0, 0.3)
	%Step.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	for j in %Dots.get_child_count():
		var d: ColorRect = %Dots.get_child(j)
		d.color = Globals.CYAN if j == i else Globals.LINE2

func _process(_delta: float) -> void:
	var r := Globals.view_rect()
	var p: CharacterBody2D = %Player
	if p.position.y <= r.position.y:
		p.position.y = r.position.y
		p.velocity.y = absf(p.velocity.y)
	if p.position.y >= r.end.y - 20:
		p.position.y = r.end.y - 20
		p.velocity.y = -absf(p.velocity.y) * 0.5
	if p.position.x >= r.end.x - 10:
		p.position.x = r.end.x - 10
		p.velocity.x = -absf(p.velocity.x)
	if p.position.x <= r.position.x + 10:
		p.position.x = r.position.x + 10
		p.velocity.x = absf(p.velocity.x)

func _on_helper_clicked() -> void:
	%Player.can_move = true
	%Player.jump_away_from($helper.global_position)
	$helper.visible = false
	timer.start()
	for k in %Knives.get_children():
		k.can_move = true

func _on_first_timeout() -> void:
	%Player.can_move = false
	$helper.position = %Player.position + Vector2(120, 50)
	$helper.visible = true
	_set_step(1)
	timer = $Second

func _on_second_timeout() -> void:
	var knife := knife_scene.instantiate()
	knife.position = Vector2(%Player.position.x + 50, Globals.view_rect().position.y - 80)
	knife.direction = Vector2.DOWN
	knife.rotation = knife.direction.angle()
	knife.get_node("Start").wait_time = 0.01
	%Knives.add_child(knife)
	knife.set_glow(Color("5afaff"))
	$KnifeStop.start()
	%Player.can_move = false
	$helper.position = %Player.position + Vector2(120, 150)
	$helper.visible = true
	_set_step(2)
	timer = $Third

func _on_third_timeout() -> void:
	$Third.stop()
	%Player.can_move = false
	_set_step(3)
	$Fourth.start()

func _on_knife_stop_timeout() -> void:
	for k in %Knives.get_children():
		k.can_move = false

func _on_fourth_timeout() -> void:
	_finish()

func _finish() -> void:
	SaveData.set_tutorial_done("knife")
	Globals.go("play")

## Tutorial daggers should never end the run.
func game_over() -> void:
	pass

func increment_score() -> void:
	pass

func near_miss(_at: Vector2) -> void:
	pass
