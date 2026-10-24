extends SceneTree
var game
var dev
var out:="F:/诡异事务局/验收/20261024_开发者巡查/实机图/"
var shots:Array[String]=[]
func _initialize()->void:call_deferred("run")
func shot(name:String)->void:
	for i in range(18):await process_frame
	RenderingServer.force_draw(false,1./60.)
	var result:int=root.get_texture().get_image().save_png(out+name+".png")
	if result!=OK:push_error("developer screenshot failed");quit(2)
	shots.append(name)
func wait_loaded()->void:
	for i in range(600):
		await process_frame
		if not dev.busy:return
func run()->void:
	create_timer(120).timeout.connect(func():push_error("developer visual timeout");quit(2))
	if DisplayServer.get_name()=="headless":push_error("visual review needs a real renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1600,900);Engine.max_fps=60
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;dev=game.developer_review
	await shot("01_主菜单巡查入口")
	dev.open_login();await shot("02_账号登录")
	dev.account.text="sabrina";dev.password.text=OS.get_environment("DEV_REVIEW_TEST_PASSWORD");dev.submit_login();await wait_loaded()
	if not dev.active:push_error("visual login failed");quit(2);return
	await shot("03_地点与巡查面板")
	await dev.visit("town_01");dev._toggle_panel();await shot("04_街道巡查")
	await dev.visit("c2_16");await shot("05_第二案巡查")
	dev._toggle_panel();root.size=Vector2i(1280,720);await shot("06_720p面板适配")
	await dev.take_screenshot()
	if not dev.status.text.begins_with("截图已保存"):push_error("actual F9 screenshot failed");quit(2);return
	var file:=FileAccess.open(out+"capture.json",FileAccess.WRITE);file.store_string(JSON.stringify({"kind":"Godot actual developer mode framebuffer, not concept art","shots":shots,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name()},"\t"));file.close()
	dev.end_session();game.audio_system.stop_voice();game.queue_free();await process_frame;await process_frame;await create_timer(.2).timeout;quit(0)
