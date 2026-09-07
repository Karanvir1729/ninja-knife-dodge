extends RefCounted
## The story beats on the hub: a chapter opens with its film (or, while a film
## is missing, with the guides' lines) the first time it is launched, a second
## launch goes straight in, locked chapters stay shut, and the midpoint turn
## fires once at exactly MIDPOINT_AT seals (as a film when one exists).

func _hub(tour):
	return tour._sm().get_node("CurrentState").get_child(0)

func run(tour) -> void:
	# --- a chapter opening plays once, then launches the trial
	SaveData.data.story.opened = {}
	SaveData.set_story_flag("midpoint_seen", true)   # keep the turn out of this half
	var id := "knife"
	var film := Story.opening_film(id)
	if not film.is_empty():
		SaveData.set_story_flag(Story.film_flag(film), false)
	await tour._go("start")
	await tour._wait(1.2)
	var hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.4)
	hub._launch(id)
	if film.is_empty():
		await tour._wait_until(func(): return hub.director.running, 3.0)
		tour._check(hub.director.running, "beats: launching %s without a film plays its opening lines" % id)
		await tour._shot("smoke_beats_opening")
		hub.director.skip_all()
	else:
		await tour._wait_until(func(): return tour._sm().current_name == "film", 5.0)
		tour._check(tour._sm().current_name == "film", "beats: launching %s plays its opening film (state=%s)" % [id, tour._sm().current_name])
		await tour._wait(1.5)
		await tour._shot("smoke_beats_opening")
		if tour._sm().current_name == "film":
			tour._sm().get_node("CurrentState").get_child(0).get_node("%Skip").pressed.emit()
	tour._check(SaveData.trial_opened(id), "beats: the opening is marked seen so it plays only once")
	await tour._wait_until(func(): return tour._sm().current_name in ["play", "tutorial"], 8.0)
	tour._check(tour._sm().current_name in ["play", "tutorial"], "beats: the opening leads into the trial (state=%s)" % tour._sm().current_name)
	if not film.is_empty():
		tour._check(Story.film_seen(film), "beats: skipping the film still marks it seen")
	# --- second launch goes straight in
	await tour._go("start")
	await tour._wait(1.0)
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch(id)
	await tour._wait_until(func(): return tour._sm().current_name in ["play", "tutorial"], 5.0)
	tour._check(tour._sm().current_name in ["play", "tutorial"], "beats: a second launch skips the opening (state=%s)" % tour._sm().current_name)
	# --- a locked chapter stays shut: with no seals, Chapter II asks Pip instead.
	var keep_knife: int = int(SaveData.data.knife.best)
	SaveData.data.knife.best = 0
	tour._check(not Story.chapter_unlocked("draw"), "beats: Chapter II is locked without the Seal of Empty Air")
	tour._check(Story.unlock_seal("draw") == "knife", "beats: Chapter II waits on the Blade's seal")
	tour._check(Story.current_chapter() == "knife", "beats: the current chapter is the Blade (%s)" % Story.current_chapter())
	await tour._go("start")
	await tour._wait(1.2)
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch("draw")
	await tour._wait(0.6)
	tour._check(tour._sm().current_name == "start" and hub.director.running, "beats: launching a locked chapter stays on the hub with a line from Pip")
	await tour._shot("smoke_beats_locked")
	hub.director.skip_all()
	SaveData.data.knife.best = keep_knife
	# --- the midpoint turn fires once, at exactly MIDPOINT_AT seals.
	# Drop the last two trials below their seal so the sample profile sits on two.
	var keep_level: int = SaveData.data.match.next_level
	var keep_simon: int = int(SaveData.game_stats("simon").best)
	SaveData.data.match.next_level = 1
	SaveData.game_stats("simon").best = 0
	SaveData.set_story_flag("midpoint_seen", false)
	var seals := Story.seals_count()
	tour._check(seals == Story.MIDPOINT_AT, "beats: profile trimmed to exactly %d seals (got %d)" % [Story.MIDPOINT_AT, seals])
	tour._check(Story.midpoint_due(), "beats: the turn is due at %d seals" % Story.MIDPOINT_AT)
	tour._check(not Story.chapter_unlocked("simon") and Story.chapter_unlocked("match"), "beats: two seals open Chapter III but not IV")
	await tour._go("start")
	if Story.film_exists("midpoint"):
		await tour._wait_until(func(): return tour._sm().current_name == "film", 6.0)
		tour._check(tour._sm().current_name == "film", "beats: the turn plays as a film from the hub (state=%s)" % tour._sm().current_name)
		await tour._wait(2.0)
		await tour._shot("smoke_beats_midpoint")
		if tour._sm().current_name == "film":
			tour._sm().get_node("CurrentState").get_child(0).get_node("%Skip").pressed.emit()
		await tour._wait_until(func(): return SaveData.story_flag("midpoint_seen"), 8.0)
	else:
		await tour._wait_until(func(): return SaveData.story_flag("midpoint_seen"), 8.0)
		await tour._wait(2.6)
		await tour._shot("smoke_beats_midpoint")
	tour._check(SaveData.story_flag("midpoint_seen"), "beats: the midpoint turn plays on the hub")
	tour._check(not Story.midpoint_due(), "beats: the turn does not repeat")
	# All four seals: the turn must never collide with the ending.
	SaveData.data.match.next_level = keep_level
	SaveData.game_stats("simon").best = keep_simon
	SaveData.set_story_flag("midpoint_seen", false)
	tour._check(Story.all_sealed() and not Story.midpoint_due(), "beats: the turn is suppressed once every seal is earned")
	SaveData.set_story_flag("midpoint_seen", true)
	await tour._go("start")
