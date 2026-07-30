extends Node2D

var playState : PackedScene = preload("res://States/play_state.tscn")
var loseState : PackedScene = preload("res://States/lose_state.tscn")
var startState : PackedScene = preload("res://States/start_state.tscn")
var tutorialState : PackedScene = preload("res://States/tutorial_state.tscn")

var states = {
	"play" : playState,
	"lose" : loseState,
	"start": startState,
	"tutorial": tutorialState
}

func _ready():
	$CurrentState.add_child(startState.instantiate())

func change(next, params):
	for n in $CurrentState.get_children():
		$CurrentState.remove_child(n)
		n.queue_free()

	var nextState = states[next].instantiate()
	if  nextState.has_method("init"):
		nextState.init(params)
	$CurrentState.add_child(nextState)
