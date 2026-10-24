extends SceneTree
var game
func _initialize()->void:call_deferred("run")
func run()->void:
	create_timer(60).timeout.connect(func():push_error("review quit timeout");quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._start_prologue(false);game._hide_menu();game._clear_sub()
	game.field_kit.phone_owned=true;game.bag_add("phone","手机");game.field_kit.sync_world()
	var expected:Dictionary=game.exit_save.snapshot()
	var file:=FileAccess.open(preload("res://scripts/storage_paths.gd").file("quit_expected.json"),FileAccess.WRITE);file.store_string(JSON.stringify(expected));file.close()
	var dev=game.developer_review;dev.open_login();dev.account.text="sabrina";dev.password.text=OS.get_environment("DEV_REVIEW_TEST_PASSWORD");dev.submit_login()
	while dev.busy:await process_frame
	if not dev.active:push_error("quit review login failed");quit(2);return
	await dev.visit("c2_17")
	# This runner always has a dedicated F-drive --data-dir. Enable the actual
	# quit save branch there, never on a player's profile.
	game.exit_save.test_mode=false
	game.exit_save.request_quit()
