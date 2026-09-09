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

const ORDER := ["draw", "match", "simon", "knife"]

## Seals earned before the midpoint scene plays.
const MIDPOINT_AT := 2

## The chapter path, in the order the hub shows it. A chapter is unlocked when
## every trial before it has its seal (films and the yard never gate). Each
## chapter names the film that opens it; trials also name the film that plays
## when their seal is earned, the yard interlude the film for its goal.
##   kind   film | trial | yard
const CHAPTERS := [
	{"id": "prologue", "kind": "film", "film": "prologue", "label": "PROLOGUE", "title": "THE STAR DOJO",
	 "hook": "The void, the dojo, and the star that fell into it.", "glyph": "res://graphics/gen/story/lantern.png", "accent": Color("ffd84d")},
	{"id": "draw", "kind": "trial", "film": "eye", "seal_film": "seal_eye"},
	{"id": "cricket", "kind": "yard", "film": "cricket", "goal_film": "cricket_fifty", "label": "INTERLUDE", "title": "THE TEAM FROM JAPAN"},
	{"id": "match", "kind": "trial", "film": "mind", "seal_film": "seal_mind"},
	{"id": "midpoint", "kind": "film", "film": "midpoint", "label": "THE TURN", "title": "WHAT THE DAGGERS WERE",
	 "hook": "Two seals buy the truth about the daggers of light.", "glyph": "res://graphics/skeleton_sword.png", "accent": Color("ff3b5c")},
	{"id": "simon", "kind": "trial", "film": "name", "seal_film": "seal_name"},
	{"id": "knife", "kind": "trial", "film": "blade", "seal_film": "seal_blade"},
	{"id": "epilogue", "kind": "film", "film": "epilogue", "label": "EPILOGUE", "title": "THE STAR SHINES",
	 "hook": "Four seals. Kuro sits down, and the dojo changes hands.", "glyph": "res://graphics/gen/player_star.png", "accent": Color("ffd84d")},
]
const FILM_DIR := "res://story/films/"

