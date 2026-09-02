extends CanvasLayer
## Main menu: pick a game, or head to the leaderboards / settings.

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	get_viewport().size_changed.connect(func(): Globals.apply_safe_margins(%Root, 34))
	_refresh()
	%KnifeCard.pressed.connect(_start_knife)
	%KnifePlay.pressed.connect(_start_knife)
	%MatchCard.pressed.connect(_start_match)
	%MatchPlay.pressed.connect(_start_match)
	%TrophyBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%BoardBtn.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard"))
	%GearBtn.pressed.connect(func(): AudioManager.click(); Globals.go("settings"))
	%HowBtn.pressed.connect(func(): AudioManager.click(); _show_how(true))
	%HowClose.pressed.connect(func(): AudioManager.back(); _show_how(false))
	%HowDim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show_how(false))
	%HowKnife.pressed.connect(func(): AudioManager.click(); Globals.go("tutorial"))
	%HowMatch.pressed.connect(func(): AudioManager.click(); Globals.go("match_tutorial"))
	%HowTo.visible = false
	_enter_animation()

func _refresh() -> void:
	%PlayerName.text = SaveData.player_name()
	var k: Dictionary = SaveData.knife_stats()
	%KnifeBest.text = str(int(k.best))
	%KnifeRuns.text = str(int(k.runs))
	var next_level := SaveData.match_next_level()
	%MatchLevel.text = str(next_level)
	%MatchStars.text = str(SaveData.match_total_stars())
	%Version.text = "V%s  ·  OFFLINE  ·  NO ADS  ·  NO TRACKING" % Globals.VERSION

func _start_knife() -> void:
	AudioManager.click()
	if SaveData.tutorial_done("knife"):
		Globals.go("play")
	else:
		Globals.go("tutorial")

func _start_match() -> void:
	AudioManager.click()
	Globals.go("match_levels")

func _show_how(open: bool) -> void:
	%HowTo.visible = open

func _enter_animation() -> void:
	%TitleBlock.modulate.a = 0.0
	%TitleBlock.position.x -= 30
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(%TitleBlock, "modulate:a", 1.0, 0.45)
	t.tween_property(%TitleBlock, "position:x", %TitleBlock.position.x + 30, 0.45).set_ease(Tween.EASE_OUT)
	var i := 0
	for card in [%KnifeCard, %MatchCard]:
		card.modulate.a = 0.0
		card.position.x += 40
		var ct := create_tween()
		ct.set_parallel(true)
		ct.tween_property(card, "modulate:a", 1.0, 0.4).set_delay(0.1 + i * 0.1)
		ct.tween_property(card, "position:x", card.position.x - 40, 0.45).set_delay(0.1 + i * 0.1).set_ease(Tween.EASE_OUT)
		i += 1
