extends Node2D
class_name DrawTarget
## One Quick Draw target: a tinted shuriken inside a ring that closes over its
## lifetime, or a red decoy dagger that drifts across and fades. The owning
## state drives it through tick(delta) so it freezes with the game (pause,
## life offers, end of round) instead of running its own _process.

signal expired(target: DrawTarget)
signal vanished(target: DrawTarget)

const SHURIKEN_PX := 64.0          # on-screen shuriken size (texture is 192 px)
const RING_IMAGE_PX := 240.0       # ring diameter inside the 256 px texture
const RING_START := 2.2            # ring size relative to the shuriken at spawn
const RING_END := 1.0              # ... and when the target expires
const RADIUS := SHURIKEN_PX * 0.5
const TAP_FACTOR := 1.6

var is_decoy := false
var lifetime := 1.6
var color: Color = Globals.CYAN
var drift := Vector2.ZERO          # decoy velocity in px/s
var spin := 0.0                    # shuriken spin in rad/s
var hold := false                  # tutorial: the ring stops closing and waits for a tap
var age := 0.0
var alive := true
var _fading := false
var _hold_time := 0.0

func _ready() -> void:
	$Ring.visible = not is_decoy
	$Shuriken.visible = not is_decoy
	$Glow.visible = not is_decoy
	$Dagger.visible = is_decoy
	if is_decoy:
		$Dagger.rotation = drift.angle() if drift != Vector2.ZERO else 0.0
		modulate.a = 0.0
		scale = Vector2(0.7, 0.7)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(self, "modulate:a", 1.0, 0.18)
		t.tween_property(self, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT)
	else:
		$Shuriken.modulate = color.lightened(0.15)
		$Glow.modulate = Color(color, 0.38)
		$Shuriken.rotation = randf() * TAU
		scale = Vector2.ZERO
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_apply_ring(0.0)

func tick(delta: float) -> void:
	if not alive:
		return
	age += delta
	if is_decoy:
		position += drift * delta
		if age >= lifetime - 0.25 and not _fading:
			_fading = true
			create_tween().tween_property(self, "modulate:a", 0.0, 0.25)
		if age >= lifetime:
			alive = false
			vanished.emit(self)
			queue_free()
		return
	$Shuriken.rotation += spin * delta
	var f := clampf(age / lifetime, 0.0, 1.0)
	if age >= lifetime and hold:
		# Tutorial target: sit at the closed ring and pulse gently until tapped.
		_hold_time += delta
		f = 1.0 - 0.06 * (0.5 + 0.5 * sin(_hold_time * 5.0))
	_apply_ring(f)
	if age >= lifetime and not hold:
		alive = false
		expired.emit(self)

func _apply_ring(f: float) -> void:
	var k := lerpf(RING_START, RING_END, f)
	$Ring.scale = Vector2.ONE * (SHURIKEN_PX * k / RING_IMAGE_PX)
	# The ring warms towards white as it closes so the deadline reads at a glance.
	$Ring.modulate = Color(color.lerp(Color.WHITE, f * 0.55), 0.7 + 0.3 * f)

## Distance from the centre within which a tap counts.
func tap_radius() -> float:
	return RADIUS * TAP_FACTOR + (6.0 if is_decoy else 0.0)

## Hit: flash out bigger and brighter.
func pop() -> void:
	alive = false
	z_index = 3
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.55, 1.55), 0.14).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.14)
	t.chain().tween_callback(queue_free)

## Missed: shrink away tinted red.
func miss_out() -> void:
	alive = false
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.15, 0.15), 0.24).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate", Color(Globals.RED, 0.0), 0.24)
	t.chain().tween_callback(queue_free)

## Quietly leave (decoy timed out, round ended, life offer opened).
func fade_out() -> void:
	alive = false
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_property(self, "scale", scale * 0.7, 0.2)
	t.chain().tween_callback(queue_free)
