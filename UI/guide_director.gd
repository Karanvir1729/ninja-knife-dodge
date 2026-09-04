extends Node
class_name GuideDirector
## Runs scripted conversations between the two guides and a speech bubble:
## the first-launch intro, return greetings, and tap-for-a-tip lines.
## Each line: {who: "sensei"|"pip", text: String, mood: String, gesture: "point"|"hop"|"", target: "mind"|"skill"}

signal finished
signal line_started(who: String)

const AUTO_ADVANCE := 7.0

var sensei: Mascot
var pip: Mascot
var bubble: SpeechBubble
var target_rect: Callable        # (name: String) -> Rect2 (global)
var highlighter: Callable        # (name: String, on: bool)
var bubble_bounds: Callable      # () -> Rect2 (global area the bubble may occupy)

var beside := false             # place the bubble to the speaker's right instead of above
var running := false
var _lines: Array = []
var _index := -1
var _waiting := false
var _auto := 0.0
var _speaker: Mascot

func setup(p_sensei: Mascot, p_pip: Mascot, p_bubble: SpeechBubble) -> void:
	sensei = p_sensei
	pip = p_pip
	bubble = p_bubble
	bubble.typed_char.connect(func(): if _speaker: _speaker.blip())
	bubble.finished_typing.connect(_on_finished_typing)
	bubble.advanced.connect(func(): if running and _waiting: _next())

func run(lines: Array) -> void:
	_lines = lines
	_index = -1
	running = true
	_next()

func skip_all() -> void:
	if running:
		_end()

func _next() -> void:
	_waiting = false
	if _speaker:
		_speaker.set_talking(false)
		_speaker.unpoint()
	if highlighter.is_valid():
		highlighter.call("", false)
	_index += 1
	if _index >= _lines.size():
		_end()
		return
	var line: Dictionary = _lines[_index]
	_speaker = sensei if str(line.get("who", "sensei")) == "sensei" else pip
	var other: Mascot = pip if _speaker == sensei else sensei
	other.set_talking(false)
	other.set_mood("neutral")
	_speaker.set_mood(str(line.get("mood", "neutral")))
	match str(line.get("gesture", "")):
		"point":
			var target := str(line.get("target", "mind"))
			if target_rect.is_valid():
				var r: Rect2 = target_rect.call(target)
				_speaker.point_at(r.get_center())
			if highlighter.is_valid():
				highlighter.call(target, true)
		"hop":
			_speaker.hop()
	line_started.emit(str(line.get("who", "sensei")))
	_speaker.set_talking(true)
	bubble.show_line(_speaker.display_name, str(line.text), _speaker.accent, _speaker.head_global())
	call_deferred("_place_bubble")

func _place_bubble() -> void:
	if not _speaker:
		return
	var head := _speaker.head_global()
	var bounds: Rect2 = bubble_bounds.call() if bubble_bounds.is_valid() else Globals.view_rect()
	var pos: Vector2
	if beside:
		pos = head + Vector2(70.0, -bubble.size.y * 0.35)
		pos.x = clampf(pos.x, bounds.position.x, bounds.end.x - bubble.size.x)
		pos.y = clampf(pos.y, bounds.position.y, bounds.end.y - bubble.size.y)
	else:
		pos = head + Vector2(-bubble.size.x * 0.35, -bubble.size.y - 34)
		pos.x = clampf(pos.x, bounds.position.x, bounds.end.x - bubble.size.x)
		pos.y = maxf(pos.y, bounds.position.y)
	bubble.global_position = pos
	bubble.anchor = head
	bubble.queue_redraw()

func _on_finished_typing() -> void:
	if _speaker:
		_speaker.set_talking(false)
	_waiting = true
	_auto = AUTO_ADVANCE

func _process(delta: float) -> void:
	if running and _waiting:
		_auto -= delta
		if _auto <= 0:
			_next()
	if running and bubble.visible:
		_place_bubble()

