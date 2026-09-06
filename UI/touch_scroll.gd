extends ScrollContainer
class_name TouchScroll
## Finger-drag scrolling that works on iOS regardless of what the children do
## with input. ScrollContainer's built-in drag did nothing on device (the story
## journal sat still under a finger; reproduced on an iOS 18 simulator), so
## this listens at the viewport level instead: a touch that starts inside the
## container and moves past a small deadzone scrolls it, with a short fling on
## release. Mouse wheel and the scrollbars keep working through the built-in
## path, and the emulated mouse motion iOS generates for a touch is swallowed
## while a drag is live so the two paths can never both move the list.

const DEADZONE := 8.0
const FLING_DECAY := 5.0
const FLING_STOP := 24.0

var _touch_index := -1
var _dragging := false
var _accum := Vector2.ZERO
var _velocity := Vector2.ZERO
var _last_msec := 0

func _ready() -> void:
	set_process(false)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_dragging = false
				_accum = Vector2.ZERO
				_velocity = Vector2.ZERO
				_last_msec = Time.get_ticks_msec()
				set_process(false)
		elif event.index == _touch_index:
			_touch_index = -1
			if _dragging:
				_dragging = false
				if _velocity.length() > FLING_STOP:
					set_process(true)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var rel: Vector2 = event.relative
		if not _dragging:
			_accum += rel
			if _accum.length() < DEADZONE:
				return
			_dragging = true
			rel = _accum
		_scroll_by(rel)
		var now := Time.get_ticks_msec()
		var dt := maxf(0.001, float(now - _last_msec) / 1000.0)
		_last_msec = now
		_velocity = _velocity.lerp(rel / dt, 0.5)
		get_viewport().set_input_as_handled()
	elif _dragging and event is InputEventMouseMotion and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()

func _scroll_by(rel: Vector2) -> void:
	if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		get_v_scroll_bar().value -= rel.y
	if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		get_h_scroll_bar().value -= rel.x

func _process(delta: float) -> void:
	_scroll_by(_velocity * delta)
	_velocity *= exp(-FLING_DECAY * delta)
	if _velocity.length() < FLING_STOP:
		set_process(false)
