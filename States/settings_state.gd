extends CanvasLayer
## Settings: ninja name, audio, haptics, tutorials, about, and a guarded reset.

const PRIVACY_TEXT := """[b]What Ninja Knife Dodge stores about you.[/b]

• You sign in with Apple. Apple gives the game a random account ID and, if you allow it, your email address (you can choose to hide it). Nothing else from your Apple ID is shared.
• Your ninja name, best scores, chapter and seal progress and boosters are backed up to the game's account database (hosted by Supabase) after each round, so they follow you to a new device. Your ninja name and best scores may appear on leaderboards; your email never does.
• Everything is also saved on this device. There are no third-party analytics or tracking SDKs.
• Delete your account at any time from Settings > Account: the cloud copy is erased for good. Deleting the app deletes the local copy.

Questions: mehar.khanna@uwaterloo.ca"""

const ADS_TEXT := """

[b]Ads[/b]
This version is ad supported. Between rounds a short full-screen ad may play - never during play, never in your first rounds, at most one every few rounds and never twice within a couple of minutes. You can also choose to watch a rewarded video for a power-up, hint, skip or second chance; every reward can be used without watching one. Ads are served by Google AdMob, which may collect device identifiers and usage information under Google's privacy policy. The app never asks to track you and the ads are non-personalised."""

const SUPPORT_TEXT := """Found a bug or have an idea?

• Email: [color=#56f0ff]mehar.khanna@uwaterloo.ca[/color]
• GitHub: [color=#56f0ff]github.com/Karanvir1729/ninja-knife-dodge[/color]

Include your device model and what you were doing when it happened. Screenshots help."""

const CREDITS_TEXT := """[b]Design & code[/b]  Karanvir Khanna
[b]Engine[/b]  Godot Engine (MIT)

[b]Type[/b]
• Game Continue 02 by gomarice
• Chakra Petch by Cadson Demak (SIL Open Font License)

[b]Art[/b]
• Skeleton sword by inog (opengameart.org)
• Shurikens, icons and glows drawn for this game

[b]Sound[/b]
• Fast swing air woosh by cosmicembers (freesound)
• Koto, Garden and Dusk by Tozan (opengameart.org, CC0) - looped and levelled for this game
• Mysterious; Music Box Game Over 2, re-mastered quieter and softer for this game
• The Loop Room's twenty tunes, the Shuriken Match ambience, the story score and every other effect are synthesised in-house"""

func init(_params: Dictionary) -> void:
	pass

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("menu")
	AudioManager.play_music("menu")
	Globals.apply_safe_margins(%Root, 34)
	%Back.pressed.connect(_back)
	%NameEdit.text = SaveData.player_name()
	%NameEdit.max_length = SaveData.MAX_NAME_LENGTH
	%NameEdit.text_changed.connect(_on_name_changed)
	%NameEdit.text_submitted.connect(func(_t): %NameEdit.release_focus())
	%NameEdit.focus_exited.connect(func(): SaveData.set_player_name(%NameEdit.text); %NameEdit.text = SaveData.player_name())
	%MusicToggle.set_on_silent(bool(SaveData.setting("music")))
	%MusicToggle.toggled.connect(func(on): SaveData.set_setting("music", on))
	%MusicSlider.value = float(SaveData.setting("music_volume")) * 100.0
	%MusicSlider.value_changed.connect(func(v): SaveData.set_setting("music_volume", v / 100.0))
	%SfxToggle.set_on_silent(bool(SaveData.setting("sfx")))
	%SfxToggle.toggled.connect(func(on): SaveData.set_setting("sfx", on); if on: AudioManager.play_sfx("match"))
	%HapticsToggle.set_on_silent(bool(SaveData.setting("haptics")))
	%HapticsToggle.toggled.connect(func(on): SaveData.set_setting("haptics", on); if on: AudioManager.vibrate(40))
	%HapticsRow.visible = OS.has_feature("mobile") or OS.has_feature("editor") or true
	_build_vibe_row()
	%ReplayBtn.pressed.connect(_replay_tutorials)
	%ResetBtn.pressed.connect(func(): AudioManager.click(); _show(%Confirm, true))
	%ConfirmCancel.pressed.connect(func(): AudioManager.back(); _show(%Confirm, false); if _confirm_mode == "delete": _delete_cancel())
	%ConfirmReset.pressed.connect(_reset)
	%PrivacyBtn.pressed.connect(func(): _info("PRIVACY", PRIVACY_TEXT + (ADS_TEXT if Ads.is_real() else "")))
	%SupportBtn.pressed.connect(func(): _info("SUPPORT", SUPPORT_TEXT))
	%CreditsBtn.pressed.connect(func(): _info("CREDITS", CREDITS_TEXT))
	%InfoClose.pressed.connect(func(): AudioManager.back(); _show(%Info, false))
	%VersionLabel.text = "Ninja Knife Dodge  v%s" % Globals.VERSION
	%Confirm.visible = false
	%Info.visible = false
	%Toast.modulate.a = 0.0
	_build_account()

