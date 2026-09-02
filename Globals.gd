extends Node
## Shared constants, palette and viewport helpers.
## The viewport stretches with aspect "expand", so the visible area is at least
## BASE_WIDTH x BASE_HEIGHT and grows on wider (iPhone) or taller (iPad) screens.
## Always read view_rect() instead of assuming the base size.

const BASE_WIDTH := 1408
const BASE_HEIGHT := 792
# Kept for the original scripts that referenced them.
const WINDOW_WIDTH := 1408
const WINDOW_HEIGHT := 792

const VERSION := "2.0"

# Palette (matches the design canvas)
const BG0 := Color("07080d")
const BG1 := Color("0e0f16")
const BG2 := Color("161826")
const LINE := Color("262a3d")
const LINE2 := Color("343a55")
const TEXT := Color("ebeef8")
const MUTED := Color("8b92ab")
const DIM := Color("5a6180")
const CYAN := Color("56f0ff")
const MAGENTA := Color("ff4fd8")
const GOLD := Color("ffd84d")
const GREEN := Color("4dffa6")
const VIOLET := Color("9b6bff")
const ORANGE := Color("ff8a3d")
const RED := Color("ff3b5c")

## Tile colours for Shuriken Match, in index order.
const GEM_COLORS: Array[Color] = [
	Color("56f0ff"), Color("ff4fd8"), Color("ffd84d"),
	Color("4dffa6"), Color("9b6bff"), Color("ff8a3d"),
]

## Visible viewport rectangle in canvas units (already accounts for aspect expand).
func view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(0, 0, BASE_WIDTH, BASE_HEIGHT)
	return vp.get_visible_rect()

func view_size() -> Vector2:
	return view_rect().size

func view_center() -> Vector2:
	var r := view_rect()
	return r.position + r.size * 0.5

## Safe-area insets (notch, home indicator) converted to canvas units.
## Returns {left, top, right, bottom}. All zero on desktop.
func safe_insets() -> Dictionary:
	var insets := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return insets
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return insets
	var vs := view_size()
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	insets.left = float(safe.position.x) * sx
	insets.top = float(safe.position.y) * sy
	insets.right = float(win.x - (safe.position.x + safe.size.x)) * sx
	insets.bottom = float(win.y - (safe.position.y + safe.size.y)) * sy
	return insets

## Apply safe-area insets on top of base margins to a MarginContainer.
func apply_safe_margins(mc: MarginContainer, base: int = 32) -> void:
	var s := safe_insets()
	mc.add_theme_constant_override("margin_left", base + int(s.left))
	mc.add_theme_constant_override("margin_top", base + int(s.top))
	mc.add_theme_constant_override("margin_right", base + int(s.right))
	mc.add_theme_constant_override("margin_bottom", base + int(s.bottom))

## Change the active screen through the state machine.
func go(state: String, params: Dictionary = {}) -> void:
	get_tree().call_group("currentState", "change", state, params)

static func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

static func pad_score(n: int, width: int = 6) -> String:
	return str(n).pad_zeros(width)
