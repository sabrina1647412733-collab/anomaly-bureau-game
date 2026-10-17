extends SceneTree
## 电脑/广播台/第三人称转身回归
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _run() -> void:
	for i in range(30):
		await process_frame
	game._on_start()
	for i in range(10):
		await process_frame
	game._act("pc")
	await process_frame
	var pc_ok: bool = game.state == "minigame" and game.pc_overlay.visible
	var buttons: Array = game.pc_overlay.get("buttons")
	var file: Label = game.pc_overlay.get("file_view")
	var file_ok: bool = file != null and file.text.contains("邵国平") and file.text.contains("19")
	print("[FEAT] pc state=", game.state, " visible=", game.pc_overlay.visible, " buttons=", buttons.size(), " file=", file_ok)
	game._close_pc()
	await process_frame
	var close_ok: bool = game.state == "play" and not game.pc_overlay.visible
	game.round = 1
	game._act("studio_dial"); game._act("studio_dial"); game._act("studio_dial")
	await process_frame
	var tape_ok := false
	for it in game.items:
		if String(it["def"]["id"]) == "tape":
			tape_ok = bool(it["got"])
	game._act("studio_onair")
	var onair_ok: bool = game.studio_onair_on
	game.player.cam_mode = 1
	game.player.velocity = Vector3(1, 0, 0)
	var before: float = game.player.body.rotation.y
	game.player._update_body(0.1, 1.0)
	var after: float = game.player.body.rotation.y
	var turn_ok := absf(after - before) > 0.01
	print("[FEAT] close=", close_ok, " tape=", tape_ok, " onair=", onair_ok, " turn=", before, "->", after)
	game.round = 3
	game.handle = false
	game.late = true
	game._resolve_final()
	await process_frame
	var c_ok: bool = game.shown_end == "C" and game.hud_end_title.text.contains("结局 C")
	print("[FEAT] ending_c=", c_ok)
	var pass_ok: bool = pc_ok and file_ok and close_ok and tape_ok and onair_ok and turn_ok and c_ok
	print("[FEAT] PASS=", pass_ok)
	quit(0 if pass_ok else 1)