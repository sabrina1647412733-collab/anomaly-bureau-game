extends SceneTree
var game
var lc
var folder := "res://_预览/第一案三夜/"

func _initialize() -> void: call_deferred("run")

func frame(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+name+".png")

func view(eye: Vector3,target: Vector3) -> void:
	game.player.global_position = eye-Vector3(0,1.6,0)
	game.player.cam_mode = 0
	game.player.body.visible = false
	game.player.cam.global_position = eye
	game.player.cam.look_at(target)
	game.field_kit.rig.visible = false
	game.hud_prompt.text = ""
	game._clear_sub()
	game._update_hud()
	game.director.toast.visible = false

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1600,900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._enter_laundry_from_room()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud_fade.modulate.a = 0
	game.hud.visible = true
	game.hud_end.modulate.a = 0
	game.hud_end_title.modulate.a = 0
	lc = game.laundry
	var story = lc.campaign
	view(Vector3(0,5.15,9.1),Vector3(0,4.25,3.2))
	await frame("01_洗衣店")
	story.show_page("303 · 结婚证与家庭照片",story.DOCS.marriage[1]+"\n\n"+story.DOCS.photo[1])
	await frame("02_调查阅读")
	story.close_page()
	for id in ["slip","marriage","photo","cert","discharge","pipe_map","sweater","sandal"]:
		game.bag_add(id,story.DOCS[id][0],story.DOCS[id][1])
	game.field_kit.open_inventory(true)
	game.field_kit.select("discharge")
	await frame("03_格子背包")
	game.field_kit.open_inventory(false)
	view(Vector3(-1.7,14.25,5.0),Vector3(.8,13.8,4.3))
	await frame("04_维修通道")
	view(Vector3(6.0,5.15,10.1),Vector3(14.0,4.7,10))
	await frame("05_廊桥")
	view(Vector3(0,17.2,7.8),Vector3(-1.0,17.5,3.5))
	await frame("06_屋顶童装")
	view(Vector3(.5,-1.3,-3.5),Vector3(3.2,-1.9,-6))
	await frame("07_地下竖井")
	view(Vector3(.15,5.05,7.9),Vector3(1.7,4.25,6.7))
	lc._spawn_lady(false)
	lc.night._do_sit()
	lc.night.lady_state = "sit"
	story.bag_model.visible = true
	await frame("08_周秀兰和衣袋")
	game.field_kit.equip("sweater")
	await frame("09_手持毛衣")
	game.field_kit.equip("sandal")
	await frame("10_手持童鞋")
	game.field_kit.equip("phone")
	await frame("11_手持手机")
	game.field_kit.equip("envelope")
	await frame("12_手持信件")
	game.field_kit.equip("weird_clock")
	await frame("13_手持时钟")
	game.field_kit.stow()
	story.progress.night = 3
	story.progress.earnings = 2400
	story.progress.rent_due = 0
	story.progress.spare = 240
	lc.selected_ending = "A"
	lc.complete_case()
	await frame("14_结案")
	game._discard_laundry()
	game.queue_free()
	await process_frame
	quit(0)
