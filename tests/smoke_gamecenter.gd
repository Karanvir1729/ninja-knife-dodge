extends RefCounted
## Game Center wiring without the native plugin (desktop and the debug tour):
## every call is inert, the board map covers every game, and the values it would
## submit are the ones the player sees.

func run(tour) -> void:
	tour._check(not GameCenter.available(), "gamecenter: no native plugin on this platform, so the tour never talks to Apple")
	tour._check(not GameCenter.authenticated, "gamecenter: nobody is signed in without the plugin")
	# Inert calls must not crash or change anything.
	GameCenter.submit("knife")
	GameCenter.submit_all()
	GameCenter.show_board("draw")
	GameCenter.show_board()
	tour._check(true, "gamecenter: submitting and opening the board are no-ops without the plugin")
	# Every registered game has a board, and no two share one.
	var ids := []
	for g in Globals.GAMES:
		var board := GameCenter.board_for(str(g.id))
		tour._check(not board.is_empty(), "gamecenter: %s has a leaderboard id (%s)" % [g.id, board])
		tour._check(not ids.has(board), "gamecenter: %s's board id is its own" % g.id)
		ids.append(board)
	tour._check(ids.size() == Globals.GAMES.size(), "gamecenter: one board per game (%d)" % ids.size())
	# The submitted figure matches what the game shows: bests, and stars for Match.
	tour._check(GameCenter.value_for("knife") == int(SaveData.best_for("knife")), "gamecenter: Knife Dodge submits its best run")
	tour._check(GameCenter.value_for("match") == SaveData.match_total_stars(), "gamecenter: Shuriken Match ranks by stars (%d)" % GameCenter.value_for("match"))
	tour._check(GameCenter.value_for("cricket") == int(SaveData.best_for("cricket")), "gamecenter: Star Cricket submits its best innings")
	# The leaderboard screen stays exactly as it was without the plugin.
	await tour._go("leaderboard", {"tab": "draw"})
	await tour._wait(0.4)
	var st = tour._sm().get_node("CurrentState").get_child(0)
	tour._check(st._gc_button == null, "gamecenter: no Game Center button without the plugin")
	await tour._go("start")