const TRIALS := {
	"knife": {
		"numeral": "IV", "trial": "TRIAL OF THE BLADE", "glyph": "blade",
		"hook": "Be elsewhere when they arrive.",
		"seal_name": "Seal of Empty Air", "seal_rule": "Score 25 in one run", "seal_target": 25,
		"lore": "The daggers of light hunt whatever is still burning, and out here that is a short list. Kuro's first lesson is the only one the dojo ever proved against them: a blade owns the thin line it travels on, and every other place in the void belongs to you. Move before you are moved.",
		"opening": [
			{"who": "sensei", "mood": "neutral", "gesture": "point", "target": "knife", "text": "The daggers hunt whatever is still burning. Tonight that is you. Be elsewhere when they arrive."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Score twenty-five in one run and the seal is yours. Slip past one closely and it counts five."},
			{"who": "sensei", "mood": "think", "text": "Move before you are moved, {name}. It is the one lesson this dojo ever proved."},
		],
		"seal_lines": [
			{"who": "sensei", "mood": "happy", "gesture": "point", "target": "knife", "text": "Twenty-five daggers, and every one of them found empty air. The Seal of Empty Air is yours."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "They went through where you used to be, {name}. Twenty-five times. I checked."},
			{"who": "sensei", "mood": "think", "text": "My best was thirty-one. It was a long time ago, and I was not old."},
		],
	},
	"draw": {
		"numeral": "I", "trial": "TRIAL OF THE EYE", "glyph": "eye",
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
		"numeral": "II", "trial": "TRIAL OF THE MIND", "glyph": "mind",
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
		"numeral": "III", "trial": "TRIAL OF THE NAME", "glyph": "memory",
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

## Yard games sit beside the trials: no seal, but a story of their own.
const YARD := {
	"cricket": {
		"caps": "THE YARD  ·  STAR CRICKET",
		"hook": "Japan's cricket team prays here before they face India.",
		"quote": "I do not do miracles. I do drills.", "quote_by": "KURO",
		"drill": "KURO'S DRILL  ·  READ THE FIELD. SWING ONCE.",
		"intro": "EVERY SPRING A TEAM FROM JAPAN CLIMBS UP HERE AND PRAYS TO KURO BEFORE THEY PLAY INDIA. HE ANSWERS WITH A DRILL. THIS IS IT.",
		"opening": [
			{"who": "sensei", "mood": "neutral", "gesture": "point", "target": "cricket", "text": "A cricket team climbs up here every spring. From Japan. They pray to me before they play India."},
			{"who": "pip", "mood": "think", "text": "They have never beaten India. Not once. I keep the scorebook."},
			{"who": "sensei", "mood": "think", "text": "I do not do miracles, {name}. I do drills. Read the field. Wait for the ball. Swing once."},
			{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Score fifty out here and I will tell them a ninja did it. They might finally listen."},
		],
		"lore": "Every spring a cricket team from Japan climbs to the Star Dojo to pray before they play India. They have never won. Kuro does not do miracles; he does drills, so he laid a pitch in the yard and bowls with the void itself. Read the field. Wait for the ball. Swing once. The daggers, for once, stay out of it.",
		"goal": "Score fifty in one innings and Pip tells the team a ninja did it.",
		"goal_target": 50,
	},
}

## The turn: the truth about the daggers, once the player has two seals.
const MIDPOINT := [
	{"who": "sensei", "mood": "neutral", "text": "{name}. Two seals. You have earned the truth about the daggers of light."},
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
		if seal_earned(id) and not SaveData.seal_celebrated(id) and _trials_before_sealed(id):
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

static func yard(id: String) -> Dictionary:
	return YARD.get(id, {})

## Lines played on the hub the first time the player opens a trial or a yard game.
static func opening_scene(id: String, pname: String) -> Array:
	var lines: Array = trial(id).get("opening", [])
	if lines.is_empty():
		lines = yard(id).get("opening", [])
	return _scene(lines, pname)

static func has_opening(id: String) -> bool:
	return not trial(id).get("opening", []).is_empty() or not yard(id).get("opening", []).is_empty()

## Lines played on the hub when a seal is earned.
static func seal_scene(id: String, pname: String) -> Array:
	return _scene(trial(id).get("seal_lines", []), pname)

## The name of the seal a trial awards, for the journal and the seal wheel.
static func seal_name(id: String) -> String:
	return str(trial(id).get("seal_name", ""))

## The turn: played once, on the hub, at MIDPOINT_AT seals.
static func midpoint_due() -> bool:
	return seals_count() >= MIDPOINT_AT and _trials_before_sealed("midpoint") \
		and not all_sealed() and not SaveData.story_flag("midpoint_seen")

static func midpoint_scene(pname: String) -> Array:
	return _scene(MIDPOINT, pname)

static func epilogue_scene(pname: String) -> Array:
	return _scene(EPILOGUE, pname)

# ---------------------------------------------------------------- films

## The story flag a film sets when it has played (or been skipped).
static func film_flag(film: String) -> String:
	match film:
		"prologue": return "prologue_seen"
		"midpoint": return "midpoint_seen"
		"epilogue": return "epilogue_seen"
	return "film_%s_seen" % film

static func film_seen(film: String) -> bool:
	return SaveData.story_flag(film_flag(film))

## Films are optional until they are built: a missing one is simply skipped.
static func film_exists(film: String) -> bool:
	return not film.is_empty() and ResourceLoader.exists(FILM_DIR + film + ".tscn")

## The film that opens a chapter ("" when it is missing).
static func opening_film(id: String) -> String:
	var f := str(chapter(id).get("film", ""))
	return f if film_exists(f) else ""

## The film that plays when a trial's seal is earned ("" when missing).
static func seal_film(id: String) -> String:
	var f := str(chapter(id).get("seal_film", ""))
	return f if film_exists(f) else ""

## Films due on the hub right now, in order: seal films for seals earned but
## not yet celebrated, the turn, the ending, then the yard's goal film. Each
## entry is the params for Globals.go("film", ...) plus the chapter it is for.
static func pending_films() -> Array:
	var out := []
	for id in ORDER:
		# A seal earned out of turn waits: its film stages the chapters before it.
		if seal_earned(id) and not SaveData.seal_celebrated(id) and _trials_before_sealed(id):
			var f := seal_film(id)
			if not f.is_empty():
				out.append({"film": f, "chapter": id, "return": "start"})
	if midpoint_due() and film_exists("midpoint"):
		out.append({"film": "midpoint", "chapter": "midpoint", "return": "start"})
	if all_sealed() and not SaveData.story_flag("epilogue_seen") and film_exists("epilogue"):
		out.append({"film": "epilogue", "chapter": "epilogue", "return": "start"})
	for c in CHAPTERS:
		if str(c.kind) == "yard":
			var goal := str(c.get("goal_film", ""))
			var y := yard(str(c.id))
			if film_exists(goal) and not film_seen(goal) and _trials_before_sealed(str(c.id)) and int(y.get("goal_target", 0)) > 0 and SaveData.best_for(str(c.id)) >= int(y.goal_target):
				out.append({"film": goal, "chapter": str(c.id), "return": "start"})
	return out

## Chain a list of pending films into one params dictionary (each "then"s the next).
static func chain_films(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}
	var head: Dictionary = entries[0].duplicate()
	var rest := entries.slice(1)
	if not rest.is_empty():
		head["then"] = chain_films(rest)
	return head

# ---------------------------------------------------------------- chapters

static func chapter(id: String) -> Dictionary:
	for c in CHAPTERS:
		if str(c.id) == id:
			return c
	return {}

static func chapter_index(id: String) -> int:
	for i in CHAPTERS.size():
		if str(CHAPTERS[i].id) == id:
			return i
	return -1

static func chapter_ids() -> Array:
	var out := []
	for c in CHAPTERS:
		out.append(str(c.id))
	return out

## Unlocked when every trial before it in the path has its seal. A chapter the
## player has already finished, or that the hub has already shown them as open,
## never closes again: the path was reordered in 2.3 (the Blade moved to the
## end), and nobody should lose a chapter they had already reached.
static func chapter_unlocked(id: String) -> bool:
	var idx := chapter_index(id)
	if idx < 0:
		return false
	if chapter_done(id):
		return true
	# Build 11's hub marked the first two cards revealed by position, and the
	# Blade sat second, so "revealed" alone would hand every old save a chapter
	# it never reached. A trial has to have actually been entered.
	if SaveData.chapter_revealed(id) and (str(CHAPTERS[idx].get("kind", "")) != "trial" or SaveData.trial_opened(id)):
		return true
	return _trials_before_sealed(id)

## Is every trial that sits before this chapter in the path sealed? This is the
## plain path test, without the clauses above that keep finished chapters open,
## so the beats that belong to a place in the story can ask it directly.
static func _trials_before_sealed(id: String) -> bool:
	var idx := chapter_index(id)
	if idx < 0:
		return false
	for i in idx:
		var c: Dictionary = CHAPTERS[i]
		if str(c.kind) == "trial" and not seal_earned(str(c.id)):
			return false
	return true

## Done: a film watched, a trial sealed, the yard's goal reached.
static func chapter_done(id: String) -> bool:
	var c := chapter(id)
	match str(c.get("kind", "")):
		"film": return film_seen(str(c.film))
		"trial": return seal_earned(id)
		"yard":
			var y := yard(id)
			return int(y.get("goal_target", 0)) > 0 and SaveData.best_for(id) >= int(y.goal_target)
	return false

## The chapter the player is on: the first unlocked one that is not done
## (the yard counts as visited once its film has played). "" when all done.
static func current_chapter() -> String:
	for c in CHAPTERS:
		var id := str(c.id)
		if not chapter_unlocked(id):
			continue
		if str(c.kind) == "yard":
			if not film_seen(str(c.film)) and film_exists(str(c.film)):
				return id
			continue
		if not chapter_done(id):
			return id
	return ""

## The seal a locked chapter is waiting on (the first missing one before it).
static func unlock_seal(id: String) -> String:
	var idx := chapter_index(id)
	for i in maxi(0, idx):
		var c: Dictionary = CHAPTERS[i]
		if str(c.kind) == "trial" and not seal_earned(str(c.id)):
			return str(c.id)
	return ""

## Small caps label above a chapter card: PROLOGUE, CHAPTER I, INTERLUDE...
static func chapter_label(id: String) -> String:
	var c := chapter(id)
	if str(c.get("kind", "")) == "trial":
		return "CHAPTER %s" % str(trial(id).get("numeral", ""))
	return str(c.get("label", id.to_upper()))

static func chapter_title(id: String) -> String:
	var c := chapter(id)
	match str(c.get("kind", "")):
		"trial": return str(trial(id).get("trial", id.to_upper()))
		"yard": return str(c.get("title", str(Globals.game(id).get("title", id.to_upper()))))
	return str(c.get("title", id.to_upper()))

static func chapter_hook(id: String) -> String:
	var c := chapter(id)
	match str(c.get("kind", "")):
		"trial": return str(trial(id).get("hook", ""))
		"yard": return str(yard(id).get("hook", ""))
	return str(c.get("hook", ""))
