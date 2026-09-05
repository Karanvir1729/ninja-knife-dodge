extends RefCounted
## The story beats on the hub: a chapter opening the first time a trial is
## launched, and the midpoint turn once enough seals are earned.

func _hub(tour):
	return tour._sm().get_node("CurrentState").get_child(0)

func run(tour) -> void:
	# --- chapter opening plays once, then launches the trial
	SaveData.data.story.opened = {}
	SaveData.set_story_flag("midpoint_seen", true)   # keep the turn out of this half
	await tour._go("start")
	await tour._wait(1.2)
	var hub = _hub(tour)
	var with_opening := []
	for id in Story.ORDER:
		if Story.has_opening(str(id)):
			with_opening.append(str(id))
	tour._check(with_opening.size() == Story.ORDER.size(), "beats: every trial has a chapter opening (%d/%d)" % [with_opening.size(), Story.ORDER.size()])
	if with_opening.is_empty():
		return
	var id: String = with_opening[0]
	hub.director.skip_all()
	await tour._wait(0.4)
	hub._launch(id)
	await tour._wait_until(func(): return hub.director.running, 3.0)
	tour._check(hub.director.running, "beats: launching %s plays its chapter opening" % id)
	tour._check(SaveData.trial_opened(id), "beats: the opening is marked seen so it plays only once")
	await tour._shot("smoke_beats_opening")
	hub.director.skip_all()
	await tour._wait_until(func(): return tour._sm().current_name != "start", 6.0)
	tour._check(tour._sm().current_name != "start", "beats: skipping the opening starts the trial (state=%s)" % tour._sm().current_name)
	# --- second launch goes straight in
	await tour._go("start")
	await tour._wait(1.0)
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch(id)
	await tour._wait_until(func(): return tour._sm().current_name != "start", 5.0)
	tour._check(tour._sm().current_name != "start", "beats: a second launch skips the opening (state=%s)" % tour._sm().current_name)
	# --- the midpoint turn fires once, at MIDPOINT_AT seals
	SaveData.set_story_flag("midpoint_seen", false)
	var seals := Story.seals_count()
	tour._check(seals >= Story.MIDPOINT_AT, "beats: sample data has enough seals for the turn (%d)" % seals)
	tour._check(Story.midpoint_due() == (seals >= Story.MIDPOINT_AT and seals < Story.ORDER.size()), "beats: the turn is due only between %d seals and the ending" % Story.MIDPOINT_AT)
	if Story.midpoint_due():
		await tour._go("start")
		await tour._wait_until(func(): return SaveData.story_flag("midpoint_seen"), 6.0)
		tour._check(SaveData.story_flag("midpoint_seen"), "beats: the midpoint turn plays on the hub")
		await tour._shot("smoke_beats_midpoint")
		tour._check(not Story.midpoint_due(), "beats: the turn does not repeat")
	await tour._go("start")
