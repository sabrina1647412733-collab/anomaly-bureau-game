extends SceneTree
## 实机截图：主菜单 → 出租屋 → 洗衣店（全用 0017 现成 UI）
const OUT := "res://_预览/洗衣店/动线/"
var game
var frames := 0
var idx := 0
var shoot := false
var steps := ["0_主菜单", "1_出租屋_目标条", "2_出租屋_看门", "3_洗衣店_门厅", "4_洗衣店_机组", "5_洗衣店_七号机", "6_洗衣店_她"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 12:
		shoot = true
		return false
	if frames == 40:
		game._on_new_game()
	if frames == 100:
		shoot = true
		return false
	if frames == 140:
		var p = game.player
		p.position = Vector3(-0.9, 12.1, 321.4)
		p.rotation.y = 0.0
		p.pitch = -0.05
		p.cam.rotation.x = -0.05
	if frames == 180:
		shoot = true
		return false
	if frames == 210:
		game._prologue_drop_letter()
		game.prologue_letter_read = true
		game.prologue_call_done = true
		game._prologue_act("door")
	if frames == 500:
		var p2 = game.player
		p2.position = game.laundry.world.position + Vector3(0.0, 0.05, 10.0)
		p2.rotation.y = PI
		p2.pitch = -0.02
		p2.cam.rotation.x = -0.02
		shoot = true
	if frames == 560:
		var p3 = game.player
		p3.position = game.laundry.world.position + Vector3(-1.2, 3.55, 9.4)
		p3.rotation.y = -0.5
		p3.pitch = -0.1
		p3.cam.rotation.x = -0.1
		shoot = true
	if frames == 620:
		var p4 = game.player
		p4.position = game.laundry.world.position + Vector3(1.5, 3.55, 9.0)
		p4.rotation.y = PI
		p4.pitch = -0.05
		p4.cam.rotation.x = -0.05
		shoot = true
	if frames == 680:
		var p5 = game.player
		p5.position = game.laundry.world.position + Vector3(0.0, 4.25, 2.75)
		p5.rotation.y = 0.0
		p5.pitch = -0.05
		p5.cam.rotation.x = -0.05
		shoot = true
	return false

func _grab() -> void:
	if not shoot:
		return
	shoot = false
	var img: Image = root.get_texture().get_image()
	var nm: String = steps[mini(idx, steps.size() - 1)]
	img.save_png(OUT + nm + ".png")
	print("[SHOT] ", nm)
	idx += 1
	if idx >= steps.size():
		quit()
		return
