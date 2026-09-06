extends Node
## Rewarded ads behind a tiny provider interface.
##
## On iOS the Poing Studios AdMob plugin (addons/admob, Google Mobile Ads SDK via
## Swift Package Manager) serves real rewarded video. Everywhere else - the
## editor, macOS, the debug tour - a local, offline "test ad" overlay with a
## countdown stands in, so every reward flow works end to end and stays
## deterministic in tests.
##
## Configuration lives in Project Settings, not in code:
##   admob/general/ios/app_id       - the AdMob APP id  (ca-app-pub-XXXX~YYYY)
##   ninja/ads/rewarded_unit_id     - the rewarded AD UNIT id (ca-app-pub-XXXX/ZZZZ)
## Both default to Google's official TEST ids, which serve real (test-labelled)
## video on device and never count as invalid traffic. Swap in the ids from the
## AdMob console for the store release.
##
## No App Tracking Transparency prompt is made: the SDK serves non-personalised
## ads without the IDFA, which keeps the app's no-tracking stance and its App
## Privacy answers simple.

signal reward_granted(placement: String)
signal ad_finished(placement: String, rewarded: bool)

enum Provider { NONE, MOCK, ADMOB }

const UNIT_SETTING := "ninja/ads/rewarded_unit_id"
const TEST_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"   # Google's iOS test unit
const RELOAD_BACKOFF := [2.0, 5.0, 15.0, 30.0, 60.0]
const MOCK_AD_SCENE := "res://UI/mock_ad.tscn"

## What each placement gives the player, for the offer dialogs.
const PLACEMENTS := {
	"hint": {"title": "NEED A HINT?", "reward": "+3 hints", "booster": "hint", "amount": 3, "blurb": "Watch a short ad and the best move lights up when you ask."},
	"moves": {"title": "OUT OF MOVES?", "reward": "+5 moves", "booster": "moves", "amount": 1, "blurb": "Watch a short ad to keep this board alive with five extra moves."},
	"shuffle": {"title": "STUCK?", "reward": "+1 shuffle", "booster": "shuffle", "amount": 1, "blurb": "Watch a short ad to reshuffle the board without spending a move."},
	"hammer": {"title": "ONE TILE IN THE WAY?", "reward": "+1 hammer", "booster": "hammer", "amount": 1, "blurb": "Watch a short ad to smash any single shuriken."},
	"skip": {"title": "SKIP THIS LEVEL", "reward": "level skip", "booster": "skip", "amount": 1, "blurb": "Watch a short ad to clear this level with one star and move on."},
	"revive": {"title": "ONE MORE CHANCE", "reward": "revive", "booster": "revive", "amount": 1, "blurb": "Watch a short ad to continue this run from where you fell."},
	"life": {"title": "EXTRA LIFE", "reward": "+1 life", "booster": "life", "amount": 1, "blurb": "Watch a short ad for one more life."},
}

var provider: int = Provider.NONE
var _busy := false
var _showing := false

## True while a full-screen ad is on top of the game. Play states use this to
## skip their auto-pause when iOS reports the focus change the ad causes.
func is_showing() -> bool:
	return _showing

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _admob_available():
		provider = Provider.ADMOB
		_admob_init()
	else:
		provider = Provider.MOCK
	print("Ads: provider=%s unit=%s test_install=%s" % [Provider.keys()[provider], unit_id(), is_test_install()])

## The rewarded ad unit id. TestFlight and development installs carry an
## embedded provisioning profile that App Store installs do not, so those builds
## keep Google's test unit: testers can watch as much as they like without the
## live unit ever seeing invalid traffic. Only a real App Store install serves
## the live unit from Project Settings.
static func unit_id() -> String:
	if is_test_install():
		return TEST_REWARDED_UNIT_ID
	var v := str(ProjectSettings.get_setting(UNIT_SETTING, ""))
	return v if v != "" else TEST_REWARDED_UNIT_ID

static func is_test_install() -> bool:
	if not OS.has_feature("ios"):
		return true
	var bundle_dir := OS.get_executable_path().get_base_dir()
	return FileAccess.file_exists(bundle_dir.path_join("embedded.mobileprovision"))

