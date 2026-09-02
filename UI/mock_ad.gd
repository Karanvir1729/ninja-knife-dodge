extends CanvasLayer
## Offline stand-in for a rewarded video: a countdown "test ad" card. Returns
## true from run() when the player waits it out and claims the reward.

const DURATION := 5.0

var _done := false
var _result := false
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Claim.disabled = true
	%Claim.pressed.connect(func(): _result = true; _done = true)
	%Close.pressed.connect(func(): _result = false; _done = true)
	%Card.pivot_offset = %Card.size * 0.5
	%Card.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(%Card, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func run(info: Dictionary) -> bool:
	%Reward.text = "REWARD: " + str(info.get("reward", "")).to_upper()
	%Blurb.text = "This is a stand-in ad. In the App Store build a short video plays here."
	while not _done:
		await get_tree().process_frame
	return _result

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var left := maxf(0.0, DURATION - _elapsed)
	%Ring.value = (_elapsed / DURATION) * 100.0
	%Countdown.text = str(ceili(left)) if left > 0 else "OK"
	if left <= 0 and %Claim.disabled:
		%Claim.disabled = false
		%Countdown.text = "OK"
		AudioManager.play_sfx("star_ding", 1.2, -6.0)
