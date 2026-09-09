extends RefCounted
## Story films: every film in Story.CHAPTERS that exists loads and can be
## skipped back to the hub; the Yard's opening film leads into the game; a new
## seal queues its film on the hub; a chapter that has just opened is revealed.

func _hub(tour):
	return tour._sm().get_node("CurrentState").get_child(0)

func _skip(tour) -> void:
	if tour._sm().current_name == "film":
		tour._sm().get_node("CurrentState").get_child(0).get_node("%Skip").pressed.emit()

func run(tour) -> void:
	# --- every film that exists opens and skips back to the hub
	var films := ["prologue"]
	for c in Story.CHAPTERS:
		for key in ["film", "seal_film", "goal_film"]:
			var f := str(c.get(key, ""))
			if not f.is_empty() and not films.has(f):
				films.append(f)
	var present := 0
	for f in films:
		if not Story.film_exists(f):
			continue
		present += 1
		await tour._go("film", {"film": f, "return": "start"})
		await tour._wait(1.2)
		tour._check(tour._sm().current_name == "film", "films: %s opens (state=%s)" % [f, tour._sm().current_name])
		await tour._shot("smoke_film_%s" % f)
		_skip(tour)
		await tour._wait_until(func(): return tour._sm().current_name == "start", 6.0)
		tour._check(tour._sm().current_name == "start", "films: SKIP on %s returns to the hub (state=%s)" % [f, tour._sm().current_name])
		tour._check(Story.film_seen(f), "films: %s is marked seen" % f)
	print("TOUR  films present: %d of %d" % [present, films.size()])
	tour._check(Story.film_exists("cricket") and Story.film_exists("cricket_fifty"), "films: the Yard's two films exist")
	# --- the Yard's opening film plays the first time the interlude is launched, then the game
	SaveData.set_story_flag(Story.film_flag("cricket"), false)
	SaveData.set_tutorial_done("cricket", false)
	tour._check(Story.chapter_unlocked("cricket"), "films: the interlude is open once the Eye is sealed")
	await tour._go("start")
	await tour._wait(1.2)
	var hub = _hub(tour)
	hub.director.skip_all()
	await tour._wait(0.3)
	hub._launch("cricket")
	await tour._wait_until(func(): return tour._sm().current_name == "film", 5.0)
	tour._check(tour._sm().current_name == "film", "films: launching the interlude plays its film (state=%s)" % tour._sm().current_name)
	await tour._wait(1.0)
	_skip(tour)
	await tour._wait_until(func(): return tour._sm().current_name == "cricket_tutorial", 8.0)
	tour._check(tour._sm().current_name == "cricket_tutorial", "films: the film leads into Star Cricket (state=%s)" % tour._sm().current_name)
	tour._check(Story.film_seen("cricket"), "films: the interlude's film is marked seen")
	# --- fifty in one innings queues the goal film on the hub
	SaveData.set_story_flag(Story.film_flag("cricket_fifty"), false)
	var keep: Dictionary = SaveData.game_stats("cricket").duplicate(true)
	SaveData.record_game_score("cricket", 64, {"detail": "TEST"}, 40.0)
	var due := Story.pending_films()
	var has_fifty := false
	for e in due:
		if str(e.get("film", "")) == "cricket_fifty":
			has_fifty = true
	tour._check(has_fifty, "films: fifty in one innings queues the goal film (%d due)" % due.size())
	var chain := Story.chain_films(due)
	tour._check(not chain.is_empty() and str(chain.get("film", "")) == str(due[0].film), "films: pending films chain from the first")
	await tour._go("start")
	await tour._wait_until(func(): return tour._sm().current_name == "film", 6.0)
	tour._check(tour._sm().current_name == "film", "films: the hub plays the due film (state=%s)" % tour._sm().current_name)
	await tour._wait(1.0)
	await tour._shot("smoke_film_due")
	_skip(tour)
	await tour._wait_until(func(): return tour._sm().current_name == "start", 8.0)
	tour._check(Story.film_seen("cricket_fifty"), "films: the goal film is marked seen after the chain")
	tour._check(Story.pending_films().is_empty(), "films: nothing is due after the chain")
	SaveData.data.games["cricket"] = keep
	# --- a chapter that has just opened is revealed on the path
	SaveData.data.story.revealed.erase("cricket")
	SaveData.data.story.revealed.erase("match")
	await tour._go("start")
	await tour._wait_until(func(): return SaveData.chapter_revealed("match"), 8.0)
	tour._check(SaveData.chapter_revealed("cricket") and SaveData.chapter_revealed("match"), "films: newly open chapters are revealed on the hub")
	await tour._wait(0.8)
	await tour._shot("smoke_film_reveal")
	hub = _hub(tour)
	hub.director.skip_all()
	await tour._go("start")
