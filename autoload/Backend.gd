extends Node
## The player backend: Supabase over plain HTTPS. Players sign in with Apple
## (the native AppleSignIn plugin on iOS hands back Apple's identity token,
## Supabase Auth turns it into a session), every player owns one row in the
## `players` table, and the local save is mirrored there after each round.
##
## Order matters: a sign-in or launch first PULLS the cloud row and merges it
## into the local save (higher bests win, flags are OR-ed), and only then
## PUSHES, so a reinstall or a second device can never wipe cloud progress.
## Nothing here blocks play: the game keeps its offline save; sync is best
## effort and retried on the next launch. Desktop and simulator builds have no
## Apple plugin and use "Continue on this device" (a device-only guest).

signal signed_in
signal signed_out
signal sign_in_failed(message: String)
signal synced(ok: bool)
signal refresh_done(ok: bool)

const URL_SETTING := "ninja/backend/url"
const KEY_SETTING := "ninja/backend/publishable_key"
const REFRESH_MARGIN := 120        # refresh the access token this long before it expires (s)
const SYNC_DEBOUNCE := 2.0
const TIMEOUT := 20.0
## Apple's ASAuthorizationError.canceled.
const APPLE_CANCELED := 1001

var url := ""
var key := ""
var busy := false
var last_error := ""
var _raw_nonce := ""
var _sync_timer: SceneTreeTimer
var _plugin: Object
var _refreshing := false
var _merging := false
var _push_refused := false        # the server rejected the row (4xx): stop retrying every round

func _ready() -> void:
	url = str(ProjectSettings.get_setting(URL_SETTING, "")).rstrip("/")
	key = str(ProjectSettings.get_setting(KEY_SETTING, ""))
	if Engine.has_singleton("AppleSignIn"):
		_plugin = Engine.get_singleton("AppleSignIn")
		_plugin.connect("sign_in_completed", _on_apple_completed)
		_plugin.connect("sign_in_failed", _on_apple_failed)
		_plugin.connect("credential_state", _on_credential_state)
	if has_session():
		call_deferred("_resume")

# ---------------------------------------------------------------- state

func is_configured() -> bool:
	return not url.is_empty() and not key.is_empty()

func apple_available() -> bool:
	return _plugin != null and bool(_plugin.call("is_available"))

## A Supabase session (signed in with Apple) is stored in the save file.
func has_session() -> bool:
	var a: Dictionary = SaveData.data.get("account", {})
	return not str(a.get("refresh_token", "")).is_empty() and not str(a.get("user_id", "")).is_empty()

## The player chose to play without an account on this device.
func is_guest() -> bool:
	return bool(SaveData.data.get("account", {}).get("guest", false))

## Does the game need to show the sign-in screen first?
func needs_sign_in() -> bool:
	return is_configured() and not has_session() and not is_guest()

func user_id() -> String:
	return str(SaveData.data.get("account", {}).get("user_id", ""))

func account_label() -> String:
	var a: Dictionary = SaveData.data.get("account", {})
	if has_session():
		var email := str(a.get("email", ""))
		return email if not email.is_empty() else "APPLE ID"
	if is_guest():
		return "THIS DEVICE ONLY"
	return "NOT SIGNED IN"

func continue_as_guest() -> void:
	SaveData.data.account = {"guest": true}
	SaveData.save()

# ---------------------------------------------------------------- Sign in with Apple

## Ask Apple for an identity token, then trade it for a Supabase session.
## Emits signed_in (after the cloud merge) or sign_in_failed(message).
func sign_in_with_apple() -> void:
	if busy:
		return
	if not apple_available():
		sign_in_failed.emit("Sign in with Apple is not available on this device.")
		return
	busy = true
	last_error = ""
	_raw_nonce = Crypto.new().generate_random_bytes(32).hex_encode()
	_plugin.call("sign_in", _sha256_hex(_raw_nonce))

func _on_apple_completed(result: Dictionary) -> void:
	var token := str(result.get("identity_token", ""))
	if token.is_empty():
		busy = false
		sign_in_failed.emit("Apple returned no identity token. Please try again.")
		return
	var ok := await sign_in_with_id_token(token, _raw_nonce)
	if ok:
		var a: Dictionary = SaveData.data.account
		a["apple_user"] = str(result.get("user", ""))
		if str(a.get("email", "")).is_empty() and not str(result.get("email", "")).is_empty():
			a["email"] = str(result.get("email", ""))
		SaveData.save()
		_adopt_device(user_id())
		await merge_from_cloud()
	busy = false
	if ok:
		signed_in.emit()
	else:
		sign_in_failed.emit(_friendly(last_error))

