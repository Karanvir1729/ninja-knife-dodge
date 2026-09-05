class_name Story
extends RefCounted
## "The Last Lantern": the storyline that ties the four games together.
##
## The void the dojo calls the Quiet does not kill things, it unmakes them, and
## a name is the last part to go. Each game is a trial with a seal; the seal
## conditions are read from stats the games already keep, so nothing new is
## stored except which scenes have played.
##
## Every scene below is a queue of lines for GuideDirector: {who, mood, gesture,
## target, text}. "{name}" is replaced with the player's ninja name.

const ORDER := ["knife", "draw", "match", "simon"]

## Seals earned before the midpoint scene plays.
const MIDPOINT_AT := 2

const TRIALS := {
	"knife": {
		"numeral": "I", "trial": "TRIAL OF THE BLADE", "glyph": "blade",
		"hook": "Be elsewhere when they arrive.",
		"seal_name": "Seal of Empty Air", "seal_rule": "Dodge 25 daggers in one run", "seal_target": 25,
		"lore": "The daggers of light hunt whatever is still burning, and out here that is a short list. Kuro's first lesson is the only one the dojo ever proved against them: a blade owns the thin line it travels on, and every other place in the void belongs to you. Move before you are moved.",
		"opening": [
			{"who": "sensei", "mood": "neutral", "gesture": "point", "target": "knife", "text": "The daggers hunt whatever is still burning. Tonight that is you. Be elsewhere when they arrive."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Twenty-five dodged in one run and the seal is yours. My record is eleven. Once."},
			{"who": "sensei", "mood": "think", "text": "Move before you are moved, {name}. It is the one lesson this dojo ever proved."},
		],
		"seal_lines": [
			{"who": "sensei", "mood": "happy", "gesture": "point", "target": "knife", "text": "Twenty-five daggers, and every one of them found empty air. The Seal of Empty Air is yours."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "They went through where you used to be, {name}. Twenty-five times. I checked."},
			{"who": "sensei", "mood": "think", "text": "My best was thirty-one. It was a long time ago, and I was not old."},
		],
	},
	"draw": {
		"numeral": "II", "trial": "TRIAL OF THE EYE", "glyph": "eye",
		"hook": "The red ones are copies. Leave them.",
		"seal_name": "Seal of the True Light", "seal_rule": "Score 20 in one round", "seal_target": 20,
		"lore": "The Quiet makes nothing of its own. It copies what it has already taken and paints the copy red, because a hand that answers a lie is a hand out of position. Kuro answered one once, a long way from here. He will not say what it cost him, only that he now counts to one before he strikes.",
		"opening": [
			{"who": "sensei", "mood": "think", "gesture": "point", "target": "draw", "text": "The Quiet cannot make light. It can only copy what it took, and the copies come out red."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Score twenty and the seal is yours. Sensei's best is forty. It used to be more."},
			{"who": "sensei", "mood": "neutral", "text": "Do not answer a lie, {name}. Answering costs more than missing."},
		],
		"seal_lines": [
			{"who": "sensei", "mood": "happy", "gesture": "point", "target": "draw", "text": "Twenty true lights, struck before the Quiet could finish a copy. The Seal of the True Light is yours."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "I flinched at three of the red ones. From back here. Sitting down."},
			{"who": "sensei", "mood": "happy", "text": "Progress, Pip. Last year you flinched at four."},
		],
	},
	"match": {
		"numeral": "III", "trial": "TRIAL OF THE MIND", "glyph": "mind",
		"hook": "Three of a colour. Nine hundred to go.",
		"seal_name": "Seal of the Gathered", "seal_rule": "Clear level 3", "seal_target": 3,
		"lore": "The Star Dojo kept nine hundred shurikens on nine hundred hooks. The Quiet scattered them in a single night, and Kuro has spent eighty years bringing them back three of a colour at a time. He says the gathering is the point. He also knows he will not finish, and he goes out for them anyway.",
		"opening": [
			{"who": "sensei", "mood": "neutral", "gesture": "point", "target": "match", "text": "The dojo kept nine hundred shurikens on nine hundred hooks. The Quiet scattered them in one night."},
			{"who": "pip", "mood": "think", "text": "How many has he got back? He will not tell me. I have asked for years."},
			{"who": "sensei", "mood": "neutral", "text": "Three of a colour at a time, {name}. That is the whole method. Begin."},
		],
		"seal_lines": [
			{"who": "sensei", "mood": "happy", "gesture": "point", "target": "match", "text": "Three levels. Order out of scatter, three at a time. The Seal of the Gathered is yours."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "That is a piece of eighty years of Sensei's work, done before dinner."},
			{"who": "sensei", "mood": "think", "text": "Eighty years. I am not bitter, {name}. I am tired. It is a different thing."},
		],
	},
	"simon": {
		"numeral": "IV", "trial": "TRIAL OF THE NAME", "glyph": "memory",
		"hook": "Nine pads. Nine masters. Hold the roll.",
		"seal_name": "Seal of the Kept Name", "seal_rule": "Reach round 5", "seal_target": 5,
		"lore": "Nine pads, one for each master of the Star Dojo, in the order they stood at dawn. Kuro is the ninth and can still play the whole roll without thinking. The eighth was his own master; he lost her name somewhere in the second fifty years and kept her drill instead. The Quiet does not kill things. It makes them forgotten, and forgotten is the worse half.",
		"opening": [
			{"who": "sensei", "mood": "neutral", "gesture": "point", "target": "simon", "text": "Nine pads. Nine masters of the Star Dojo, in the order they stood. I am the ninth."},
			{"who": "sensei", "mood": "think", "text": "The Quiet takes a name last. I can play all nine patterns. I can name eight."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Reach round five, {name}. Hold the pattern. I am going to hold my breath."},
		],
		"seal_lines": [
			{"who": "sensei", "mood": "happy", "gesture": "point", "target": "simon", "text": "Round five, held whole when it got long. The Seal of the Kept Name is yours."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Say your own name out loud after, {name}. It helps. Sensei taught me that."},
			{"who": "sensei", "mood": "think", "text": "The eighth pad was my master. I kept her drill. I lost her name. Keep yours."},
		],
	},
}

## The turn: the truth about the daggers, once the player has two seals.
const MIDPOINT := [
	{"who": "sensei", "mood": "neutral", "text": "{name}. Two seals. You have earned the truth about what you have been dodging."},
	{"who": "sensei", "mood": "think", "text": "Every dagger of light was a star. The Quiet unmade them and kept the edges."},
	{"who": "pip", "mood": "neutral", "text": "...I have been calling them light. This whole time. Out loud."},
	{"who": "sensei", "mood": "think", "text": "You came through them whole, Pip. Nothing else ever has. That is why they keep coming."},
	{"who": "pip", "mood": "happy", "gesture": "hop", "text": "Right. Then we do not lose. Two more, {name}. I am counting them now too."},
]

const EPILOGUE := [
	{"who": "sensei", "mood": "happy", "text": "Four seals. The star holds. I did not think I would be standing here for this."},
	{"who": "sensei", "mood": "think", "text": "For ninety years I have been the only thing standing here. Tonight I was not."},
	{"who": "pip", "mood": "neutral", "text": "Sensei. Sit down. You have been standing since before I fell."},
	{"who": "sensei", "mood": "happy", "gesture": "point", "target": "knife", "text": "The dojo is yours now, {name}. Two lanterns. Light them both. Keep the count."},
	{"who": "pip", "mood": "happy", "text": "His name is Kuro. I am saying it out loud so it stays. Kuro."},
	{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Every trial stays open, {name}. Come back. We will keep the light on."},
]

const PROLOGUE_SUMMARY := "The void came first, and the dojo named it the Quiet: it does not kill things, it unmakes them, and a name is the last part to go. Kuro was the ninth master of the Star Dojo. He trained a hundred years, and then a star fell into the dojo still burning, and the daggers came for it, and he stood between. Now his hands are old and one lantern is already out. Four trials remain."
const EPILOGUE_SUMMARY := "Four seals, and the star holds. Kuro sat down for the first time in a hundred years and gave the dojo away. Pip says his name out loud most days, so that it stays. The daggers still come. They are no longer the only thing that does."

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

## One substitution rule for every scene in the edition.
static func _scene(lines: Array, pname: String) -> Array:
	var out := []
	for l in lines:
		var d: Dictionary = l.duplicate()
		d.text = str(d.text).replace("{name}", pname)
		out.append(d)
	return out

## Lines played on the hub the first time the player opens a trial.
static func opening_scene(id: String, pname: String) -> Array:
	return _scene(trial(id).get("opening", []), pname)

static func has_opening(id: String) -> bool:
	return not trial(id).get("opening", []).is_empty()

## Lines played on the hub when a seal is earned.
static func seal_scene(id: String, pname: String) -> Array:
	return _scene(trial(id).get("seal_lines", []), pname)

## The name of the seal a trial awards, for the journal and the seal wheel.
static func seal_name(id: String) -> String:
	return str(trial(id).get("seal_name", ""))

## The turn: played once, on the hub, at MIDPOINT_AT seals.
static func midpoint_due() -> bool:
	return seals_count() >= MIDPOINT_AT and not all_sealed() and not SaveData.story_flag("midpoint_seen")

static func midpoint_scene(pname: String) -> Array:
	return _scene(MIDPOINT, pname)

static func epilogue_scene(pname: String) -> Array:
	return _scene(EPILOGUE, pname)
