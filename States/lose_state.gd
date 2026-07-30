extends CanvasLayer

var score = 0

func init(params):
	score = params["score"]
	displayScore()

func displayScore():
	%Score.text = "Score: " + str(score)
	var best = 0
	if FileAccess.file_exists("user://high_score"):
		var f = FileAccess.open("user://high_score", FileAccess.READ)
		best = f.get_32()
		f.close()
	if score > best:
		best = score
		var f = FileAccess.open("user://high_score", FileAccess.WRITE)
		f.store_32(best)
		f.close()
	%Stats.text = "High Score: " + str(best)

func _on_play_again_pressed():
	get_tree().call_group("currentState", "change", "play", {})
