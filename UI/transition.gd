extends CanvasLayer
## Full-screen fade used between states. Lives above everything (layer 100).

const DURATION := 0.22

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Fade.color = Globals.BG0
	$Fade.modulate.a = 1.0
	$Fade.mouse_filter = Control.MOUSE_FILTER_STOP

func snap_clear() -> void:
	$Fade.modulate.a = 0.0
	$Fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out() -> void:
	$Fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property($Fade, "modulate:a", 1.0, DURATION)
	await t.finished

func fade_in() -> void:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property($Fade, "modulate:a", 0.0, DURATION)
	await t.finished
	$Fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
