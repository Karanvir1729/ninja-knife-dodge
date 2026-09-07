extends CanvasLayer
## First launch: sign in with Apple before the story starts, so seals, scores
## and chapters follow the player. On builds without the native plugin (desktop,
## the simulator, the debug tour) the only way in is "continue on this device".

const MASCOT := preload("res://UI/mascot.gd")

var _sensei: Mascot
var _pip: Mascot
var _leaving := false
var _from := ""          # "settings" when opened from Settings > Account

func init(params: Dictionary) -> void:
	_from = str(params.get("from", ""))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 30)
	get_viewport().size_changed.connect(_on_resize)
	%AppleBtn.pressed.connect(_on_apple)
	%GuestBtn.pressed.connect(_on_guest)
	%BackBtn.pressed.connect(_on_back)
	%Status.text = ""
	%Busy.visible = false
	var apple := Backend.apple_available()
	%AppleBtn.visible = apple
	# Apple first. The device-only option appears only where Apple cannot sign
	# in at all, after an attempt fails or is cancelled, or when coming from Settings.
	%GuestBtn.visible = not apple
	%GuestBtn.text = "CONTINUE ON THIS DEVICE"
	%NoApple.visible = not apple
	%BackBtn.visible = _from == "settings"
	Backend.signed_in.connect(_on_signed_in)
	Backend.sign_in_failed.connect(_on_failed)
	_setup_guides()
	_enter_animation()

func _on_resize() -> void:
	Globals.apply_safe_margins(%Root, 30)
	call_deferred("_place_guides", false)

func _on_apple() -> void:
	if Backend.busy or _leaving:
		return
	AudioManager.click()
	%Status.text = ""
	%Busy.visible = true
	%AppleBtn.disabled = true
	Backend.sign_in_with_apple()

func _on_guest() -> void:
	if _leaving:
		return
	AudioManager.click()
	Backend.continue_as_guest()
	_proceed()

func _on_signed_in() -> void:
	%Busy.visible = false
	%Status.add_theme_color_override("font_color", Globals.GREEN)
	%Status.text = "SIGNED IN. WELCOME, NINJA."
	AudioManager.play_sfx("seal", 1.0, -4.0)
	if _pip: _pip.set_mood("excited")
	if _sensei: _sensei.set_mood("happy")
	await Backend.merge_from_cloud()
	_proceed()

func _on_failed(message: String) -> void:
	%Busy.visible = false
	%AppleBtn.disabled = false
	%Status.add_theme_color_override("font_color", Globals.RED if not message.is_empty() else Globals.MUTED)
	%Status.text = message.to_upper() if not message.is_empty() else "NO SIGN-IN YET. TAP THE BUTTON TO TRY AGAIN."
	if _pip and not message.is_empty(): _pip.set_mood("think")
	# Never a dead end: after a failed or cancelled attempt the player can go on
	# without an account (offline launch, no Apple ID on the device) and sign in
	# later from Settings > Account.
	%GuestBtn.text = "NOT NOW  ·  PLAY ON THIS DEVICE"
	%GuestBtn.visible = true

func _on_back() -> void:
	if _leaving:
		return
	AudioManager.back()
	_leaving = true
	Globals.go("settings")

## On into the story (the prologue the first time), or back to Settings.
func _proceed() -> void:
	if _leaving:
		return
	_leaving = true
	await get_tree().create_timer(0.6).timeout
	if _from == "settings":
		Globals.go("settings")
	else:
		Globals.go("start" if SaveData.story_flag("prologue_seen") else "cinematic", {"return": "start"})

func _setup_guides() -> void:
	_sensei = MASCOT.new()
	_sensei.character = "sensei"
	_sensei.base_scale = 0.56
	_pip = MASCOT.new()
	_pip.character = "pip"
	_pip.base_scale = 0.56
	%Actors.add_child(_sensei)
	%Actors.add_child(_pip)
	await get_tree().process_frame
	await get_tree().process_frame
	_place_guides(true)

func _place_guides(animate: bool) -> void:
	if _sensei == null:
		return
	var r := Globals.view_rect()
	var s := Globals.safe_insets()
	var floor_y := r.end.y - 40.0 - float(s.bottom)
	var home_s := Vector2(r.position.x + 130.0 + float(s.left), floor_y - 118.0 * _sensei.base_scale)
	var home_p := Vector2(r.position.x + 275.0 + float(s.left), floor_y - 92.0 * _pip.base_scale)
	if animate:
		_sensei.enter(home_s + Vector2(-500, 0), home_s, 0.1)
		_pip.enter(home_p + Vector2(-700, 0), home_p, 0.35)
	else:
		_sensei.position = home_s
		_pip.position = home_p

func _enter_animation() -> void:
	%Card.modulate.a = 0.0
	create_tween().tween_property(%Card, "modulate:a", 1.0, 0.5).set_delay(0.15)
