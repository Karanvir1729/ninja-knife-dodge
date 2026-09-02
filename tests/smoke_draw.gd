extends RefCounted
## Quick Draw smoke checks, run by the debug tour (autoload/DebugTour.gd):
## hit a target through the tap path, run out of lives, decline the life offer
## and land on the arcade results screen. Then walk the tutorial.

func run(tour) -> void:
	await tour._go("draw_play")
	var play = tour._sm().get_node("CurrentState").get_child(0)
	await tour._wait_until(func(): return _first_shuriken(play) != null, 6.0)
	var target = _first_shuriken(play)
	tour._check(target != null, "draw: a shuriken target spawned within 6s")
	if target == null:
		return
	play.tap_at(target.global_position)
	await tour._frames(2)
	tour._check(play.score > 0, "draw: tapping a target scores (score=%d)" % play.score)
	tour._check(play.hits == 1, "draw: hit counted once (hits=%d)" % play.hits)
	tour._check(play.combo == 1, "draw: combo started (combo=%d)" % play.combo)
	await tour._wait(0.3)
	await tour._shot("smoke_draw_hit")
	# Chain five more hits: combo 5 is a milestone and hits start paying +2.
	for i in 5:
		await tour._wait_until(func(): return _first_shuriken(play) != null, 6.0)
		var next = _first_shuriken(play)
		if next == null:
			break
		play.tap_at(next.global_position)
		await tour._frames(2)
	tour._check(play.combo == 6, "draw: six straight hits build a x6 combo (combo=%d)" % play.combo)
	tour._check(play.score == 8, "draw: score per hit is 1 + combo/5 (score=%d, expected 8)" % play.score)
	await tour._wait(0.2)
	await tour._shot("smoke_draw_combo")
	play.toggle_pause()
	await tour._wait(0.3)
	tour._check(play.paused and tour.get_tree().paused, "draw: pause toggles the tree pause")
	await tour._shot("smoke_draw_paused")
	play.toggle_pause()
	# Run the round down: expire everything until the lives are gone.
	SaveData.data.boosters.life = 0
	var lives_before: int = play.lives
	var t0 := Time.get_ticks_msec()
	while play.lives > 0 and Time.get_ticks_msec() - t0 < 10000:
		play.force_expire_all()
		await tour._wait(0.25)
	tour._check(play.lives == 0, "draw: forced misses drain the lives (%d -> %d)" % [lives_before, play.lives])
	tour._check(play.misses >= 3, "draw: misses counted (%d)" % play.misses)
	# With the mock ad provider a life offer appears; decline it.
	await tour._wait_until(func(): return _offer(tour) != null or tour._sm().current_name == "arcade_result", 3.0)
	var offer = _offer(tour)
	if offer != null:
		await tour._wait(0.3)
		await tour._shot("smoke_draw_life_offer")
		tour._check(true, "draw: life offer shown at 0 lives")
		offer.choose("no")
	await tour._wait_until(func(): return tour._sm().current_name == "arcade_result", 4.0)
	tour._check(tour._sm().current_name == "arcade_result", "draw: declining the offer ends on the results (state=%s)" % tour._sm().current_name)
	await tour._wait(1.2)
	await tour._shot("smoke_draw_result")
	# Tutorial: tap the demo target, let the decoy pass, auto-finish into play.
	await tour._go("draw_tutorial")
	await tour._wait(0.5)
	var tut = tour._sm().get_node("CurrentState").get_child(0)
	tour._check(tut.step == 0, "draw tutorial: starts on step 1")
	await tour._shot("smoke_draw_tutorial")
	var demo = tut._target
	tour._check(demo != null and not demo.is_decoy, "draw tutorial: demo target present")
	if demo != null:
		tour._click(demo.global_position)
	await tour._wait_until(func(): return tut.step == 1, 4.0)
	tour._check(tut.step == 1, "draw tutorial: tapping the target advances to step 2 (step=%d)" % tut.step)
	await tour._wait(0.4)
	await tour._shot("smoke_draw_tutorial_decoy")
	await tour._wait_until(func(): return tut.step == 2, 4.0)
	tour._check(tut.step == 2, "draw tutorial: the decoy passes and step 3 shows (step=%d)" % tut.step)
	await tour._wait_until(func(): return tour._sm().current_name == "draw_play", 4.0)
	tour._check(tour._sm().current_name == "draw_play", "draw tutorial: finishes into a round (state=%s)" % tour._sm().current_name)
	tour._check(SaveData.tutorial_done("draw"), "draw tutorial: marked done")

func _first_shuriken(play) -> Node:
	for t in play.alive_targets():
		if not t.is_decoy:
			return t
	return null

func _offer(tour) -> Node:
	for c in tour.get_tree().root.get_children():
		if c is OfferOverlay:
			return c
	return null
