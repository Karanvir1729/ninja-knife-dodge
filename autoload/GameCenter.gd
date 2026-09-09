extends Node
## Game Center leaderboards. The native AppleGameCenter plugin signs the player
## in when the game launches (iOS only), every best score the save records is
## submitted to that game's board, and the leaderboard screen can open Apple's
## own board over the game.
##
## Without the plugin - desktop, the editor, the debug tour - every call here is
## a no-op, so nothing on those platforms touches the network or the UI.

signal state_changed

## Game id -> the leaderboard's vendor id in App Store Connect.
const BOARDS := {
	"knife": "nkd_knife_best",
	"draw": "nkd_draw_best",
	"match": "nkd_match_stars",
	"simon": "nkd_simon_round",
	"cricket": "nkd_cricket_runs",
}

var authenticated := false
var alias := ""
var last_error := ""
var _plugin: Object

func _ready() -> void:
	if not Engine.has_singleton("AppleGameCenter"):
		return
	_plugin = Engine.get_singleton("AppleGameCenter")
	_plugin.connect("authenticated", _on_authenticated)
	_plugin.connect("score_reported", _on_score_reported)
	# GameKit wants its handler set early; the sign-in banner shows itself.
	call_deferred("_authenticate")

func _authenticate() -> void:
	if _plugin != null:
		_plugin.call("authenticate")

## Is Game Center available at all (the native plugin is in this build)?
func available() -> bool:
	return _plugin != null

func board_for(game_id: String) -> String:
	return str(BOARDS.get(game_id, ""))

## The number that stands on a game's board: the same figure the hub shows,
## except Shuriken Match, which ranks by stars collected rather than level.
func value_for(game_id: String) -> int:
	if game_id == "match":
		return SaveData.match_total_stars()
	return int(SaveData.best_for(game_id))

## Submit one game's current best. Scores earned before sign-in are not lost:
## every board is submitted again as soon as the player is authenticated.
func submit(game_id: String) -> void:
	if _plugin == null or not authenticated:
		return
	var board := board_for(game_id)
	var value := value_for(game_id)
	if board.is_empty() or value <= 0:
		return
	_plugin.call("report_score", board, value)

func submit_all() -> void:
	for id in BOARDS.keys():
		submit(str(id))

## Open Apple's leaderboard UI: one game's board, or the whole list for "".
func show_board(game_id: String = "") -> void:
	if _plugin == null:
		return
	_plugin.call("show_leaderboard", board_for(game_id))

func _on_authenticated(ok: bool, p_alias: String, _player_id: String) -> void:
	authenticated = ok
	alias = p_alias
	state_changed.emit()
	if ok:
		submit_all()

func _on_score_reported(board: String, ok: bool, message: String) -> void:
	if not ok:
		last_error = message
		push_warning("Game Center: %s did not accept a score: %s" % [board, message])
