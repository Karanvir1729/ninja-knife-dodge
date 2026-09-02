extends Node2D
class_name GuideCameo
## A small guide popping into a corner of a results screen with a one-liner.
## Tapping the guide gets another line.

const BUBBLE := preload("res://UI/speech_bubble.tscn")

var who := "pip"
var lines: Array = []
var mascot: Mascot
var bubble: SpeechBubble

## Add to any CanvasLayer state. `corner` is "left" or "right".
static func create(parent: Node, p_who: String, p_lines: Array, corner: String = "left") -> GuideCameo:
	var c := GuideCameo.new()
	c.who = p_who
	c.lines = p_lines
	parent.add_child(c)
	c.call_deferred("_show", corner)
	return c

func _show(corner: String) -> void:
	var r := Globals.view_rect()
	var s := Globals.safe_insets()
	mascot = Mascot.new()
	mascot.character = who
	mascot.base_scale = 0.5
	add_child(mascot)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(layer)
	bubble = BUBBLE.instantiate()
	bubble.max_width = 290.0
	layer.add_child(bubble)
	bubble.get_node("%Hint").visible = false
	var x := r.position.x + 110.0 + float(s.left) if corner == "left" else r.end.x - 110.0 - float(s.right)
	var y := r.end.y - 40.0 - float(s.bottom) - (118.0 if who == "sensei" else 92.0) * mascot.base_scale
	mascot.enter(Vector2(x, r.end.y + 200.0), Vector2(x, y), 0.4)
	mascot.tapped.connect(_say)
	bubble.typed_char.connect(func(): mascot.blip())
	bubble.finished_typing.connect(func(): mascot.set_talking(false))
	await get_tree().create_timer(0.9).timeout
	_say()

func _say() -> void:
	if lines.is_empty() or not is_instance_valid(mascot):
		return
	var text := str(lines[randi() % lines.size()])
	mascot.set_mood("excited" if who == "pip" else "happy")
	mascot.set_talking(true)
	bubble.show_line(mascot.display_name, text, mascot.accent, mascot.head_global())
	await get_tree().process_frame
	var r := Globals.view_rect()
	var head := mascot.head_global()
	var pos := head + Vector2(-bubble.size.x * 0.5, -bubble.size.y - 26.0)
	pos.x = clampf(pos.x, r.position.x + 12.0, r.end.x - bubble.size.x - 12.0)
	pos.y = maxf(pos.y, r.position.y + 12.0)
	bubble.global_position = pos
	bubble.anchor = head
	bubble.queue_redraw()