func _end() -> void:
	running = false
	_waiting = false
	bubble.hide_bubble()
	if _speaker:
		_speaker.set_talking(false)
		_speaker.unpoint()
	if highlighter.is_valid():
		highlighter.call("", false)
	finished.emit()

# ---------------------------------------------------------------- scripts

static func intro(pname: String) -> Array:
	return [
		{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Whoa, a new ninja! Welcome to the Star Dojo, %s!" % pname},
		{"who": "sensei", "mood": "neutral", "text": "I am Sensei Kuro. Four trials await you, one seal each."},
		{"who": "sensei", "mood": "think", "gesture": "point", "target": "skill", "text": "The Blade and the Eye test your reflexes: dodge the daggers, strike the targets."},
		{"who": "sensei", "mood": "think", "gesture": "point", "target": "mind", "text": "The Mind and Memory test your patience: align the shurikens, keep the pattern."},
		{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Earn all four seals and I'll shine unbroken! Tap us any time for a tip."},
	]

static func intro_legacy(pname: String) -> Array:
	return [
		{"who": "pip", "mood": "excited", "gesture": "hop", "text": "Whoa, a new ninja! Welcome to the void, %s!" % pname},
		{"who": "sensei", "mood": "neutral", "text": "Calm yourself, Pip. Welcome, young one. I am Sensei Kuro, and this is Pip."},
		{"who": "sensei", "mood": "think", "gesture": "point", "target": "mind", "text": "Two paths await you. Mind games sharpen your thinking: plan ahead, remember patterns, outwit the board."},
		{"who": "pip", "mood": "excited", "gesture": "point", "target": "skill", "text": "And skill games are all about fast fingers! Tap, dodge, react. My favourite!"},
		{"who": "sensei", "mood": "happy", "text": "Pick any game to begin. Tap either of us whenever you want a tip. We will be right here."},
	]

static func greeting(pname: String) -> Array:
	var hour: int = Time.get_time_dict_from_system().hour
	var when := "morning" if hour < 12 else ("afternoon" if hour < 18 else "evening")
	var options := [
		[{"who": "sensei", "mood": "happy", "text": "Good %s, %s. The void has been quiet without you." % [when, pname]}],
		[{"who": "pip", "mood": "excited", "gesture": "hop", "text": "You're back, %s! Let's beat a high score today!" % pname}],
		[{"who": "sensei", "mood": "think", "text": "A calm mind sees the whole board. Breathe, then play."}],
		[{"who": "pip", "mood": "happy", "text": "Psst. Knife Dodge waves get faster every loop. Just saying!"}],
		[{"who": "sensei", "mood": "happy", "text": "Welcome back. Which path today, %s: mind or skill?" % pname}],
	]
	return options[randi() % options.size()]

static func tip(who: String) -> Array:
	var sensei_tips := [
		"Four in a row forges a Line shuriken. Swap it again to fire it along its row or column.",
		"A Prism clears every shuriken of one colour. Save it for the colour you see the most.",
		"In Sensei Says, say the colours in your head as they light. The voice remembers.",
		"Out of moves? A hint or a few extra moves can be earned with a short ad. Use them wisely.",
		"Clearing three stars early ends the level and turns your leftover moves into bonus points.",
		"Patience. The board always offers a move. When it does not, it reshuffles itself.",
	]
	var pip_tips := [
		"Near misses in Knife Dodge score bonus points. Live dangerously!",
		"In Quick Draw the red daggers are decoys. Hands off!",
		"Chain hits in Quick Draw for combos. Every fifth hit makes them worth more!",
		"You can change your ninja name in Settings. Make it a cool one!",
		"Tap right under the star to launch it straight up. Tap beside it to dodge sideways!",
		"The leaderboards live on this device only. Every score is yours to beat!",
	]
	var pool: Array = sensei_tips if who == "sensei" else pip_tips
	return [{"who": who, "mood": "happy" if who == "sensei" else "excited", "text": pool[randi() % pool.size()]}]
