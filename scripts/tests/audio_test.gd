extends SceneTree
## 音频层回归：所有 SFX 流存在，列车循环模式正确，播放调用不报错
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
	var streams := {
		"relay": game.sfx_relay, "chime": game.sfx_chime, "step": game.sfx_step,
		"horn": game.sfx_horn, "brake": game.sfx_brake, "train": game.sfx_train,
	}
	var players := {
		"relay": game.relay_player, "chime": game.chime_player, "step": game.step_player,
		"horn": game.horn_player, "brake": game.brake_player, "train": game.train_player,
	}
	var ok := true
	for k in streams:
		if streams[k] == null: ok = false
		print("[AUDIO] stream ", k, "=", streams[k] != null, " len=", (streams[k].get_length() if streams[k] != null else -1.0))
	for k in players:
		if players[k] == null: ok = false
	var loop_ok: bool = game.sfx_train != null and game.sfx_train.loop_mode == AudioStreamWAV.LOOP_FORWARD
	game.play_relay(1.0)
	game.play_chime(1.0, -9.0)
	game.play_step(false)
	game.play_horn()
	game.play_brake()
	game.play_train()
	await process_frame
	game._on_footstep(true)
	await process_frame
	game.stop_train()
	print("[AUDIO] players_ok=", ok, " train_loop=", loop_ok, " PASS=", ok and loop_ok)
	quit(0 if (ok and loop_ok) else 1)