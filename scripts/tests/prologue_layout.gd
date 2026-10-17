extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(30): await process_frame
	game._on_new_game()
	for i in range(5): await process_frame
	game._show_letter_ui()
	await process_frame
	var l: Label = game.prologue_paper_text
	print("[PL] lines=", l.get_line_count(), " min=", l.get_minimum_size(), " size=", l.size)
	quit()
