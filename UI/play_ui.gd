extends CanvasLayer

var score = 0

func increment_score():
	score = score + 1
	%Score.text = "Score: " + str(score)