func _back() -> void:
	AudioManager.back()
	SaveData.set_player_name(%NameEdit.text)
	Globals.go("start")

func _on_name_changed(t: String) -> void:
	var up := t.to_upper()
	var clean := ""
	for ch in up:
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "_":
			clean += ch
	if clean != t:
		var caret: int = %NameEdit.caret_column
		%NameEdit.text = clean
		%NameEdit.caret_column = mini(caret, clean.length())

func _replay_tutorials() -> void:
	AudioManager.click()
	SaveData.reset_tutorials()
	_toast("ALL TUTORIALS WILL PLAY AGAIN NEXT TIME YOU START EACH GAME")

func _reset() -> void:
	if _confirm_mode == "delete":
		_delete_account()
		return
	AudioManager.play_sfx("level_fail")
	SaveData.reset_all()
	_show(%Confirm, false)
	_toast("PROGRESS RESET. THE VOID IS EMPTY AGAIN.")

# ---------------------------------------------------------------- music vibe

var _vibe_tabs := {}
var _vibe_desc: Label

## Picks what the background music feels like. Every bed is loudness-matched, so tapping
## one crossfades a preview in straight away without the level jumping.
func _build_vibe_row() -> void:
	var left: Control = %MusicRow.get_parent()
	var panel := PanelContainer.new()
	panel.name = "VibeRow"
	panel.add_theme_stylebox_override("panel", %MusicRow.get_theme_stylebox("panel"))
	# Same shape as the rows around it - label on the left, control on the right - so the
	# column stays short enough for a notched phone's safe-area inset.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)
	var t := VBoxContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_theme_constant_override("separation", 2)
	h.add_child(t)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.text = "Music vibe"
	t.add_child(title)
	_vibe_desc = Label.new()
	_vibe_desc.theme_type_variation = &"MutedLabel"
	_vibe_desc.add_theme_font_size_override("font_size", 18)
	_vibe_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_child(_vibe_desc)
	var make := Button.new()
	make.add_theme_font_size_override("font_size", 14)
	make.custom_minimum_size = Vector2(150, 34)
	make.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	make.add_theme_color_override("font_color", Globals.GREEN)
	make.text = "MAKE YOUR OWN"
	make.pressed.connect(func(): AudioManager.click(); Globals.go("loops_play"))
	t.add_child(make)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for id in AudioManager.VIBE_ORDER:
		var vibe_id := str(id)
		var b := Button.new()
		b.theme_type_variation = &"TabButton"
		b.toggle_mode = true
		b.text = str(AudioManager.VIBES[vibe_id]["label"])
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(86, 44)
		b.pressed.connect(_pick_vibe.bind(vibe_id))
		tabs.add_child(b)
		_vibe_tabs[vibe_id] = b
	h.add_child(tabs)
	left.add_child(panel)
	left.move_child(panel, %MusicRow.get_index() + 1)
	_show_vibe(AudioManager.current_vibe())

func _pick_vibe(id: String) -> void:
	AudioManager.click()
	SaveData.set_setting("music_vibe", id)
	_show_vibe(id)

func _show_vibe(id: String) -> void:
	for k in _vibe_tabs.keys():
		_vibe_tabs[k].set_pressed_no_signal(k == id)
		_vibe_tabs[k].add_theme_color_override("font_pressed_color", Globals.CYAN)
	_vibe_desc.text = str(AudioManager.VIBES[id]["desc"])

# ---------------------------------------------------------------- account

var _confirm_mode := "reset"
var _account_label: Label
var _sign_out_btn: Button
var _delete_btn: Button

