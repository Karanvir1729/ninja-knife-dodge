class_name Story
extends RefCounted
## The Four Trials: the storyline that ties the four games together.
## Each game is a trial with a numeral, a glyph, a seal condition and story text
## revealed when the seal is earned. Progress is derived from existing stats.

const ORDER := ["knife", "draw", "match", "simon"]

const TRIALS := {
	"knife": {"numeral": "I", "trial": "TRIAL OF THE BLADE", "glyph": "blade", "hook": "Outlast the daggers of light.",
		"seal_rule": "Dodge 25 daggers in one run", "seal_target": 25,
		"lore": "The blade trial is not about striking. It is about the space a blade cannot reach. Kuro's first lesson: move before you are moved.",
		"seal_text": "The daggers found only empty air. The Seal of the Blade is yours."},
	"draw": {"numeral": "II", "trial": "TRIAL OF THE EYE", "glyph": "eye", "hook": "Strike the targets. Spare the decoys.",
		"seal_rule": "Score 20 in one round", "seal_target": 20,
		"lore": "In the void, light lies. The eye trial teaches you to see the true target before the ring closes, and to leave the red daggers be.",
		"seal_text": "Your eye is quicker than the void's tricks. The Seal of the Eye is yours."},
	"match": {"numeral": "III", "trial": "TRIAL OF THE MIND", "glyph": "mind", "hook": "Align the shurikens. Beat the target.",
		"seal_rule": "Clear level 3", "seal_target": 3,
		"lore": "Kuro's shurikens were once scattered across the void. The mind trial is the patience to line them up, three at a time, until the pattern reveals itself.",
		"seal_text": "Order from chaos, three shurikens at a time. The Seal of the Mind is yours."},
	"simon": {"numeral": "IV", "trial": "TRIAL OF MEMORY", "glyph": "memory", "hook": "Watch the pattern. Play it back.",
		"seal_rule": "Reach round 5", "seal_target": 5,
		"lore": "The last trial is Kuro's own art: the nine pads of the Star Dojo. A pattern watched is a pattern kept. Say the colours in your mind.",
		"seal_text": "The pattern lives in you now. The Seal of Memory is yours."},
}

const PROLOGUE_SUMMARY := "Before the first ninja there was only the void. In the Star Dojo, Kuro trained for a hundred years. Then a star fell, and the daggers of light came hunting. The old master stood between them, and took the star as his student. Four trials remain."
const EPILOGUE_SUMMARY := "With four seals the star shines unbroken. The daggers still come, as they always will, but now the void has a ninja who is ready for them."

static func trial(id: String) -> Dictionary:
	return TRIALS.get(id, {})

## Current progress toward a trial's seal, in the seal's own unit.
static func progress(id: String) -> int:
	match id:
		"knife": return int(SaveData.knife_stats().best)
		"draw": return int(SaveData.game_stats("draw").best)
		"match": return maxi(0, SaveData.match_next_level() - 1)
		"simon": return int(SaveData.game_stats("simon").best)
	return 0

static func seal_target(id: String) -> int:
	return int(trial(id).get("seal_target", 1))

static func seal_earned(id: String) -> bool:
	return progress(id) >= seal_target(id)

static func seals_count() -> int:
	var n := 0
	for id in ORDER:
		if seal_earned(id):
			n += 1
	return n

static func all_sealed() -> bool:
	return seals_count() == ORDER.size()

## Trials whose seal is earned but not yet celebrated on the hub.
static func pending_celebrations() -> Array:
	var out := []
	for id in ORDER:
		if seal_earned(id) and not SaveData.seal_celebrated(id):
			out.append(id)
	return out

## Guide lines played on the hub when a seal is earned.
static func seal_scene(id: String, pname: String) -> Array:
	var t := trial(id)
	var lines := [
		{"who": "sensei", "mood": "happy", "gesture": "point", "target": id, "text": str(t.seal_text)},
	]
	match id:
		"knife":
			lines.append({"who": "pip", "mood": "excited", "gesture": "hop", "text": "You dodged like a comet, %s! I knew it!" % pname})
		"draw":
			lines.append({"who": "pip", "mood": "excited", "gesture": "hop", "text": "Not a single decoy fooled you. My eyes are watering!"})
		"match":
			lines.append({"who": "pip", "mood": "happy", "text": "Three in a row, again and again. Even Sensei looked impressed."})
		"simon":
			lines.append({"who": "sensei", "mood": "think", "text": "Nine pads. You held them all. Few students ever do."})
	var left := ORDER.size() - seals_count()
	if left > 0:
		lines.append({"who": "sensei", "mood": "neutral", "text": "%d seal%s remain%s. The void is patient, but the star grows brighter." % [left, "" if left == 1 else "s", "s" if left == 1 else ""]})
	return lines

static func epilogue_scene(pname: String) -> Array:
	return [
		{"who": "sensei", "mood": "happy", "text": "Four seals. Blade, Eye, Mind, Memory. %s, you have finished what a hundred years began." % pname},
		{"who": "pip", "mood": "excited", "gesture": "hop", "text": "I'm shining! Look at me, I'm actually shining!"},
		{"who": "sensei", "mood": "think", "text": "The daggers will still come. That is the void. But now it has a ninja who is ready."},
		{"who": "pip", "mood": "happy", "text": "Every trial stays open, so... race you to a new high score?"},
	]