func _on_apple_failed(code: int, message: String) -> void:
	busy = false
	if code == APPLE_CANCELED:
		sign_in_failed.emit("")
		return
	# ASAuthorizationError codes; 1000 is the simulator's usual answer.
	var why := ""
	match code:
		1000: why = "Apple could not complete sign-in. Check your connection and that an Apple ID is signed in to this device, then try again."
		1002: why = "Apple sent an invalid response. Please try again."
		1003: why = "The sign-in request was not handled. Please try again."
		1004: why = "Sign in with Apple failed. Please try again."
		1005: why = "Sign in with Apple needs you to confirm on this device."
		_: why = "Apple could not sign you in (%d). %s" % [code, message]
	sign_in_failed.emit(why)

## A different Apple ID than the one this device's progress belongs to starts
## clean: the previous player's progress stays safe in their own cloud row.
func _adopt_device(uid: String) -> void:
	var owner := str(SaveData.data.profile.get("owner_uid", ""))
	if not owner.is_empty() and owner != uid:
		SaveData.reset_all()
	SaveData.data.profile.owner_uid = uid
	SaveData.save()

## POST /auth/v1/token?grant_type=id_token with Apple's token and the raw nonce
## whose SHA-256 was sent to Apple. On success the session is saved.
func sign_in_with_id_token(id_token: String, raw_nonce: String) -> bool:
	var body := {"provider": "apple", "id_token": id_token}
	if not raw_nonce.is_empty():
		body["nonce"] = raw_nonce
	var r := await _request("POST", "/auth/v1/token?grant_type=id_token", body, false)
	if not r.ok:
		last_error = _auth_error(r)
		return false
	_store_session(r.json)
	_push_refused = false
	return true

func _store_session(s: Dictionary) -> void:
	var user: Dictionary = s.get("user", {})
	var account: Dictionary = SaveData.data.get("account", {})
	account["guest"] = false
	account["access_token"] = str(s.get("access_token", ""))
	account["refresh_token"] = str(s.get("refresh_token", ""))
	account["expires_at"] = int(Time.get_unix_time_from_system()) + int(s.get("expires_in", 3600))
	account["user_id"] = str(user.get("id", account.get("user_id", "")))
	if not str(user.get("email", "")).is_empty():
		account["email"] = str(user.get("email", ""))
	SaveData.data.account = account
	SaveData.save()

## Refresh the access token when it is about to expire. False means the
## session is gone (refused refresh token) or the network is down. A dead
## session turns the device into a guest so the player is never locked out.
func ensure_fresh() -> bool:
	if not has_session():
		return false
	var a: Dictionary = SaveData.data.account
	if int(a.get("expires_at", 0)) - REFRESH_MARGIN > int(Time.get_unix_time_from_system()):
		return true
	if _refreshing:
		var ok: bool = await refresh_done
		return ok and has_session()
	_refreshing = true
	var r := await _request("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": str(a.refresh_token)}, false)
	var ok := bool(r.ok)
	if ok:
		_store_session(r.json)
	else:
		last_error = _auth_error(r)
		if r.code in [400, 401, 403]:
			_drop_session()
	_refreshing = false
	refresh_done.emit(ok)
	return ok

## Forget the session on this device and keep playing as a guest. The account
## itself stays; Settings > Account can sign in again.
func sign_out(tell_server: bool = true) -> void:
	if tell_server and has_session():
		if await ensure_fresh():
			await _request("POST", "/auth/v1/logout?scope=global", {}, true)
	_drop_session()
	signed_out.emit()

func _drop_session() -> void:
	SaveData.data.account = {"guest": true}
	SaveData.save()

## Delete the account and everything stored for it (App Store rule 5.1.1).
func delete_account() -> bool:
	if not await ensure_fresh():
		return false
	var r := await _request("POST", "/rest/v1/rpc/delete_my_account", {}, true)
	if r.ok:
		_drop_session()
		signed_out.emit()
		return true
	last_error = _rest_error(r)
	return false

## Apple can revoke the credential (Settings > Apple ID > Sign in with Apple).
func _on_credential_state(state: String) -> void:
	if state in ["revoked", "not_found"] and has_session():
		sign_out(true)

# ---------------------------------------------------------------- the player's row

## Push the local save to the cloud soon (debounced: rounds end in bursts).
func sync_later() -> void:
	if not has_session() or _push_refused:
		return
	if _sync_timer != null and _sync_timer.time_left > 0.0:
		return
	_sync_timer = get_tree().create_timer(SYNC_DEBOUNCE)
	_sync_timer.timeout.connect(sync_now)

func sync_now() -> void:
	if not has_session() or _merging:
		return
	var ok := await push_player()
	synced.emit(ok)

