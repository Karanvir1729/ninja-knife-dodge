extends Node2D
## Swaps whole-screen states with a fade. States are scenes whose root may be a
## CanvasLayer or a Node2D; each may implement `init(params)` (called before the
## node enters the tree) and belongs to no group itself - callers reach us via
## the "currentState" group: get_tree().call_group("currentState", "change", name, params)
## or the Globals.go(name, params) shortcut.

const STATES := {
	"start": "res://States/start_state.tscn",
	"tutorial": "res://States/tutorial_state.tscn",
	"play": "res://States/play_state.tscn",
	"lose": "res://States/lose_state.tscn",
	"leaderboard": "res://States/leaderboard_state.tscn",
	"settings": "res://States/settings_state.tscn",
	"match_levels": "res://States/match_levels_state.tscn",
	"match_tutorial": "res://States/match_tutorial_state.tscn",
	"match_play": "res://States/match_play_state.tscn",
	"match_result": "res://States/match_result_state.tscn",
	"arcade_result": "res://States/arcade_result_state.tscn",
	"simon_tutorial": "res://States/simon_tutorial_state.tscn",
	"simon_play": "res://States/simon_play_state.tscn",
	"draw_tutorial": "res://States/draw_tutorial_state.tscn",
	"draw_play": "res://States/draw_play_state.tscn",
}

signal state_changed(state_name: String)

var current_name := ""
var _busy := false
var _cache := {}
var _pending: Array = []

func _ready() -> void:
	_swap("start", {})
	$Transition.snap_clear()

func _scene(state_name: String) -> PackedScene:
	if not _cache.has(state_name):
		var path: String = STATES.get(state_name, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			push_error("Unknown state: " + state_name)
			return null
		_cache[state_name] = load(path)
	return _cache[state_name]

## Requests made mid-transition are queued (last one wins) rather than dropped.
func change(next: String, params: Dictionary = {}) -> void:
	if _busy:
		_pending = [next, params]
		return
	_busy = true
	get_tree().paused = false
	await $Transition.fade_out()
	_swap(next, params)
	await $Transition.fade_in()
	_busy = false
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		change(p[0], p[1])

func is_busy() -> bool:
	return _busy

func _swap(next: String, params: Dictionary) -> void:
	var scene := _scene(next)
	if scene == null:
		return
	for n in $CurrentState.get_children():
		$CurrentState.remove_child(n)
		n.queue_free()
	var node := scene.instantiate()
	if node.has_method("init"):
		node.init(params)
	$CurrentState.add_child(node)
	current_name = next
	state_changed.emit(next)
