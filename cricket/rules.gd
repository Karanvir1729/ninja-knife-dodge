class_name CricketRules
extends RefCounted
## Star Cricket rules, kept free of nodes so they read (and test) as a table:
## timing grades, the tap-to-zone mapping and the deterministic outcome table.

const ZONE_NAMES := ["FAR LEFT", "LEFT", "STRAIGHT", "RIGHT", "FAR RIGHT"]
const ZONE_COUNT := 5
const FIELDERS_PER_BALL := 3

## Timing windows in seconds of |tap - arrival|.
const PERFECT := 0.06
const GOOD := 0.13
const OK := 0.22
## An untouched ball stays hittable this long after it reaches the crease.
const PASS_GRACE := 0.23
## A swing before the ball is this far down the pitch is always a miss.
const EARLY_FRACTION := 1.0 / 3.0

## Timing grade for an error of `err` seconds. `scale` widens every window
## (the tutorial uses 2.0).
static func grade(err: float, scale: float = 1.0) -> String:
	if err <= PERFECT * scale:
		return "perfect"
	if err <= GOOD * scale:
		return "good"
	if err <= OK * scale:
		return "ok"
	return "miss"

## Zone picked by a tap `dx` units right of the view centre.
static func zone_for_x(dx: float, halfwidth: float) -> int:
	var f := dx / maxf(1.0, halfwidth)
	if f < -0.3:
		return 0
	if f < -0.1:
		return 1
	if f <= 0.1:
		return 2
	if f <= 0.3:
		return 3
	return 4

## A fraction of the half-width that maps back onto `zone` (see zone_for_x).
static func zone_fraction(zone: int) -> float:
	var f := [-0.5, -0.2, 0.0, 0.2, 0.5]
	return f[clampi(zone, 0, ZONE_COUNT - 1)]

## The outcome of a swing graded `g` toward a zone that is a gap or not, with
## the ball's line on the stumps or not. No randomness: the table decides.
##   kind: six | four | two | fielded | caught | bowled | dot
static func outcome(g: String, gap: bool, on_stumps: bool) -> Dictionary:
	match g:
		"perfect":
			return _o("six", 6, false, "SIX!", true)
		"good":
			if gap:
				return _o("four", 4, false, "FOUR!", true)
			return _o("fielded", 2, false, "FIELDED", true)
		"ok":
			if gap:
				return _o("two", 2, false, "TWO RUNS", true)
			return _o("caught", 0, true, "CAUGHT!", true)
		_:
			if on_stumps:
				return _o("bowled", 0, true, "BOWLED!", false)
			return _o("dot", 0, false, "DOT", false)

static func _o(kind: String, runs: int, wicket: bool, label: String, contact: bool) -> Dictionary:
	return {"kind": kind, "runs": runs, "wicket": wicket, "label": label, "contact": contact}

## Banner colour for an outcome kind.
static func color_for(kind: String) -> Color:
	match kind:
		"six": return Globals.GOLD
		"four": return Globals.CYAN
		"two": return Globals.GREEN
		"fielded": return Globals.MUTED
		"caught", "bowled": return Globals.RED
		_: return Globals.DIM

## Three fielder zones, drawn without replacement.
static func random_fielders(rng: RandomNumberGenerator = null) -> Array:
	var zones := [0, 1, 2, 3, 4]
	if rng != null:
		for i in range(zones.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = zones[i]
			zones[i] = zones[j]
			zones[j] = tmp
	else:
		zones.shuffle()
	var out := zones.slice(0, FIELDERS_PER_BALL)
	out.sort()
	return out

## Travel time of ball number `n` (0-based): 1.35 s on the first ball easing
## down to 0.75 s by ball 40, never faster.
static func travel_time(n: int) -> float:
	var p := clampf(float(n) / 39.0, 0.0, 1.0)
	var eased := 1.0 - (1.0 - p) * (1.0 - p)
	return lerpf(1.35, 0.75, eased)

## Result-screen title for a score.
static func title_for(runs: int) -> String:
	if runs >= 200:
		return "IMMORTAL"
	if runs >= 100:
		return "CENTURY"
	if runs >= 50:
		return "HALF CENTURY"
	if runs >= 25:
		return "GOOD KNOCK"
	return "EARLY WICKETS"
