extends CanvasLayer
class_name OfferOverlay
## "Use a booster or watch an ad" dialog shared by every game.
##
##   var overlay := OfferOverlay.open(get_tree(), "moves")
##   var got_it: bool = await overlay.finished
##
## When the player owns the booster they can spend one; otherwise (or as well)
## they can watch a rewarded ad. Either way the booster is consumed on success
## so callers only see a yes/no. Works while the tree is paused.

signal finished(got_reward: bool)

const SCENE := "res://UI/offer_overlay.tscn"

var placement := ""
var _done := false

static func open(tree: SceneTree, p_placement: String, title_override: String = "") -> OfferOverlay:
	var scene: PackedScene = load(SCENE)
	var o: OfferOverlay = scene.instantiate()
	o.placement = p_placement
	tree.root.add_child(o)
	if title_override != "":
		o.get_node("%Title").text = title_override
	return o

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var info: Dictionary = Ads.placement_info(placement)
	var booster := str(info.get("booster", placement))
	var count := SaveData.booster_count(booster)
	%Title.text = str(info.get("title", "POWER UP"))
	%Blurb.text = str(info.get("blurb", ""))
	%Reward.text = "REWARD: " + str(info.get("reward", "")).to_upper()
	%UseBtn.visible = count > 0
	%UseBtn.text = "USE ONE  ·  %d LEFT" % count
	%AdBtn.visible = Ads.available(placement)
	%AdBtn.text = "WATCH AD  ·  %s" % str(info.get("reward", "")).to_upper()
	%Reward.visible = %AdBtn.visible
	if not %AdBtn.visible and count == 0 and Ads.is_real():
		# The SDK has no video loaded yet (first seconds after launch, or no fill).
		%Blurb.text = "No ad is ready right now. Play on and try again in a moment."
	%UseBtn.pressed.connect(func(): choose("use"))
	%AdBtn.pressed.connect(func(): choose("ad"))
	%NoBtn.pressed.connect(func(): choose("no"))
	%Card.pivot_offset = %Card.size * 0.5
	%Card.scale = Vector2(0.92, 0.92)
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(%Card, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx("ui_click", 0.9, -6.0)

## "use" spends an owned booster, "ad" plays a rewarded ad then spends the
## booster it grants, "no" declines. Tests call this directly.
func choose(which: String) -> void:
	if _done:
		return
	var info: Dictionary = Ads.placement_info(placement)
	var booster := str(info.get("booster", placement))
	match which:
		"use":
			_finish(SaveData.use_booster(booster))
		"ad":
			%Buttons.visible = false
			_set_waiting(true)
			var rewarded: bool = await Ads.show_rewarded(placement)
			if not is_inside_tree():
				return
			_set_waiting(false)
			if rewarded:
				_finish(SaveData.use_booster(booster))
			else:
				%Blurb.text = "The ad did not finish, so there is no reward. You can try again."
				%AdBtn.visible = Ads.available(placement)
				%Buttons.visible = true
		_:
			AudioManager.back()
			_finish(false)

var _waiting: Label = null

## A visible state while the video plays, so a slow ad never looks like a freeze.
func _set_waiting(on: bool) -> void:
	if on and _waiting == null:
		_waiting = Label.new()
		_waiting.theme_type_variation = &"CapsLabel"
		_waiting.add_theme_font_size_override("font_size", 15)
		_waiting.add_theme_color_override("font_color", Globals.MUTED)
		_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_waiting.text = "PLAYING THE AD  ·  YOUR REWARD LANDS WHEN IT ENDS"
		%Buttons.get_parent().add_child(_waiting)
	elif not on and _waiting != null:
		_waiting.queue_free()
		_waiting = null

func _finish(ok: bool) -> void:
	_done = true
	if ok:
		AudioManager.play_sfx("booster")
		AudioManager.vibrate(25)
	finished.emit(ok)
	queue_free()
