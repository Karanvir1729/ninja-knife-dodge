extends RefCounted
## Sensei Says smoke checks for the debug tour (`godot --path . -- --tour=DIR`):
## plays round 1 through press_pad, taps a pad through the real input path,
## fails on purpose with no lives left, declines the extra-life offer and
## expects the results screen. Then walks the tutorial to the game.

func run(tour) -> void:
	await tour._go("simon_play")
	var play = tour._sm().get_node("CurrentState").get_child(0)
	await tour._wait_until(func(): return play.phase == "input", 10.0)
	tour._check(play.phase == "input", "simon: round 1 playback finished and input opened (phase=%s)" % play.phase)
	tour._check(play.round == 1 and play.sequence.size() == 1, "simon: round 1 shows a one-pad sequence (round=%d, len=%d)" % [play.round, play.sequence.size()])
	await tour._shot("smoke_simon_your_turn")
	# Pause and resume while waiting for input; the idle timer must not run.
	play.toggle_pause()
	await tour._wait(0.3)
	tour._check(play.paused and tour.get_tree().paused, "simon: pause opens the overlay and halts the tree")
	await tour._shot("smoke_simon_paused")
	play.toggle_pause()
	await tour._frames(2)
	tour._check(not play.paused and play.phase == "input", "simon: resume returns to the player's turn")
	# Play the round back through the public API.
	for i in play.sequence.duplicate():
		play.press_pad(i)
		await tour._frames(2)
	await tour._wait_until(func(): return play.round == 2, 4.0)
	tour._check(play.round == 2, "simon: completing the sequence advances to round 2 (round=%d)" % play.round)
	tour._check(play.rounds_completed == 1, "simon: rounds_completed counts the cleared round (%d)" % play.rounds_completed)
	await tour._wait_until(func(): return play.phase == "input", 10.0)
	tour._check(play.phase == "input" and play.sequence.size() == 2, "simon: round 2 shows two pads and opens input (phase=%s, len=%d)" % [play.phase, play.sequence.size()])
	# A synthetic tap through the real input pipeline on the first pad.
	var grid = play.get_node("%Grid")
	var taps_before: int = play.taps
	var centre: Vector2 = grid.pad_center(play.sequence[0])
	tour._click(play.get_viewport().get_final_transform() * centre)
	await tour._frames(3)
	tour._check(play.taps == taps_before + 1 and play.phase == "input", "simon: a real tap on the lit pad is counted as a correct press (taps=%d)" % play.taps)
	# Now a wrong pad with no lives left: the mock ad provider still offers a
	# life, so decline it and expect the results screen.
	SaveData.data.boosters.life = 0
	var wrong := 0
	while wrong in play.sequence:
		wrong += 1
	play.press_pad(wrong)
	await tour._frames(2)
	tour._check(play.phase != "input", "simon: a wrong tap ends the player's turn (phase=%s)" % play.phase)
	await tour._wait_until(func(): return _offer(tour) != null, 3.0)
	var offer = _offer(tour)
	tour._check(offer != null, "simon: the extra-life offer appears once after a miss")
	if offer:
		await tour._shot("smoke_simon_offer")
		offer.choose("no")
	await tour._wait_until(func(): return tour._sm().current_name == "arcade_result", 4.0)
	tour._check(tour._sm().current_name == "arcade_result", "simon: declining the extra life leads to the results screen (state=%s)" % tour._sm().current_name)
	await tour._wait(1.3)
	await tour._shot("smoke_simon_result")
	# --- Tutorial: the demo plays itself, then taps walk it to the game.
	await tour._go("simon_tutorial")
	var tut = tour._sm().get_node("CurrentState").get_child(0)
	await tour._wait_until(func(): return tut.step == 1, 8.0)
	tour._check(tut.step == 1, "simon tutorial: the demo pattern plays and step 2 asks for taps (step=%d)" % tut.step)
	await tour._wait(0.3)
	await tour._shot("smoke_simon_tutorial_step2")
	var bad := 0
	while bad in tut.DEMO:
		bad += 1
	tut.press_pad(bad)
	await tour._frames(2)
	tour._check(tut.step == 1, "simon tutorial: a wrong tap keeps step 2 waiting")
	for i in tut.DEMO:
		tut.press_pad(i)
		await tour._frames(2)
	await tour._wait_until(func(): return tut.step == 2, 4.0)
	tour._check(tut.step == 2, "simon tutorial: the correct taps advance to step 3 (step=%d)" % tut.step)
	await tour._wait_until(func(): return tour._sm().current_name == "simon_play", 4.0)
	tour._check(tour._sm().current_name == "simon_play", "simon tutorial: finishes into a real game (state=%s)" % tour._sm().current_name)
	# Leave the game on the quiet menu so no round SFX is mid-playback when
	# the tour quits (otherwise Godot reports the stream as still in use).
	await tour._go("start")
	await tour._wait(1.0)

func _offer(tour) -> Node:
	for c in tour.get_tree().root.get_children():
		if c is OfferOverlay:
			return c
	return null
