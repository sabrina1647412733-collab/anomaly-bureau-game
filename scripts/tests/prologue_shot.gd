extends SceneTree
var game
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_预览/look/"))
	img.save_png("res://_预览/look/" + name + ".png")
	print("[SHOT] ", name, " ", img.get_width(), "x", img.get_height())
func _run() -> void:
	for i in range(30): await process_frame
	game._on_new_game()
	for i in range(20): await process_frame
	await _shot("prologue_room")
	game._prologue_act("phone")
	game._prologue_act("box")
	game._prologue_act("door")
	for i in range(10): await process_frame
	await _shot("prologue_letter")
	game._close_letter()
	game._prologue_act("phone")
	game._prologue_act("door")
	await create_timer(1.2).timeout
	for i in range(10): await process_frame
	await _shot("prologue_store")
	game._prologue_act("store_door")
	await create_timer(1.2).timeout
	for i in range(10): await process_frame
	await _shot("prologue_entrance")
	quit()
