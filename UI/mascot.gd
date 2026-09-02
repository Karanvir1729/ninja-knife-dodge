extends Node2D
class_name Mascot
## An animated guide character built from the layered parts in graphics/gen/mascot:
## "sensei" (Sensei Kuro, the old master) or "pip" (the star spirit).
## Idle bob, blinking, mouth flaps while talking, pointing, hopping, entrances.

signal tapped

@export var character := "sensei"
@export var base_scale := 0.7

const DIR := "res://graphics/gen/mascot/"

var mood := "neutral"
var talking := false
var display_name := "SENSEI KURO"
var accent: Color = Color("9b6bff")

var _t := 0.0
var _blink_in := 2.5
var _blink_left := 0.0
var _mouth_timer := 0.0
var _pointing := false
var _face_right := true
var _body: Node2D
var _eyes: Sprite2D
var _mouth: Sprite2D
var _brows: Sprite2D
var _tail_pivot: Node2D
var _arm_pivot: Node2D
var _arm: Sprite2D
var _sparkle: Sprite2D
var _tex := {}
var _hop_tween: Tween
var _lean := 0.0

func _ready() -> void:
	scale = Vector2(base_scale, base_scale)
	if character == "pip":
		display_name = "PIP"
		accent = Globals.GOLD
	var shadow := Sprite2D.new()
	shadow.texture = _load("mascot_shadow")
	shadow.position = Vector2(0, 118 if character == "sensei" else 88)
	shadow.modulate.a = 0.6
	add_child(shadow)
	_body = Node2D.new()
	add_child(_body)
	if character == "sensei":
		_tail_pivot = Node2D.new()
		_tail_pivot.position = Vector2(-60, -58)
		var tails := _sprite("sensei_tails")
		tails.position = Vector2(60, 58)
		_tail_pivot.add_child(tails)
		_body.add_child(_tail_pivot)
		_body.add_child(_sprite("sensei_body"))
		_arm_pivot = Node2D.new()
		_arm_pivot.position = Vector2(54, 64)
		_arm = _sprite("sensei_arm")
		_arm.position = Vector2(-54, -64)
		_arm_pivot.add_child(_arm)
		_arm_pivot.visible = false
		_body.add_child(_arm_pivot)
		_brows = _sprite("sensei_brows")
		_body.add_child(_brows)
		_eyes = _sprite("sensei_eyes_open")
		_body.add_child(_eyes)
		_mouth = _sprite("sensei_mouth_closed")
		_body.add_child(_mouth)
	else:
		_body.add_child(_sprite("pip_body"))
		_eyes = _sprite("pip_eyes_open")
		_body.add_child(_eyes)
		_mouth = _sprite("pip_mouth_closed")
		_body.add_child(_mouth)
		_sparkle = _sprite("pip_sparkle")
		_sparkle.visible = false
		_body.add_child(_sparkle)
	var area := Area2D.new()
	area.collision_layer = 128
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 118.0 if character == "sensei" else 100.0
	shape.shape = circle
	area.add_child(shape)
	area.input_event.connect(_on_area_input)
	add_child(area)

func _load(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]

func _sprite(name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _load(name)
	return s

func _on_area_input(_vp: Node, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()

## Global position of the head, for anchoring speech bubbles.
func head_global() -> Vector2:
	return to_global(Vector2(0, -168 if character == "sensei" else -118))

func set_facing(right: bool) -> void:
	_face_right = right
	scale.x = base_scale * (1.0 if right else -1.0)

func set_mood(m: String) -> void:
	mood = m
	_apply_eyes()
	if _brows:
		var t := create_tween()
		t.tween_property(_brows, "rotation", 0.1 if m == "think" else (-0.06 if m == "excited" else 0.0), 0.2)
		t.parallel().tween_property(_brows, "position:y", -6.0 if m == "think" else 0.0, 0.2)
	if _sparkle:
		_sparkle.visible = m == "excited"
	if m == "excited":
		hop()

func _apply_eyes() -> void:
	if _blink_left > 0:
		_eyes.texture = _load(character + "_eyes_closed")
	elif mood in ["happy", "excited"]:
		_eyes.texture = _load(character + "_eyes_happy")
	else:
		_eyes.texture = _load(character + "_eyes_open")

func set_talking(on: bool) -> void:
	talking = on
	if not on:
		_mouth.texture = _load(character + "_mouth_closed")

## Play one voice blip (called by the speech bubble as characters appear).
func blip() -> void:
	var idx := randi_range(1, 5)
	AudioManager.play_sfx("voice_%s_%d" % [character, idx], randf_range(0.94, 1.06), -9.0)

func _process(delta: float) -> void:
	_t += delta
	# idle bob and lean
	var bob := sin(_t * (2.1 if character == "sensei" else 2.8)) * (4.0 if character == "sensei" else 6.0)
	_body.position.y = bob
	if character == "pip":
		_body.rotation = sin(_t * 1.6) * 0.05 + _lean
	else:
		_body.rotation = _lean
	if _tail_pivot:
		_tail_pivot.rotation = sin(_t * 3.1) * 0.12 + (0.25 if _pointing else 0.0)
	# blinking
	if _blink_left > 0:
		_blink_left -= delta
		if _blink_left <= 0:
			_apply_eyes()
	else:
		_blink_in -= delta
		if _blink_in <= 0:
			_blink_in = randf_range(2.2, 5.0)
			_blink_left = 0.13
			_apply_eyes()
	# mouth flaps
	if talking:
		_mouth_timer -= delta
		if _mouth_timer <= 0:
			_mouth_timer = randf_range(0.06, 0.12)
			var frames := ["open", "wide", "closed", "open"]
			_mouth.texture = _load("%s_mouth_%s" % [character, frames[randi() % frames.size()]])
	if _sparkle and _sparkle.visible:
		_sparkle.rotation += delta * 2.0
		_sparkle.scale = Vector2.ONE * (0.9 + 0.15 * sin(_t * 6.0))

## Point the arm (Sensei) or lean (Pip) toward a global position.
func point_at(target: Vector2) -> void:
	_pointing = true
	var to_right := target.x >= global_position.x
	set_facing(to_right)
	if _arm_pivot:
		_arm_pivot.visible = true
		_arm_pivot.look_at(target)
		if not to_right:
			_arm_pivot.rotation = -_arm_pivot.rotation
	_lean = -0.08 if to_right else 0.08
	hop(0.6)

func unpoint() -> void:
	_pointing = false
	_lean = 0.0
	if _arm_pivot:
		_arm_pivot.visible = false

## A quick squash-and-stretch jump.
func hop(strength: float = 1.0) -> void:
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	AudioManager.play_sfx("guide_hop", randf_range(0.95, 1.1), -12.0)
	_hop_tween = create_tween()
	_hop_tween.tween_property(_body, "scale", Vector2(1.12, 0.88), 0.08)
	_hop_tween.tween_property(_body, "scale", Vector2(0.92, 1.12), 0.14)
	_hop_tween.parallel().tween_property(_body, "position:y", -34.0 * strength, 0.14).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_body, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_hop_tween.parallel().tween_property(_body, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)

## Slide in from `from` to `home` with a bounce.
func enter(from: Vector2, home: Vector2, delay: float = 0.0) -> void:
	position = from
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): AudioManager.play_sfx("guide_pop", 1.0, -8.0))
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(self, "position", home, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func(): hop(0.5))
