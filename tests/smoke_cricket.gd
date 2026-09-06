extends RefCounted
## Star Cricket smoke checks, run by the debug tour (autoload/DebugTour.gd):
## a perfect swing is a six (into a gap and into a fielder alike), pause
## works, unplayed balls on the stumps take the wickets, the life offer
## appears and declining it lands on the arcade results. Then walk the
## tutorial with on-time swings until it hands over to a real innings.

func run(tour) -> void:
	var y: float = tour.get_tree().root.size.y * 0.7
	await tour._go("cricket_play")
	var play = tour._sm().get_node("CurrentState").get_child(0)
	await tour._wait_until(func(): return play.ball_in_flight, 6.0)
	tour._check(play.ball_in_flight, "cricket: the first ball is released within 6s")
	if not play.ball_in_flight:
		return
	await tour._wait_until(func(): return play.ball_in_flight and play.time_to_arrival() <= 0.02, 4.0)
	var gaps: Array = play.gap_zones()
	tour._check(gaps.size() == 2, "cricket: three fielders leave two gaps (%s)" % [gaps])
	tour._check(play.ball_in_flight and play.time_to_arrival() <= 0.02, "cricket: the ball reached the crease (tta=%.3f)" % play.time_to_arrival())
	play.tap_at(Vector2(play.zone_center_x(gaps[0] if not gaps.is_empty() else 2), y))
	tour._check(play.runs == 6, "cricket: a perfect swing is a six (runs=%d)" % play.runs)
	tour._check(play.balls == 1 and play.sixes == 1, "cricket: the ball and the six are counted (balls=%d, sixes=%d)" % [play.balls, play.sixes])
	await tour._wait(0.3)
	await tour._shot("smoke_cricket_six")
	play.debug_skip_wait()
	await tour._wait_until(func(): return play.ball_in_flight and play.time_to_arrival() <= 0.02, 5.0)
	var fielder_zone := 0
	while play.gap_zones().has(fielder_zone) and fielder_zone < 4:
		fielder_zone += 1
	tour._check(not play.gap_zones().has(fielder_zone), "cricket: picked a fielder zone (%d, gaps=%s)" % [fielder_zone, play.gap_zones()])
	play.tap_at(Vector2(play.zone_center_x(fielder_zone), y))
	tour._check(play.runs == 12, "cricket: a perfect swing into a fielder is still a six (runs=%d)" % play.runs)
	await tour._wait(0.3)
	play.toggle_pause()
	await tour._wait(0.3)
	tour._check(play.paused and tour.get_tree().paused, "cricket: pause toggles the tree pause")
	await tour._shot("smoke_cricket_paused")
	play.toggle_pause()
	# Let balls pass without swinging: the ones on the stumps take the wickets.
	SaveData.data.boosters.life = 0
	var passed := 0
	while play.wickets_left > 0 and passed < 12:
		play.debug_skip_wait()
		await tour._wait_until(func(): return play.ball_in_flight or play.wickets_left == 0, 4.0)
		await tour._wait_until(func(): return not play.ball_in_flight or play.wickets_left == 0, 4.0)
		passed += 1
	tour._check(play.wickets_left == 0, "cricket: unplayed balls on the stumps take the wickets (%d balls, wickets_left=%d)" % [passed, play.wickets_left])
	tour._check(play.runs == 12, "cricket: dot balls and wickets add no runs (runs=%d)" % play.runs)
	# With the mock ad provider a life offer appears; decline it.
	await tour._wait_until(func(): return _offer(tour) != null, 3.0)
	var offer = _offer(tour)
	tour._check(offer != null, "cricket: the last wicket offers a life")
	if offer != null:
		await tour._wait(0.3)
		await tour._shot("smoke_cricket_offer")
		offer.choose("no")
	await tour._wait_until(func(): return tour._sm().current_name == "arcade_result", 8.0)
	tour._check(tour._sm().current_name == "arcade_result", "cricket: declining the offer ends on the results (state=%s)" % tour._sm().current_name)
	await tour._wait(1.3)
	await tour._shot("smoke_cricket_result")
	# --- Tutorial: swing on time through every step into a real innings.
	await tour._go("cricket_tutorial")
	await tour._wait(0.4)
	var tut = tour._sm().get_node("CurrentState").get_child(0)
	tour._check(tut.step == -1 and tut._in_intro, "cricket tutorial: opens on the story beat")
	await tour._shot("smoke_cricket_tutorial_story")
	tut.dismiss_intro()
	await tour._wait(0.3)
	tour._check(tut.step == 0, "cricket tutorial: starts on step 1")
	await tour._shot("smoke_cricket_tutorial")
	var t0 := Time.get_ticks_msec()
	var swings := 0
	while tour._sm().current_name == "cricket_tutorial" and Time.get_ticks_msec() - t0 < 25000:
		if not is_instance_valid(tut) or tut.step >= 3:
			await tour._frames(1)
			continue
		await tour._wait_until(func(): return not is_instance_valid(tut) or tut.step >= 3 or (tut.ball_in_flight and tut.time_to_arrival() <= 0.02), 6.0)
		if not is_instance_valid(tut) or not tut.ball_in_flight:
			continue
		var g: Array = tut.gap_zones()
		var s: int = tut.step
		tut.tap_at(Vector2(tut.zone_center_x(g[0] if not g.is_empty() else 2), y))
		swings += 1
		if s == 1:
			await tour._wait(0.3)
			await tour._shot("smoke_cricket_tutorial_gap")
		await tour._wait_until(func(): return not is_instance_valid(tut) or tut.step != s, 3.0)
	tour._check(swings == 3, "cricket tutorial: one on-time swing per step (%d)" % swings)
	await tour._wait_until(func(): return tour._sm().current_name == "cricket_play", 5.0)
	tour._check(tour._sm().current_name == "cricket_play", "cricket tutorial: finishes into an innings (state=%s)" % tour._sm().current_name)
	tour._check(SaveData.tutorial_done("cricket"), "cricket tutorial: marked done")
	# Leave on the quiet menu so no SFX is mid-playback when the tour quits.
	await tour._go("start")
	await tour._wait(0.6)

func _offer(tour) -> Node:
	for c in tour.get_tree().root.get_children():
		if c is OfferOverlay:
			return c
	return null
