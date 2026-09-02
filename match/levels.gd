class_name MatchLevels
extends RefCounted
## Level parameters for Shuriken Match. Levels are formula-driven so the game
## never runs out; the curve was tuned with the greedy bot in tests/.

const LEVEL_COUNT := 50

static func params(level: int) -> Dictionary:
	var n := maxi(1, level)
	var colors := 5 if n <= 4 else 6
	var moves := 22 - int((n - 1) / 4)
	moves = maxi(14, moves)
	# Required points per move rise linearly; the greedy bot in tests/ averages
	# roughly 450-550 per move, a relaxed human about 300.
	var per_move := 90 + 9 * n
	var target := int(round(per_move * moves / 50.0) * 50)
	return {
		"level": n,
		"colors": colors,
		"moves": moves,
		"target": target,
		"stars": [target, int(round(target * 1.3 / 50.0) * 50), int(round(target * 1.6 / 50.0) * 50)],
		"seed": 1000 + n * 7919,
	}

static func stars_for(level: int, score: int) -> int:
	var p := params(level)
	var s := 0
	for t in p.stars:
		if score >= int(t):
			s += 1
	return s
