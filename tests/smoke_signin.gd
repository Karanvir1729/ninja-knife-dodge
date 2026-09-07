extends RefCounted
## Sign-in and backend plumbing without a network: the sign-in screen shows,
## a guest can continue on this device, the payload mirrors the save, and the
## first-launch gate picks the sign-in screen only when it should.

func run(tour) -> void:
	tour._check(Backend.is_configured(), "backend: project settings carry the Supabase url and publishable key")
	tour._check(not Backend.apple_available(), "backend: no Apple plugin on this platform (tour runs on desktop)")
	var keep: Dictionary = SaveData.data.get("account", {}).duplicate(true)
	SaveData.data.account = {}
	tour._check(Backend.needs_sign_in(), "backend: a fresh save needs the sign-in screen")
	tour._check(not Backend.has_session() and not Backend.is_guest(), "backend: no session, not a guest")
	await tour._go("signin")
	await tour._wait(1.4)
	var st = tour._sm().get_node("CurrentState").get_child(0)
	tour._check(not st.get_node("%AppleBtn").visible and st.get_node("%GuestBtn").visible, "signin: without the plugin the screen offers to continue on this device")
	await tour._shot("smoke_signin")
	st.get_node("%GuestBtn").pressed.emit()
	await tour._wait_until(func(): return tour._sm().current_name in ["start", "cinematic"], 6.0)
	tour._check(tour._sm().current_name in ["start", "cinematic"], "signin: continuing on this device enters the game (state=%s)" % tour._sm().current_name)
	tour._check(Backend.is_guest() and not Backend.needs_sign_in(), "backend: the guest choice is remembered")
	# A stored session counts as signed in; its payload mirrors the save.
	SaveData.data.account = {"guest": false, "access_token": "t", "refresh_token": "r", "user_id": "00000000-0000-0000-0000-000000000001", "email": "ninja@example.com", "expires_at": int(Time.get_unix_time_from_system()) + 3600}
	tour._check(Backend.has_session() and not Backend.needs_sign_in(), "backend: a stored session skips the sign-in screen")
	tour._check(Backend.account_label() == "ninja@example.com", "backend: the account label is the email")
	var payload := Backend.player_payload()
	for k in ["id", "ninja_name", "best_knife", "best_draw", "best_simon", "best_cricket", "match_level", "match_stars", "seals", "save", "platform", "app_version"]:
		tour._check(payload.has(k), "backend: payload has %s" % k)
	tour._check(int(payload.best_knife) == int(SaveData.knife_stats().best) and str(payload.ninja_name) == SaveData.player_name(), "backend: payload mirrors the local bests and name")
	tour._check(payload.save.has("story") and payload.save.has("games"), "backend: the save blob carries story and game stats")
	var hashed: String = Backend._sha256_hex("abc")
	tour._check(hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "backend: the nonce hash is SHA-256 hex")
	# Settings shows the account panel with sign-out and delete when signed in.
	await tour._go("settings")
	await tour._wait(0.6)
	var settings = tour._sm().get_node("CurrentState").get_child(0)
	tour._check(settings._sign_out_btn.text == "SIGN OUT" and settings._delete_btn.visible, "settings: a signed-in player can sign out or delete the account")
	await tour._shot("smoke_signin_settings")
	settings._on_delete_account()
	await tour._wait(0.3)
	tour._check(settings.get_node("%Confirm").visible and settings.get_node("%ConfirmReset").text == "DELETE", "settings: deleting asks for confirmation")
	settings.get_node("%ConfirmCancel").pressed.emit()
	await tour._wait(0.3)
	tour._check(settings.get_node("%ConfirmReset").text == "RESET", "settings: cancelling restores the reset confirm")
	SaveData.data.account = keep
	await tour._go("start")
