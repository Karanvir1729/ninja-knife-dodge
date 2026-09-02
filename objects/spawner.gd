extends Node2D
## Builds the dagger formations. All positions come from the live viewport
## rectangle so formations cover iPhone and iPad screens edge to edge.

var knife_scene: PackedScene = preload("res://objects/knife.tscn")
var knives: Node = null
var speed_mult := 1.0

const COLOR_DEFAULT := Color(0.66, 0.0, 0.57)
const COLOR_INTERVAL := Color("5afaff")
const COLOR_SPRAY := Color("e20037")
const COLOR_TEETH := Color("e5ec45")

func _ready() -> void:
	var group := get_tree().get_nodes_in_group("knives")
	knives = group[0] if group.size() > 0 else get_parent()

func _player() -> Node2D:
	var p := get_tree().get_nodes_in_group("player")
	return p[0] if p.size() > 0 else null

func _make(pos: Vector2, dir: Vector2, wait: float, color: Color, spd: float = 450.0) -> Node:
	var knife := knife_scene.instantiate()
	knife.position = pos
	knife.direction = dir.normalized()
	knife.rotation = knife.direction.angle()
	knife.speed = spd * speed_mult
	knife.get_node("Start").wait_time = maxf(0.01, wait)
	knives.add_child(knife)
	knife.set_glow(color)
	return knife

## A ring of daggers closes in on the player, one after another.
func circle(params: Dictionary) -> void:
	var player := _player()
	if player == null:
		return
	var n: int = params.num_knives
	for i in range(n):
		var angle := TAU * i / n
		var pos := player.position + Vector2(cos(angle), sin(angle)) * float(params.radius)
		_make(pos, player.position - pos, 0.5 * (i + 1), COLOR_DEFAULT)

## Daggers from random edges, released on the given schedule (seconds).
func interval(params: Dictionary) -> void:
	var r := Globals.view_rect()
	for wait in params.intervals:
		var horizontal := randi() % 2 == 1
		var pos: Vector2
		var dir: Vector2
		if horizontal:
			var from_left := randi() % 2 == 1
			pos = Vector2(r.position.x - 80 if from_left else r.end.x + 80, randf_range(r.position.y + 100, r.end.y - 100))
			dir = Vector2.RIGHT if from_left else Vector2.LEFT
		else:
			var from_top := randi() % 2 == 1
			pos = Vector2(randf_range(r.position.x + 100, r.end.x - 100), r.position.y - 80 if from_top else r.end.y + 80)
			dir = Vector2.DOWN if from_top else Vector2.UP
		_make(pos, dir, float(wait), COLOR_INTERVAL)

## Two daggers from the top corners, aimed at the player.
func spray(_params: Dictionary) -> void:
	var player := _player()
	if player == null:
		return
	var r := Globals.view_rect()
	for corner in [r.position, Vector2(r.end.x, r.position.y)]:
		_make(corner, player.position - corner, 0.5, COLOR_SPRAY)

## Rows of daggers from top and bottom that snap shut like teeth.
func teeth(params: Dictionary) -> void:
	var r := Globals.view_rect()
	var n: int = params.num_knives
	var step := (r.size.x - 100.0) / n
	for i in range(n):
		var x := r.position.x + step * (i + 1) + 50.0
		_make(Vector2(x, r.position.y - 80), Vector2.DOWN, i * 0.3, COLOR_TEETH, 600.0)
		_make(Vector2(x - 10, r.end.y + 80), Vector2.UP, i * 0.3, COLOR_TEETH, 600.0)

func spawn(data: Dictionary) -> void:
	match data.type:
		"circle": circle(data.params)
		"interval": interval(data.params)
		"spray": spray(data.params)
		"teeth": teeth(data.params)
