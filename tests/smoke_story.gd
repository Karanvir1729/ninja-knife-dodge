extends RefCounted
## Films the prologue (a screenshot every 1.6 s without advancing), checks it
## returns to the hub and marks itself seen, then checks seal logic.

func run(tour) -> void:
	SaveData.set_story_flag("prologue_seen", false)
	await tour._go("cinematic", {"return": "start"})
	var n := 0
	var t0 := Time.get_ticks_msec()
	while tour._sm().current_name == "cinematic" and Time.get_ticks_msec() - t0 < 70000:
		await tour._wait(1.6)
		if tour._sm().current_name == "cinematic":
			await tour._shot("story_prologue_%02d" % n)
			n += 1
	tour._check(tour._sm().current_name == "start", "story: prologue plays through and returns to the hub (state=%s, %d frames)" % [tour._sm().current_name, n])
	tour._check(SaveData.story_flag("prologue_seen"), "story: prologue marked as seen")
	tour._check(n >= 20, "story: prologue runs at least 32 s unattended (%d frames)" % n)
	# Skip path
	await tour._go("cinematic", {"return": "start"})
	await tour._wait(1.0)
	var cin = tour._sm().get_node("CurrentState").get_child(0)
	cin.get_node("%Skip").pressed.emit()
	await tour._wait_until(func(): return tour._sm().current_name == "start", 6.0)
	tour._check(tour._sm().current_name == "start", "story: SKIP leaves the prologue promptly")
	# Seals derive from stats
	tour._check(Story.seal_earned("knife") == (int(SaveData.knife_stats().best) >= 25), "story: blade seal follows the Knife Dodge best")
	tour._check(Story.seals_count() >= 0 and Story.ORDER.size() == 4, "story: four trials registered")
	var before := Story.seals_count()
	SaveData.record_game_score("simon", 5, {"detail": "0:30"}, 30.0)
	tour._check(Story.seal_earned("simon"), "story: memory seal earned at round 5")
	tour._check(Story.pending_celebrations().has("simon") or SaveData.seal_celebrated("simon"), "story: new seal is pending celebration")
	tour._check(Story.seals_count() >= before, "story: seal count never decreases")
