extends Node
## The player backend: Supabase over plain HTTPS. Players sign in with Apple
## (the native AppleSignIn plugin on iOS hands back Apple's identity token,
## Supabase Auth turns it into a session), every player owns one row in the
## `players` table, and the local save is mirrored there after each round.
##
## Nothing here blocks play: the game keeps its offline save; sync is best
## effort and retried on the next launch. Desktop and simulator builds have no
## Apple plugin and use "Continue on this device" (a device-only guest).

signal signed_in
signal signed_out
signal sign_in_failed(message: String)
signal synced(ok: bool)

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

func _ready() -> void:
	url = str(ProjectSettings.get_setting(URL_SETTING, "")).rstrip("/")
	key = str(ProjectSettings.get_setting(KEY_SETTING, ""))
	if Engine.has_singleton("AppleSignIn"):
		_plugin = Engine.get_singleton("AppleSignIn")
		_plugin.connect("sign_in_completed", _on_apple_completed)
		_plugin.connect("sign_in_failed", _on_apple_failed)
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
## Emits signed_in or sign_in_failed(message).
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
		sign_in_failed.emit("Apple returned no identity token.")
		return
	var ok := await sign_in_with_id_token(token, _raw_nonce)
	if ok:
		var a: Dictionary = SaveData.data.account
		a["apple_user"] = str(result.get("user", ""))
		var given := str(result.get("given_name", ""))
		if not given.is_empty():
			a["name"] = (given + " " + str(result.get("family_name", ""))).strip_edges()
		if str(a.get("email", "")).is_empty() and not str(result.get("email", "")).is_empty():
			a["email"] = str(result.get("email", ""))
		SaveData.save()
	busy = false
	if ok:
		signed_in.emit()
		sync_now()
	else:
		sign_in_failed.emit(last_error)

func _on_apple_failed(code: int, message: String) -> void:
	busy = false
	if code == APPLE_CANCELED:
		sign_in_failed.emit("")
		return
	# ASAuthorizationError codes; 1000 is the simulator's usual answer.
	var why := "Apple could not sign you in."
	match code:
		1000: why = "Apple could not sign you in. Make sure an Apple ID is signed in to this device, then try again."
		1002: why = "Apple sent an invalid response. Please try again."
		1003: why = "The sign-in request was not handled. Please try again."
		1004: why = "Sign in with Apple failed. Please try again."
		1005: why = "Sign in with Apple needs you to confirm on this device."
		_: why = "Apple could not sign you in (%d). %s" % [code, message]
	sign_in_failed.emit(why)

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
## session is gone (revoked or expired refresh token) and was cleared.
func ensure_fresh() -> bool:
	if not has_session():
		return false
	var a: Dictionary = SaveData.data.account
	if int(a.get("expires_at", 0)) - REFRESH_MARGIN > int(Time.get_unix_time_from_system()):
		return true
	var r := await _request("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": str(a.refresh_token)}, false)
	if r.ok:
		_store_session(r.json)
		return true
	last_error = _auth_error(r)
	# A refused refresh token means the session is dead; a network error does not.
	if r.code in [400, 401, 403]:
		sign_out(false)
	return false

## Forget the session on this device (the account stays; the next launch asks again).
func sign_out(tell_server: bool = true) -> void:
	if tell_server and has_session():
		await _request("POST", "/auth/v1/logout", {}, true)
	SaveData.data.account = {}
	SaveData.save()
	signed_out.emit()

## Delete the account and everything stored for it (App Store rule 5.1.1).
func delete_account() -> bool:
	if not await ensure_fresh():
		return false
	var r := await _request("POST", "/rest/v1/rpc/delete_my_account", {}, true)
	if r.ok:
		SaveData.data.account = {}
		SaveData.save()
		signed_out.emit()
		return true
	last_error = _rest_error(r)
	return false

# ---------------------------------------------------------------- the player's row

## Push the local save to the cloud soon (debounced: rounds end in bursts).
func sync_later() -> void:
	if not has_session():
		return
	if _sync_timer != null and _sync_timer.time_left > 0.0:
		return
	_sync_timer = get_tree().create_timer(SYNC_DEBOUNCE)
	_sync_timer.timeout.connect(sync_now)

func sync_now() -> void:
	if not has_session():
		return
	var ok := await push_player()
	synced.emit(ok)

## Upsert this player's row from SaveData.
func push_player() -> bool:
	if not await ensure_fresh():
		return false
	var r := await _request("POST", "/rest/v1/players?on_conflict=id", player_payload(), true, {"Prefer": "resolution=merge-duplicates,return=minimal"})
	if not r.ok:
		last_error = _rest_error(r)
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

## The public leaderboard (best scores by ninja name), newest first.
func fetch_leaderboard(column: String, limit: int = 20) -> Array:
	var r := await _request("GET", "/rest/v1/leaderboard?select=ninja_name,%s&order=%s.desc&limit=%d" % [column, column, limit], null, has_session())
	return r.json if r.ok and r.json is Array else []

## After a fresh sign-in on a device with an older save: keep the higher of
## local and cloud bests, then push the result.
func merge_from_cloud() -> void:
	var row := await fetch_player()
	if row.is_empty():
		return
	SaveData.data.knife.best = maxi(int(SaveData.data.knife.best), int(row.get("best_knife", 0)))
	for id in ["draw", "simon", "cricket"]:
		var st: Dictionary = SaveData.game_stats(id)
		st.best = maxi(int(st.best), int(row.get("best_%s" % id, 0)))
	SaveData.data.match.next_level = maxi(int(SaveData.data.match.next_level), int(row.get("match_level", 1)))
	var cloud_name := str(row.get("ninja_name", ""))
	if SaveData.player_name() == SaveData.DEFAULT_NAME and not cloud_name.is_empty() and cloud_name != SaveData.DEFAULT_NAME:
		SaveData.set_player_name(cloud_name)
	SaveData.save()

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
		"ninja_name": SaveData.player_name(),
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

func _resume() -> void:
	if await ensure_fresh():
		sync_now()

func _sha256_hex(text: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(text.to_utf8_buffer())
	return h.finish().hex_encode()

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
