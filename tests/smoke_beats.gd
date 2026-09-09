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
	var id := "draw"
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
	await tour._wait_until(func(): return tour._sm().current_name in ["draw_play", "draw_tutorial"], 8.0)
	tour._check(tour._sm().current_name in ["draw_play", "draw_tutorial"], "beats: the opening leads into the trial (state=%s)" % tour._sm().current_name)
	if not film.is_empty():
		tour._check(Story.film_seen(film), "beats: skipping the film still marks it seen")
	# --- second launch goes straight in
	await tour._go("start")
	await tour._wait(1.0)
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch(id)
	await tour._wait_until(func(): return tour._sm().current_name in ["draw_play", "draw_tutorial"], 5.0)
	tour._check(tour._sm().current_name in ["draw_play", "draw_tutorial"], "beats: a second launch skips the opening (state=%s)" % tour._sm().current_name)
	# --- a locked chapter stays shut: with no seals, Chapter II asks Pip instead.
	# The tour seeds every chapter as revealed, and a revealed chapter never closes
	# again (the 2.3 reorder rule), so the gating checks clear that flag first.
	var keep_revealed: Dictionary = SaveData.data.story.revealed.duplicate(true)
	SaveData.data.story.revealed = {}
	var keep_draw: int = int(SaveData.game_stats("draw").best)
	var keep_lock_level: int = SaveData.data.match.next_level
	SaveData.game_stats("draw").best = 0
	SaveData.data.match.next_level = 1        # the chapter under test must not be sealed itself
	tour._check(not Story.chapter_unlocked("match"), "beats: Chapter II is locked without the Seal of the True Light")
	tour._check(Story.unlock_seal("match") == "draw", "beats: Chapter II waits on the Eye's seal")
	tour._check(Story.current_chapter() == "draw", "beats: the current chapter is the Eye (%s)" % Story.current_chapter())
	# The 2.3 reorder moved the Blade to the end; it must not take chapters away.
	tour._check(Story.seal_earned("knife") and Story.chapter_unlocked("knife"), "beats: a sealed trial stays open however late it sits in the path")
	tour._check(not Story.chapter_unlocked("cricket"), "beats: an unseen chapter still waits on the trial before it")
	SaveData.data.story.revealed = {"cricket": true}
	tour._check(Story.chapter_unlocked("cricket"), "beats: a chapter the hub already showed as open never closes")
	SaveData.data.story.revealed = {}
	await tour._go("start")
	await tour._wait(1.2)
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch("match")
	await tour._wait(0.6)
	# If the lock ever fails the hub navigates away and frees itself, so check first.
	var blocked: bool = tour._sm().current_name == "start" and is_instance_valid(hub) and hub.director.running
	tour._check(blocked, "beats: launching a locked chapter stays on the hub with a line from Pip")
	if blocked:
		await tour._shot("smoke_beats_locked")
		hub.director.skip_all()
	SaveData.game_stats("draw").best = keep_draw
	SaveData.data.match.next_level = keep_lock_level
	SaveData.data.story.revealed = keep_revealed
	# --- the midpoint turn fires once, at exactly MIDPOINT_AT seals, and only
	# once the trials before it in the path are sealed. Drop the Mind and the Name
	# so the sample profile sits on two seals (the Eye and the Blade).
	var keep_level: int = SaveData.data.match.next_level
	var keep_simon: int = int(SaveData.game_stats("simon").best)
	SaveData.data.match.next_level = 1
	SaveData.game_stats("simon").best = 0
	SaveData.set_story_flag("midpoint_seen", false)
	var seals := Story.seals_count()
	tour._check(seals == Story.MIDPOINT_AT, "beats: profile trimmed to exactly %d seals (got %d)" % [Story.MIDPOINT_AT, seals])
	tour._check(not Story.midpoint_due(), "beats: two seals earned out of path order do not fire the turn early")
	# With the Mind sealed instead of the Blade, the turn sits in its own place.
	var keep_knife: int = int(SaveData.data.knife.best)
	SaveData.data.knife.best = 0
	SaveData.data.match.next_level = Story.seal_target("match") + 1
	tour._check(Story.seals_count() == Story.MIDPOINT_AT, "beats: the Eye and the Mind are the two seals before the turn")
	tour._check(Story.midpoint_due(), "beats: the turn is due at %d seals" % Story.MIDPOINT_AT)
	var rev_hold: Dictionary = SaveData.data.story.revealed.duplicate(true)
	SaveData.data.story.revealed = {}
	tour._check(Story.chapter_unlocked("simon") and not Story.chapter_unlocked("knife"), "beats: the Eye and the Mind open Chapter III but not the Blade")
	SaveData.data.story.revealed = rev_hold
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
	SaveData.data.knife.best = keep_knife
	SaveData.set_story_flag("midpoint_seen", false)
	tour._check(Story.all_sealed() and not Story.midpoint_due(), "beats: the turn is suppressed once every seal is earned")
	SaveData.set_story_flag("midpoint_seen", true)
	await tour._go("start")
