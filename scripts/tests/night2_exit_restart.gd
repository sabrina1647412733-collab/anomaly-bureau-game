extends SceneTree
## Run once with --write-exit and again without it, same isolated --data-dir.
const Save=preload("res://scripts/case_save.gd")
const Store=preload("res://scripts/storage_paths.gd")
var game
func _initialize():call_deferred("run")
func run():
	create_timer(80).timeout.connect(func():quit(2))
	if not Store.root_dir().begins_with("F:") or not OS.get_cmdline_user_args().has("--verify"):quit(2);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	if OS.get_cmdline_user_args().has("--write-exit"):
		var fixture:=""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--fixture="):fixture=arg.trim_prefix("--fixture=")
		var data=JSON.parse_string(FileAccess.get_file_as_string(fixture))
		if not data is Dictionary or not Save.restore(game,data):quit(1);return
		game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
		game.exit_save.test_mode=false # Only this explicit F-drive test root; exercise production quit path.
		print("EXIT_TEST writing actual production request_quit")
		game.exit_save.request_quit()
	else:
		game.exit_save.continue_game();await process_frame
		var ok:bool=game.laundry!=null and game.laundry.campaign.night_number()==2 and game.state=="play" and not game.player.physics_frozen
		var f=FileAccess.open(Store.file("restart_result.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"passed":ok,"night":game.laundry.campaign.night_number() if game.laundry!=null else 0,"path":Store.root_dir()}));f.close()
		print("RESTART_TEST ",ok)
		game.queue_free();await process_frame;quit(0 if ok else 1)
