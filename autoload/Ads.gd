extends Node
## Rewarded ads behind a tiny provider interface.
##
## The game ships with a MOCK provider: a local, offline "test ad" overlay with a
## countdown, so every reward flow (hints, boosters, level skips, revives) works
## end to end without any SDK. To serve real ads:
##
##  1. Install an AdMob plugin for Godot 4 on iOS (for example the Poing Studios
##     "godot-admob-plugin" and its iOS export template) and add your app id to
##     the export preset's plist as GADApplicationIdentifier.
##  2. Fill in ADMOB_REWARDED_UNIT_ID below with your rewarded ad unit id.
##  3. Add NSUserTrackingUsageDescription to the plist and request tracking
##     permission (ATT) before loading ads, or use non-personalised ads.
##  4. Update the privacy policy and App Store privacy labels: ad SDKs collect
##     device identifiers and usage data.
##
## `_admob_available()` detects the plugin's classes at runtime; when they are
## missing the mock provider is used, so a build without the plugin still works.

signal reward_granted(placement: String)
signal ad_finished(placement: String, rewarded: bool)

enum Provider { NONE, MOCK, ADMOB }

const ADMOB_REWARDED_UNIT_ID := ""   # e.g. "ca-app-pub-XXXX/YYYY"; empty keeps the mock
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _admob_available():
		provider = Provider.ADMOB
		_admob_init()
	else:
		provider = Provider.MOCK

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

# ---------------------------------------------------------------- AdMob (optional plugin)

var _admob_rewarded: Object = null
var _admob_loaded := false

func _admob_available() -> bool:
	return ADMOB_REWARDED_UNIT_ID != "" and ClassDB.class_exists("RewardedAdLoader") and ClassDB.class_exists("MobileAds")

func _admob_init() -> void:
	# Written against the Poing Studios plugin API (v3/v4). Everything is duck-typed
	# so a missing method degrades to "no ad available" instead of crashing.
	var ads = ClassDB.instantiate("MobileAds")
	if ads and ads.has_method("initialize"):
		ads.initialize()
	_admob_load()

func _admob_load() -> void:
	_admob_loaded = false
	if not ClassDB.class_exists("RewardedAdLoader") or not ClassDB.class_exists("AdRequest"):
		return
	var loader = ClassDB.instantiate("RewardedAdLoader")
	var request = ClassDB.instantiate("AdRequest")
	if loader == null or request == null:
		return
	if loader.has_signal("rewarded_ad_loaded"):
		loader.rewarded_ad_loaded.connect(func(ad): _admob_rewarded = ad; _admob_loaded = true)
	if loader.has_signal("rewarded_ad_failed_to_load"):
		loader.rewarded_ad_failed_to_load.connect(func(_err): _admob_loaded = false)
	if loader.has_method("load"):
		loader.load(ADMOB_REWARDED_UNIT_ID, request)

func _admob_ready() -> bool:
	return _admob_loaded and _admob_rewarded != null

func _admob_show(_placement: String) -> bool:
	if not _admob_ready():
		return false
	var ad = _admob_rewarded
	var earned := false
	var closed := false
	if ad.has_signal("user_earned_reward"):
		ad.user_earned_reward.connect(func(_reward): earned = true)
	if ad.has_signal("dismissed_full_screen_content"):
		ad.dismissed_full_screen_content.connect(func(): closed = true)
	if ad.has_method("show"):
		ad.show()
	else:
		return false
	var t0 := Time.get_ticks_msec()
	while not closed and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	_admob_rewarded = null
	_admob_load()
	return earned
