extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _run() -> void:
	for i in range(40):
		await process_frame
	game._on_start()
	for i in range(10):
		await process_frame
	var out := ""
	for t in [0.05, 0.30, 0.55, 0.80, 1.00, 1.20, 1.60, 2.50, 3.10]:
		game.desk_phone_t = t
		game._update_desk_props(0.0)
		out += "t=%.2f:%s  " % [t, ("亮" if game.desk_phone_mat.emission_energy_multiplier > 1.0 else "灭")]
	print("[PHONE] 三短一长节奏 = ", out)
	quit()