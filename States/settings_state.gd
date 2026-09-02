extends CanvasLayer
## Settings: ninja name, audio, haptics, tutorials, about, and a guarded reset.

const PRIVACY_TEXT := """[b]Ninja Knife Dodge does not collect, store, or share any personal data.[/b]

• The game runs entirely offline and makes no network connections.
• There are no accounts, no sign-in, no ads, and no third-party analytics or tracking SDKs.
• Your scores, level progress, settings and tutorial flags are saved only on this device and never leave it. Deleting the app deletes them.

Because no data is collected, there is nothing to access, correct, delete, or opt out of.

Questions: mehar.khanna@uwaterloo.ca"""

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
• Mysterious; Music Box Game Over 2
• All other effects and the Shuriken Match ambience are synthesised in-house"""

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
	%ReplayBtn.pressed.connect(_replay_tutorials)
	%ResetBtn.pressed.connect(func(): AudioManager.click(); _show(%Confirm, true))
	%ConfirmCancel.pressed.connect(func(): AudioManager.back(); _show(%Confirm, false))
	%ConfirmReset.pressed.connect(_reset)
	%PrivacyBtn.pressed.connect(func(): _info("PRIVACY", PRIVACY_TEXT))
	%SupportBtn.pressed.connect(func(): _info("SUPPORT", SUPPORT_TEXT))
	%CreditsBtn.pressed.connect(func(): _info("CREDITS", CREDITS_TEXT))
	%InfoClose.pressed.connect(func(): AudioManager.back(); _show(%Info, false))
	%VersionLabel.text = "Ninja Knife Dodge  v%s" % Globals.VERSION
	%Confirm.visible = false
	%Info.visible = false
	%Toast.modulate.a = 0.0

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
	AudioManager.play_sfx("level_fail")
	SaveData.reset_all()
	_show(%Confirm, false)
	_toast("PROGRESS RESET. THE VOID IS EMPTY AGAIN.")

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
