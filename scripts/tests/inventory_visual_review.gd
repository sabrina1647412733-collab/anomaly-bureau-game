extends SceneTree
## Opt-in screenshots of the actual interactive inventory, not a mock overlay.
const OUT := "res://_预览/20261022_背包/"
var game
func _initialize():call_deferred("run")
func shot(name:String):
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	create_timer(55).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.field_kit.letter_accepted=true;game.start_laundry_case()
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game.player.lock_look=true;game.player.global_position=Vector3(.7,3.55,7.5)
	game.player.cam.global_position=Vector3(.7,5.15,7.5);game.player.cam.look_at(Vector3(-1.5,4.8,4.5))
	game.hud_fade.modulate.a=0;game.audio_system.stop_voice();game._clear_sub();game.feedback.reset()
	game.director.toast.visible=false;game.director.set_process(false);game.laundry.campaign.guidance.set_process(false)
	game.case_bag=[]
	for item in [["phone","手机","微语、通话、相册和随身记录。"],["envelope","入职通知书",""],["weird_clock","诡异时钟","随身黄铜座钟。\nT 打开时钟，可拨到下一事件。"],["sweater","七号机原衣",game.laundry.campaign.DOCS.sweater[1]],["roof_copy","重复的童装",game.laundry.campaign.DOCS.roof_copy[1]],["sandal","竖井里的蓝布鞋",game.laundry.campaign.DOCS.sandal[1]],["tool_key","503检修盒钥匙",game.laundry.campaign.DOCS.tool_key[1]],["machine_key","七号机专用钥匙",game.laundry.campaign.DOCS.machine_key[1]],["photo","303家庭照片",game.laundry.campaign.DOCS.photo[1]],["discharge","未投递的出院小结",game.laundry.campaign.DOCS.discharge[1]],["pipe_map","全楼管线图",game.laundry.campaign.DOCS.pipe_map[1]]]:
		game.case_bag.append({"id":item[0],"name":item[1],"desc":item[2],"kind":"物"})
	var kit=game.field_kit;kit.open_inventory(true)
	await shot("01_道具")
	kit.select("sweater");await shot("02_衣物")
	kit.select("photo");await shot("03_线索")
	kit.select("tool_key");await shot("04_钥匙")
	kit.select("sweater")
	root.size=Vector2i(1280,720);await shot("05_1280x720")
	root.size=Vector2i(1920,1080);await shot("06_1920x1080")
	game.case_bag=[];kit.refresh_inventory();await shot("07_空分类")
	game.queue_free();await process_frame;quit()