## Upsert this player's row from SaveData. A 4xx means the server refused the
## row (a constraint): remember it and stop hammering until the next sign-in.
func push_player() -> bool:
	if _push_refused:
		return false
	if not await ensure_fresh():
		return false
	var r := await _request("POST", "/rest/v1/players?on_conflict=id", player_payload(), true, {"Prefer": "resolution=merge-duplicates,return=minimal"})
	if not r.ok:
		last_error = _rest_error(r)
		if r.code >= 400 and r.code < 500 and r.code != 401:
			_push_refused = true
	return r.ok

## Read this player's row ({} when there is none yet or offline).
func fetch_player() -> Dictionary:
	if not await ensure_fresh():
		return {}
	var r := await _request("GET", "/rest/v1/players?id=eq.%s&select=*" % user_id(), null, true)
	if r.ok and r.json is Array and not r.json.is_empty():
		return r.json[0]
	if not r.ok:
		last_error = _rest_error(r)
	return {}

## The public leaderboard for one score column (ninja name and score).
func fetch_leaderboard(column: String, limit: int = 20) -> Array:
	var r := await _request("GET", "/rest/v1/leaderboard?select=ninja_name,%s&order=%s.desc&limit=%d" % [column, column, limit], null, has_session())
	return r.json if r.ok and r.json is Array else []

## Pull the cloud row, keep the better of local and cloud everywhere (bests,
## levels, stars, flags, boosters), then push the result. Offline: no change.
func merge_from_cloud() -> void:
	if not has_session() or _merging:
		return
	_merging = true
	var row := await fetch_player()
	if not row.is_empty():
		_merge_row(row)
	_merging = false
	if not row.is_empty() or last_error.is_empty():
		await push_player()

func _merge_row(row: Dictionary) -> void:
	var d: Dictionary = SaveData.data
	d.knife.best = maxi(int(d.knife.best), int(row.get("best_knife", 0)))
	for id in ["draw", "simon", "cricket"]:
		var st: Dictionary = SaveData.game_stats(id)
		st.best = maxi(int(st.best), int(row.get("best_%s" % id, 0)))
	d.match.next_level = maxi(int(d.match.next_level), int(row.get("match_level", 1)))
	var cloud_name := str(row.get("ninja_name", ""))
	if SaveData.player_name() == SaveData.DEFAULT_NAME and not cloud_name.is_empty() and cloud_name != SaveData.DEFAULT_NAME:
		SaveData.set_player_name(cloud_name)
	var save = row.get("save", {})
	if save is Dictionary:
		_merge_save(save)
	SaveData.save()

## The `save` blob: OR the flags, max the counters, union the dictionaries.
func _merge_save(save: Dictionary) -> void:
	var d: Dictionary = SaveData.data
	var story: Dictionary = save.get("story", {})
	for k in ["prologue_seen", "epilogue_seen", "midpoint_seen"]:
		if bool(story.get(k, false)):
			d.story[k] = true
	for k in story.keys():
		var v = story[k]
		if v is bool and v:
			d.story[k] = true
		elif v is Dictionary:
			if not d.story.has(k) or not (d.story[k] is Dictionary):
				d.story[k] = {}
			for id in v.keys():
				if bool(v[id]):
					d.story[k][id] = true
	var tutorials: Dictionary = save.get("tutorials", {})
	for k in tutorials.keys():
		if bool(tutorials[k]):
			d.tutorials[k] = true
	var boosters: Dictionary = save.get("boosters", {})
	for k in boosters.keys():
		d.boosters[k] = maxi(int(d.boosters.get(k, 0)), int(boosters[k]))
	var knife: Dictionary = save.get("knife", {})
	for k in ["runs", "total_dodged", "best_wave"]:
		d.knife[k] = maxi(int(d.knife.get(k, 0)), int(knife.get(k, 0)))
	d.knife.time_played = maxf(float(d.knife.get("time_played", 0.0)), float(knife.get("time_played", 0.0)))
	var match_save: Dictionary = save.get("match", {})
	d.match.games = maxi(int(d.match.games), int(match_save.get("games", 0)))
	var levels: Dictionary = match_save.get("levels", {})
	for lk in levels.keys():
		var cloud_lv: Dictionary = levels[lk]
		var local_lv: Dictionary = d.match.levels.get(lk, {"stars": 0, "best": 0})
		d.match.levels[lk] = {"stars": maxi(int(local_lv.get("stars", 0)), int(cloud_lv.get("stars", 0))), "best": maxi(int(local_lv.get("best", 0)), int(cloud_lv.get("best", 0)))}
	var total := 0
	for lk in d.match.levels.keys():
		total += int(d.match.levels[lk].stars)
	d.match.total_stars = total
	var games: Dictionary = save.get("games", {})
	for id in games.keys():
		var g: Dictionary = games[id]
		var st: Dictionary = SaveData.game_stats(id)
		st.best = maxi(int(st.best), int(g.get("best", 0)))
		st.plays = maxi(int(st.plays), int(g.get("plays", 0)))
		st.total = maxi(int(st.total), int(g.get("total", 0)))
		st.time = maxf(float(st.time), float(g.get("time", 0.0)))

