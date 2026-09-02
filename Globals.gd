extends Node
## Shared constants, palette and viewport helpers.
## The viewport stretches with aspect "expand", so the visible area is at least
## BASE_WIDTH x BASE_HEIGHT and grows on wider (iPhone) or taller (iPad) screens.
## Always read view_rect() instead of assuming the base size.

const BASE_WIDTH := 1408
const BASE_HEIGHT := 792
# Kept for the original scripts that referenced them.
const WINDOW_WIDTH := 1408
const WINDOW_HEIGHT := 792

const VERSION := "2.0"

# Palette (matches the design canvas)
const BG0 := Color("07080d")
const BG1 := Color("0e0f16")
const BG2 := Color("161826")
const LINE := Color("262a3d")
const LINE2 := Color("343a55")
const TEXT := Color("ebeef8")
const MUTED := Color("8b92ab")
const DIM := Color("5a6180")
const CYAN := Color("56f0ff")
const MAGENTA := Color("ff4fd8")
const GOLD := Color("ffd84d")
const GREEN := Color("4dffa6")
const VIOLET := Color("9b6bff")
const ORANGE := Color("ff8a3d")
const RED := Color("ff3b5c")

## Game categories shown on the main menu.
const CATEGORIES := {
	"mind": {"title": "MIND GAMES", "blurb": "Think ahead. Plan every move.", "accent": Color("ff4fd8")},
	"skill": {"title": "SKILL GAMES", "blurb": "React fast. Trust your fingers.", "accent": Color("56f0ff")},
}

## Registry of every game in the arcade. Screens (menu, leaderboards, results,
## debug tour) are driven from this list, so adding a game is mostly additive.
##  id             save key and leaderboard tab
##  play_state     state to enter from the menu (tutorial gating is per game)
##  tutorial_state state used by "How to play"
##  stat_label     what best_for(id) means on the menu card
##  tour           extra screens for the debug tour: [{state, params, wait, name}]
##  milestones     [[threshold, TITLE], ...] against best_for(id)
const GAMES := [
	{"id": "match", "title": "SHURIKEN MATCH", "category": "mind", "tagline": "Line up three. Beat the target.",
	 "accent": Color("ff4fd8"), "play_state": "match_levels", "tutorial_state": "match_tutorial", "stat_label": "LEVEL",
	 "tour": [], "milestones": [[10, "APPRENTICE"], [30, "ADEPT"], [60, "MASTER"], [100, "GRANDMASTER"], [150, "LEGEND"]],
	 "milestone_text": "Collect %d stars to earn the %s title.", "milestone_stat": "stars"},
	{"id": "simon", "title": "SENSEI SAYS", "category": "mind", "tagline": "Watch the pattern. Play it back.",
	 "accent": Color("9b6bff"), "play_state": "simon_play", "tutorial_state": "simon_tutorial", "stat_label": "BEST ROUND",
	 "tour": [{"state": "simon_play", "params": {}, "wait": 2.2, "name": "simon_play"}],
	 "milestones": [[5, "ATTENTIVE"], [10, "FOCUSED"], [15, "SHARP MIND"], [20, "PHOTOGRAPHIC"], [30, "ENLIGHTENED"]],
	 "milestone_text": "Reach round %d to earn the %s title.", "milestone_stat": "best"},
	{"id": "knife", "title": "KNIFE DODGE", "category": "skill", "tagline": "Tap to bounce. Dodge the daggers.",
	 "accent": Color("56f0ff"), "play_state": "play", "tutorial_state": "tutorial", "stat_label": "BEST",
	 "tour": [], "milestones": [[25, "BLADE APPRENTICE"], [50, "VOID WALKER"], [100, "UNTOUCHABLE"], [150, "BLADE DANCER"], [250, "SHADOW MASTER"], [400, "LIVING LEGEND"]],
	 "milestone_text": "Dodge %d daggers in one run to earn the %s title.", "milestone_stat": "best"},
	{"id": "draw", "title": "QUICK DRAW", "category": "skill", "tagline": "Hit the targets. Skip the decoys.",
	 "accent": Color("ff8a3d"), "play_state": "draw_play", "tutorial_state": "draw_tutorial", "stat_label": "BEST",
	 "tour": [{"state": "draw_play", "params": {}, "wait": 2.0, "name": "draw_play"}],
	 "milestones": [[20, "QUICK HANDS"], [50, "SHARPSHOOTER"], [100, "DEADEYE"], [200, "LIGHTNING"], [400, "UNTOUCHABLE"]],
	 "milestone_text": "Score %d in one round to earn the %s title.", "milestone_stat": "best"},
]

static func game(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}

static func games_in(category: String) -> Array:
	var out := []
	for g in GAMES:
		if g.category == category:
			out.append(g)
	return out

## Tile colours for Shuriken Match, in index order.
const GEM_COLORS: Array[Color] = [
	Color("56f0ff"), Color("ff4fd8"), Color("ffd84d"),
	Color("4dffa6"), Color("9b6bff"), Color("ff8a3d"),
]

## Visible viewport rectangle in canvas units (already accounts for aspect expand).
func view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(0, 0, BASE_WIDTH, BASE_HEIGHT)
	return vp.get_visible_rect()

func view_size() -> Vector2:
	return view_rect().size

func view_center() -> Vector2:
	var r := view_rect()
	return r.position + r.size * 0.5

## Safe-area insets (notch, home indicator) converted to canvas units.
## Returns {left, top, right, bottom}. All zero on desktop.
func safe_insets() -> Dictionary:
	var insets := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return insets
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return insets
	var vs := view_size()
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	insets.left = float(safe.position.x) * sx
	insets.top = float(safe.position.y) * sy
	insets.right = float(win.x - (safe.position.x + safe.size.x)) * sx
	insets.bottom = float(win.y - (safe.position.y + safe.size.y)) * sy
	return insets

## Apply safe-area insets on top of base margins to a MarginContainer.
func apply_safe_margins(mc: MarginContainer, base: int = 32) -> void:
	var s := safe_insets()
	mc.add_theme_constant_override("margin_left", base + int(s.left))
	mc.add_theme_constant_override("margin_top", base + int(s.top))
	mc.add_theme_constant_override("margin_right", base + int(s.right))
	mc.add_theme_constant_override("margin_bottom", base + int(s.bottom))

## Change the active screen through the state machine.
func go(state: String, params: Dictionary = {}) -> void:
	get_tree().call_group("currentState", "change", state, params)

## Start a game from the menu: first time runs its tutorial (Shuriken Match
## gates inside its level map instead).
func start_game(id: String) -> void:
	var g := game(id)
	if g.is_empty():
		return
	if id != "match" and not SaveData.tutorial_done(id):
		go(g.tutorial_state, {})
	else:
		go(g.play_state, {})

static func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

static func pad_score(n: int, width: int = 6) -> String:
	return str(n).pad_zeros(width)
