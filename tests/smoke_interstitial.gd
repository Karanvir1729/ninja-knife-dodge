extends RefCounted
## Interstitials between rounds: the pacing rules, the stand-in ad on the way
## out of a results screen, and that the exit still lands on the next state.

func run(tour) -> void:
	Ads.interstitials_enabled = true
	Ads.debug_reset_pacing()
	tour._check(not Ads.interstitial_due(), "interstitial: none before any round")
	Ads.round_finished()
	Ads.round_finished()
	tour._check(not Ads.interstitial_due(), "interstitial: the first two rounds of a session are ad-free")
	Ads.round_finished()
	tour._check(Ads.interstitial_due(), "interstitial: due after the third round")
	await tour._go("arcade_result", {"game": "cricket", "score": 12, "time": 30.0, "detail": "12 runs", "stats": []})
	await tour._wait(1.2)
	var st = tour._sm().get_node("CurrentState").get_child(0)
	st._leave("cricket_play")
	await tour._wait_until(func(): return _mock(tour) != null, 2.0)
	var ad = _mock(tour)
	tour._check(ad != null, "interstitial: stand-in ad appears when leaving the results")
	tour._check(Ads.is_showing(), "interstitial: reported as showing (play states skip their auto-pause)")
	tour._check(tour._sm().current_name == "arcade_result", "interstitial: results stay underneath until it closes")
	await tour._wait(0.5)
	await tour._shot("smoke_interstitial")
	if ad:
		var btn: Button = ad.get_node("%Claim")
		await tour._wait_until(func(): return not btn.disabled, 5.0)
		tour._check(not btn.disabled, "interstitial: continue unlocks after the countdown")
		tour._check(ad.get_node("%Close").visible, "interstitial: close control appears once it has run")
		btn.pressed.emit()
	await tour._wait_until(func(): return tour._sm().current_name == "cricket_play", 4.0)
	tour._check(tour._sm().current_name == "cricket_play", "interstitial: continues into the next round (state=%s)" % tour._sm().current_name)
	tour._check(not Ads.is_showing(), "interstitial: no longer showing afterwards")
	tour._check(not Ads.interstitial_due(), "interstitial: pacing resets after one shows")
	Ads.round_finished()
	Ads.round_finished()
	Ads.round_finished()
	tour._check(not Ads.interstitial_due(), "interstitial: the minimum gap holds even after three more rounds")
	Ads.interstitials_enabled = false
	Ads.debug_reset_pacing()
	await tour._go("start")
	await tour._wait(0.5)

func _mock(tour) -> Node:
	for c in tour.get_tree().root.get_children():
		if c.name.begins_with("MockAd"):
			return c
	return null