## The server only accepts A-Z, 0-9, space and underscore, 1 to 12 characters.
static func clean_name(n: String) -> String:
	var out := ""
	for ch in n.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "_":
			out += ch
	out = out.strip_edges().substr(0, 12)
	return out if not out.is_empty() else SaveData.DEFAULT_NAME

func player_payload() -> Dictionary:
	var d: Dictionary = SaveData.data
	var save := {
		"story": d.get("story", {}), "tutorials": d.get("tutorials", {}), "boosters": d.get("boosters", {}),
		"knife": {"best": d.knife.best, "runs": d.knife.runs, "total_dodged": d.knife.get("total_dodged", 0), "best_wave": d.knife.get("best_wave", 0), "time_played": d.knife.get("time_played", 0.0)},
		"match": {"next_level": d.match.next_level, "games": d.match.games, "total_stars": d.match.get("total_stars", 0), "levels": d.match.get("levels", {})},
		"games": {},
	}
	for id in d.get("games", {}).keys():
		var g: Dictionary = d.games[id]
		save.games[id] = {"best": g.get("best", 0), "plays": g.get("plays", 0), "total": g.get("total", 0), "time": g.get("time", 0.0)}
	return {
		"id": user_id(),
		"ninja_name": clean_name(SaveData.player_name()),
		"best_knife": int(d.knife.best),
		"best_draw": int(SaveData.game_stats("draw").best),
		"best_simon": int(SaveData.game_stats("simon").best),
		"best_cricket": int(SaveData.game_stats("cricket").best),
		"match_level": int(d.match.next_level),
		"match_stars": int(SaveData.match_total_stars()),
		"seals": Story.seals_count(),
		"save": save,
		"platform": OS.get_name(),
		"app_version": Globals.VERSION,
	}

# ---------------------------------------------------------------- plumbing

## On launch with a session: check Apple has not revoked it, pull, merge, push.
func _resume() -> void:
	if _plugin != null and not str(SaveData.data.account.get("apple_user", "")).is_empty():
		_plugin.call("check_credential", str(SaveData.data.account.apple_user))
	if await ensure_fresh():
		await merge_from_cloud()
		synced.emit(last_error.is_empty())

func _sha256_hex(text: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(text.to_utf8_buffer())
	return h.finish().hex_encode()

## Player-facing wording for a raw error (the raw text stays in last_error).
func _friendly(raw: String) -> String:
	if raw.begins_with("no connection") or raw.begins_with("request error"):
		return "Could not reach the dojo. Check your connection and try again."
	if raw.begins_with("HTTP 5"):
		return "The dojo is busy right now. Please try again in a moment."
	return "Sign-in was refused. Please try again."

## One HTTPS call. Returns {ok, code, json, text}. `authed` sends the user's
## access token (the publishable key is sent as apikey either way).
func _request(method: String, path: String, body, authed: bool, extra_headers: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "code": 0, "json": null, "text": ""}
	if not is_configured():
		out.text = "backend not configured"
		return out
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json", "Accept: application/json"])
	if authed and has_session():
		headers.append("Authorization: Bearer " + str(SaveData.data.account.access_token))
	else:
		headers.append("Authorization: Bearer " + key)
	for k in extra_headers.keys():
		headers.append("%s: %s" % [k, extra_headers[k]])
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.accept_gzip = true
	add_child(http)
	var m := HTTPClient.METHOD_GET
	match method:
		"POST": m = HTTPClient.METHOD_POST
		"PATCH": m = HTTPClient.METHOD_PATCH
		"DELETE": m = HTTPClient.METHOD_DELETE
	var data := "" if body == null else JSON.stringify(body)
	var err := http.request(url + path, headers, m, data)
	if err != OK:
		http.queue_free()
		out.text = "request error %d" % err
		return out
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	out.code = int(res[1])
	var raw: PackedByteArray = res[3]
	out.text = raw.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		out.text = "no connection (%d)" % result
		return out
	if not out.text.is_empty():
		out.json = JSON.parse_string(out.text)
	out.ok = out.code >= 200 and out.code < 300
	return out

func _auth_error(r: Dictionary) -> String:
	if r.json is Dictionary:
		for k in ["error_description", "msg", "message", "error"]:
			if r.json.has(k):
				return str(r.json[k])
	return r.text if not r.text.is_empty() else "HTTP %d" % r.code

func _rest_error(r: Dictionary) -> String:
	if r.json is Dictionary and r.json.has("message"):
		return str(r.json.message)
	return r.text if not r.text.is_empty() else "HTTP %d" % r.code
