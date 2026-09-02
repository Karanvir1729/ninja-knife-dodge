extends CanvasLayer
## Knife Dodge results: score, record/rank chips, run stats, and what next.

var score := 0
var wave := 0
var elapsed := 0.0
var near := 0
var dodged := 0

func init(params: Dictionary) -> void:
	score = int(params.get("score", 0))
	wave = int(params.get("wave", 0))
	elapsed = float(params.get("time", 0.0))
	near = int(params.get("near", 0))
	dodged = int(params.get("dodged", 0))

func _ready() -> void:
	var bg := get_tree().get_first_node_in_group("background")
	if bg: bg.set_mood("knife")
	Globals.apply_safe_margins(%Root, 24)
	var result: Dictionary = SaveData.record_knife_run(score, wave, elapsed, near)
	%ScoreVal.text = str(score)
	%DodgedVal.text = str(dodged)
	%WavesVal.text = str(wave)
	%NearVal.text = str(near)
	%TimeVal.text = Globals.format_time(elapsed)
	%RecordChip.visible = bool(result.new_record) and score > 0
	var rank: int = int(result.rank)
	%RankChip.visible = rank > 0
	%RankLabel.text = "#%d ON THE BOARD" % rank
	%BestLine.text = "BEST %d" % int(SaveData.knife_stats().best)
	%BestLine.visible = not %RecordChip.visible
	%Title.text = _title_for(score)
	%PlayAgain.pressed.connect(func(): AudioManager.click(); Globals.go("play"))
	%Board.pressed.connect(func(): AudioManager.click(); Globals.go("leaderboard", {"tab": "knife"}))
	%Menu.pressed.connect(func(): AudioManager.back(); Globals.go("start"))
	_layout_daggers()
	get_viewport().size_changed.connect(_layout_daggers)
	_animate(result)
	var quips := []
	if bool(result.new_record) and score > 0:
		quips = ["NEW RECORD! Did you see that? I saw that!", "You dodged like a comet! New best!"]
	elif score >= 50:
		quips = ["So close to legend status. One more run!", "The void blinked first. Again!"]
	else:
		quips = ["That dagger had your name on it!", "Tap under the star to launch it up. You've got this!", "Near misses score extra. Live a little!"]
	GuideCameo.create(self, "pip", quips, "right")

func _title_for(s: int) -> String:
	if s >= 150: return "BLADE DANCER"
	if s >= 100: return "UNTOUCHABLE"
	if s >= 50: return "YOU FOUGHT WELL"
	if s >= 20: return "A WORTHY RUN"
	return "THE VOID CLAIMS YOU"

func _layout_daggers() -> void:
	var r := Globals.view_rect()
	$DaggerL.position = r.position + Vector2(90, 90)
	$DaggerR.position = Vector2(r.end.x - 90, r.position.y + 90)

func _animate(result: Dictionary) -> void:
	%Card.pivot_offset = %Card.size * 0.5
	%Card.scale = Vector2(0.9, 0.9)
	%Card.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(%Card, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(%Card, "modulate:a", 1.0, 0.25)
	# count the score up
	var counter := create_tween()
	counter.tween_method(func(v): %ScoreVal.text = str(int(v)), 0.0, float(score), minf(1.2, 0.3 + score * 0.01))
	if bool(result.new_record) and score > 0:
		counter.tween_callback(func(): AudioManager.play_sfx("record"); AudioManager.vibrate(40))
