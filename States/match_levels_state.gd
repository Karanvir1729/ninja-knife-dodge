extends CanvasLayer
## Shuriken Match level select: a winding path of level nodes (see
## match/level_map.gd). Continue where you left off, replay any cleared level
## for more stars, or skip the next one after two failed attempts.

var _next := 1
var _offer: OfferOverlay

func init(_p: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("match")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	%Back.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	%ContinueBtn.pressed.connect(func(): _play(_next))
	%Map.level_pressed.connect(_play)
	%Map.skip_pressed.connect(_skip)
	get_viewport().size_changed.connect(_layout)
	%Scroll.resized.connect(_layout)
	_refresh()
	# The scroll range only exists once the map has been laid out.
	await get_tree().process_frame
	await get_tree().process_frame
	_center_on(_next, false)

func _refresh() -> void:
	_next = mini(SaveData.match_next_level(), MatchLevels.LEVEL_COUNT)
	%ContinueBtn.text = "CONTINUE  ·  LEVEL %d" % _next if _next > 1 else "START  ·  LEVEL 1"
	%StarsVal.text = "%d / %d" % [SaveData.match_total_stars(), MatchLevels.LEVEL_COUNT * 3]
	var p := MatchLevels.params(_next)
	%NextInfo.text = "TARGET %s  ·  %d MOVES  ·  %d COLOURS" % [Globals.format_number(int(p.target)), int(p.moves), int(p.colors)]
	%Map.build(_next, SaveData.match_attempts(_next) >= 2)
	_layout()

func _layout() -> void:
	Globals.apply_safe_margins(%Root, 34)
	%Map.custom_minimum_size = Vector2(MatchLevels.LEVEL_COUNT * 150.0 + 300.0, %Scroll.size.y)

## Scroll so `level`'s node sits in the middle of the screen.
func _center_on(level: int, animate: bool) -> void:
	var target := int(%Map.level_pos(level).x - %Scroll.size.x * 0.5)
	if animate:
		var t := create_tween()
		t.tween_property(%Scroll, "scroll_horizontal", target, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		%Scroll.scroll_horizontal = target

func _exit_tree() -> void:
	if is_instance_valid(_offer):
		_offer.queue_free()
		_offer = null

func _play(level: int) -> void:
	AudioManager.click()
	if SaveData.tutorial_done("match"):
		Globals.go("match_play", {"level": level})
	else:
		Globals.go("match_tutorial", {"level": level})

## SKIP pill under the next level (after two failed attempts): booster or ad.
func _skip(level: int) -> void:
	AudioManager.click()
	if is_instance_valid(_offer):
		return
	_offer = OfferOverlay.open(get_tree(), "skip")
	var ok: bool = await _offer.finished
	_offer = null
	if not ok or not is_inside_tree():
		return
	SaveData.skip_match_level(level)
	AudioManager.play_sfx("unlock")
	_refresh()
	await get_tree().process_frame
	_center_on(_next, true)