## True when a reward ad can be offered right now.
func available(placement: String = "") -> bool:
	if _busy or not PLACEMENTS.has(placement) and placement != "":
		return false
	match provider:
		Provider.MOCK: return true
		Provider.ADMOB: return _admob_ready()
		_: return false

func is_real() -> bool:
	return provider == Provider.ADMOB

func placement_info(placement: String) -> Dictionary:
	return PLACEMENTS.get(placement, {})

## Show a rewarded ad. Awaitable: returns true when the reward was earned.
## The reward's booster is added to the inventory automatically.
func show_rewarded(placement: String) -> bool:
	if _busy or not available(placement):
		return false
	_busy = true
	var rewarded := false
	match provider:
		Provider.MOCK:
			rewarded = await _mock_show(placement)
		Provider.ADMOB:
			rewarded = await _admob_show(placement)
	_busy = false
	if rewarded:
		var info: Dictionary = placement_info(placement)
		if info.has("booster"):
			SaveData.add_booster(str(info.booster), int(info.get("amount", 1)))
		AudioManager.play_sfx("ad_reward")
		reward_granted.emit(placement)
	ad_finished.emit(placement, rewarded)
	return rewarded

# ---------------------------------------------------------------- mock provider

func _mock_show(placement: String) -> bool:
	var scene: PackedScene = load(MOCK_AD_SCENE)
	if scene == null:
		return false
	var overlay := scene.instantiate()
	get_tree().root.add_child(overlay)
	var ok: bool = await overlay.run(placement_info(placement))
	overlay.queue_free()
	return ok

# ---------------------------------------------------------------- AdMob (iOS, Poing Studios plugin)

var _rewarded_ad: RewardedAd = null
var _show_closed := false
var _show_earned := false
var _loading := false
var _load_failures := 0
var _load_callback := RewardedAdLoadCallback.new()
var _content_callback := FullScreenContentCallback.new()

## Real ads only where the native singleton exists (an iOS/Android export with the
## plugin enabled). The editor and desktop builds keep the local mock so tests and
## screenshots never depend on the network.
func _admob_available() -> bool:
	return (OS.has_feature("ios") or OS.has_feature("android")) and Engine.has_singleton("PoingGodotAdMob")

func _admob_init() -> void:
	_load_callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_load_failures = 0
		ad.full_screen_content_callback = _content_callback
		_rewarded_ad = ad
	_load_callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading = false
		_rewarded_ad = null
		push_warning("Ads: rewarded load failed (%s); retrying" % error.message)
		_schedule_reload()
	# Keep the game's music going underneath the SDK's own audio handling.
	MobileAds.set_ios_app_pause_on_background(false)
	MobileAds.initialize()
	_admob_load()

func _admob_load() -> void:
	if _loading or _rewarded_ad != null:
		return
	_loading = true
	RewardedAdLoader.new().load(unit_id(), AdRequest.new(), _load_callback)

func _schedule_reload() -> void:
	var wait: float = RELOAD_BACKOFF[mini(_load_failures, RELOAD_BACKOFF.size() - 1)]
	_load_failures += 1
	get_tree().create_timer(wait, true, false, true).timeout.connect(_admob_load)

func _admob_ready() -> bool:
	return _rewarded_ad != null

## Show the loaded ad; resolve when it is dismissed. The reward callback and the
## dismiss callback are both deferred by the plugin, so wait a couple of frames
## after the close before reading the result.
func _admob_show(_placement: String) -> bool:
	if not _admob_ready():
		return false
	var ad := _rewarded_ad
	_rewarded_ad = null
	# Member flags, not locals: GDScript lambdas capture locals by value, so a
	# local `closed` flipped inside a callback would never be seen out here.
	_show_closed = false
	_show_earned = false
	_content_callback.on_ad_dismissed_full_screen_content = func() -> void: _show_closed = true
	_content_callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("Ads: failed to show (%s)" % error.message)
		_show_closed = true
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _show_earned = true
	_showing = true
	AudioManager.duck(true)
	ad.show(listener)
	var t0 := Time.get_ticks_msec()
	while not _show_closed and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	# The reward and dismiss callbacks are both deferred by the plugin; give the
	# reward two more frames to land before reading it.
	await get_tree().process_frame
	await get_tree().process_frame
	_showing = false
	AudioManager.duck(false)
	ad.destroy()
	_admob_load()
	return _show_earned
