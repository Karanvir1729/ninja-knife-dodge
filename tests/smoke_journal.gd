extends RefCounted
## Story journal smoke checks for the debug tour (autoload/DebugTour.gd):
## one chapter card per trial, the seal count follows Story.seals_count()
## after a seal-earning score, and WATCH THE PROLOGUE round-trips through the
## cinematic (skipped) back to the journal. Also captures the journal at the
## iPhone and iPad ratios unless the tour runs with --quick.

## Entrance stagger plus Sensei's pop-in and his typed line, so shots are settled.
const SETTLE := 2.8

func run(tour) -> void:
	# A fresh journal (in memory): no seals, locked epilogue, Sensei's opening line.
	var keep := {"knife": int(SaveData.data.knife.best), "match": int(SaveData.data.match.next_level),
		"simon": int(SaveData.game_stats("simon").best), "draw": int(SaveData.game_stats("draw").best)}
	SaveData.data.knife.best = 0
	SaveData.data.match.next_level = 1
	SaveData.game_stats("simon").best = 0
	SaveData.game_stats("draw").best = 0
	tour._check(Story.seals_count() == 0, "journal: cleared stats leave no seals")
	await tour._go("story")
	await tour._wait(SETTLE)
	var fresh = _state(tour)
	tour._check(fresh.seals_shown() == 0, "journal: a fresh journal shows 0 seals (%d)" % fresh.seals_shown())
	tour._check(fresh.get_node("%NextLine").text.begins_with("NEXT: TRIAL OF THE BLADE"), "journal: the wheel points at the Trial of the Blade first")
	await tour._shot("smoke_journal_fresh")
	fresh.get_node("%Scroll").scroll_vertical = 100000
	await tour._frames(2)
	await tour._shot("smoke_journal_fresh_locked")
	SaveData.data.knife.best = keep.knife
	SaveData.data.match.next_level = keep.match
	SaveData.game_stats("simon").best = keep.simon
	SaveData.game_stats("draw").best = keep.draw
	# Drop Quick Draw below its seal so the next journal shows one open trial.
	var draw: Dictionary = SaveData.game_stats("draw")
	draw.best = mini(int(draw.best), Story.seal_target("draw") - 1)
	await tour._go("story")
	await tour._wait(SETTLE)
	var st = _state(tour)
	tour._check(st.chapter_count() == 4, "journal: one chapter card per trial (%d)" % st.chapter_count())
	tour._check(st.seals_shown() == Story.seals_count(), "journal: seal count matches Story (%d)" % st.seals_shown())
	tour._check(not Story.seal_earned("draw"), "journal: the Seal of the Eye is still open before the test score")
	await tour._shot("smoke_journal")
	# A seal-earning round: re-entering the journal shows the new seal.
	var seals_before: int = Story.seals_count()
	SaveData.record_game_score("draw", 25, {"detail": "TEST"}, 10.0)
	tour._check(Story.seals_count() == seals_before + 1, "journal: scoring 25 in Quick Draw earns the Seal of the Eye (%d -> %d)" % [seals_before, Story.seals_count()])
	await tour._go("story")
	await tour._wait(SETTLE)
	st = _state(tour)
	tour._check(st.seals_shown() == Story.seals_count(), "journal: re-entering shows the new seal count (%d)" % st.seals_shown())
	tour._check(st.chapter_count() == 4, "journal: still four chapter cards after the new seal")
	if Story.all_sealed():
		tour._check(st.get_node("%NextLine").text == "ALL SEALS EARNED", "journal: wheel caption reads ALL SEALS EARNED")
	await tour._shot("smoke_journal_sealed")
	# Scroll to the end of the journal for the (unlocked) epilogue card.
	st.get_node("%Scroll").scroll_vertical = 100000
	await tour._frames(2)
	await tour._shot("smoke_journal_epilogue")
	# WATCH THE PROLOGUE: into the cinematic, SKIP, back to the journal.
	st.get_node("%PrologueBtn").pressed.emit()
	await tour._wait_until(func(): return tour._sm().current_name == "cinematic", 6.0)
	tour._check(tour._sm().current_name == "cinematic", "journal: WATCH THE PROLOGUE opens the cinematic (state=%s)" % tour._sm().current_name)
	if tour._sm().current_name == "cinematic":
		await tour._wait(0.5)
		tour._sm().get_node("CurrentState").get_child(0).get_node("%Skip").pressed.emit()
		await tour._wait_until(func(): return tour._sm().current_name == "story", 6.0)
	tour._check(tour._sm().current_name == "story", "journal: skipping the prologue returns to the journal (state=%s)" % tour._sm().current_name)
	await tour._wait(SETTLE)
	await tour._shot("smoke_journal_after_prologue")
	# The journal at the iPhone and iPad ratios (the tour's own passes do not visit it).
	if not tour.quick:
		for preset in [["iphone", 1712, 792], ["ipad", 1408, 1056]]:
			DisplayServer.window_set_size(Vector2i(int(preset[1] * tour._scale), int(preset[2] * tour._scale)))
			await tour._frames(4)
			await tour._go("story")
			await tour._wait(SETTLE)
			await tour._shot("%s_99_journal" % preset[0])
		DisplayServer.window_set_size(Vector2i(int(1408 * tour._scale), int(792 * tour._scale)))
		await tour._frames(4)
	await tour._go("start")

func _state(tour) -> Node:
	return tour._sm().get_node("CurrentState").get_child(0)