## Who is signed in (Sign in with Apple through Supabase), with sign-out and
## the account deletion App Review requires. Guests see a way to sign in.
func _build_account() -> void:
	var danger: Control = %ResetBtn.get_parent().get_parent()
	var right: Control = danger.get_parent()
	var panel := PanelContainer.new()
	panel.name = "Account"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var caps := Label.new()
	caps.theme_type_variation = &"CapsLabel"
	caps.add_theme_font_size_override("font_size", 14)
	caps.add_theme_color_override("font_color", Globals.CYAN)
	caps.text = "ACCOUNT"
	v.add_child(caps)
	_account_label = Label.new()
	_account_label.theme_type_variation = &"MutedLabel"
	_account_label.add_theme_font_size_override("font_size", 17)
	_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_account_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_sign_out_btn = Button.new()
	_sign_out_btn.add_theme_font_size_override("font_size", 17)
	_sign_out_btn.custom_minimum_size = Vector2(0, 44)
	_sign_out_btn.pressed.connect(_on_sign_out)
	row.add_child(_sign_out_btn)
	_delete_btn = Button.new()
	_delete_btn.theme_type_variation = &"DangerButton"
	_delete_btn.add_theme_font_size_override("font_size", 17)
	_delete_btn.custom_minimum_size = Vector2(0, 44)
	_delete_btn.text = "DELETE ACCOUNT"
	_delete_btn.pressed.connect(_on_delete_account)
	row.add_child(_delete_btn)
	v.add_child(row)
	right.add_child(panel)
	right.move_child(panel, danger.get_index())
	panel.visible = Backend.is_configured()
	_refresh_account()

func _refresh_account() -> void:
	if _account_label == null:
		return
	if Backend.has_session():
		_account_label.text = "Signed in with Apple as %s. Seals, chapters and scores are backed up after every round." % Backend.account_label()
		_sign_out_btn.text = "SIGN OUT"
		_delete_btn.visible = true
	else:
		_account_label.text = "Playing on this device only. Sign in with Apple to back up your seals and scores."
		_sign_out_btn.text = "SIGN IN"
		_delete_btn.visible = false

func _on_sign_out() -> void:
	AudioManager.click()
	if Backend.has_session():
		await Backend.sign_out()
		_refresh_account()
		_toast("SIGNED OUT. YOUR PROGRESS STAYS ON THIS DEVICE.")
	else:
		Globals.go("signin", {"from": "settings"})

func _on_delete_account() -> void:
	AudioManager.click()
	_confirm_mode = "delete"
	%Confirm.get_node("Center/Card/V/T").text = "DELETE YOUR ACCOUNT?"
	%Confirm.get_node("Center/Card/V/S").text = "Your account and its cloud backup are erased for good. Progress on this device stays until you reset it, and the game keeps working without an account."
	%ConfirmReset.text = "DELETE"
	_show(%Confirm, true)

func _delete_cancel() -> void:
	_confirm_mode = "reset"
	%Confirm.get_node("Center/Card/V/T").text = "RESET EVERYTHING?"
	%Confirm.get_node("Center/Card/V/S").text = "Both leaderboards, all level stars and every stat will be erased. This cannot be undone."
	%ConfirmReset.text = "RESET"

func _delete_account() -> void:
	_show(%Confirm, false)
	_confirm_mode = "reset"
	%Confirm.get_node("Center/Card/V/T").text = "RESET EVERYTHING?"
	%Confirm.get_node("Center/Card/V/S").text = "Both leaderboards, all level stars and every stat will be erased. This cannot be undone."
	%ConfirmReset.text = "RESET"
	var ok: bool = await Backend.delete_account()
	_refresh_account()
	if ok:
		AudioManager.play_sfx("level_fail")
		_toast("ACCOUNT DELETED. YOU ARE PLAYING ON THIS DEVICE ONLY.")
	else:
		_toast("COULD NOT DELETE THE ACCOUNT: %s" % Backend.last_error.to_upper())

func _info(title: String, body: String) -> void:
	AudioManager.click()
	%InfoTitle.text = title
	%InfoBody.text = body
	_show(%Info, true)

func _show(overlay: Control, open: bool) -> void:
	overlay.visible = open
	if open:
		var card: Control = overlay.get_node("Center/Card")
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.92, 0.92)
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _toast(text: String) -> void:
	%Toast.text = text
	var t := create_tween()
	t.tween_property(%Toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.4)
	t.tween_property(%Toast, "modulate:a", 0.0, 0.4)
