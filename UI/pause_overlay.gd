extends CanvasLayer
## Shared pause menu for both games. Works while the tree is paused.

signal resume
signal restart
signal menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	%ResumeBtn.pressed.connect(func(): resume.emit())
	%RestartBtn.pressed.connect(func(): AudioManager.click(); restart.emit())
	%MenuBtn.pressed.connect(func(): AudioManager.back(); menu.emit())

func set_title(title: String, subtitle: String, accent: Color = Globals.CYAN) -> void:
	%Title.text = title
	%Subtitle.text = subtitle
	var mind := accent == Globals.MAGENTA or accent == Globals.VIOLET
	%ResumeBtn.theme_type_variation = &"MagentaButton" if mind else &"PrimaryButton"

func set_open(open: bool) -> void:
	visible = open
	if open:
		%Card.scale = Vector2(0.92, 0.92)
		%Card.pivot_offset = %Card.size * 0.5
		var t := create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(%Card, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
