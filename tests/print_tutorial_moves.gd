extends SceneTree
func _init() -> void:
	var layouts := {"step_match3": TutorialLayouts.step_match3(), "step_line": TutorialLayouts.step_line()}
	for name in layouts.keys():
		var d: Dictionary = layouts[name]
		var m := BoardModel.new(8, 6, 5, 1)
		m.load_layout(d.layout)
		print(name, " intended ", d.from, "->", d.to)
		print(m.to_string_grid())
		for mv in m.find_valid_moves():
			print("  move ", mv[0], " <-> ", mv[1], "  score ", m.score_move(mv[0], mv[1]))
	quit()
