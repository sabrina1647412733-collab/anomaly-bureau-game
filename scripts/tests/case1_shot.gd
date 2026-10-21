extends SceneTree
## 第一案实机截图。
##   --path . --script res://scripts/tests/case1_shot.gd
##
## ★ 取图必须在 RenderingServer.frame_post_draw 回调里做。
##   之前写错成在 _process 里直接 root.get_texture().get_image()，
##   拿到的是旧帧 —— 表现为「无论怎么改机位，截图都一模一样」。
const OUT := "res://_预览/洗衣店/第一案/"

var game
var phase := 0
var idx := 0
var wait := 0
var frames := 0
var shoot := false
var pending_name := ""

const STEPS := ["1_洗衣店门厅", "2_洗衣店店堂", "3_她坐在长椅上", "4_三选一", "5_结局卡"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_on_post_draw)

func _aim(pos: Vector3, yaw: float, pitch := -0.03) -> void:
	var p = game.player
	p.global_position = pos
	p.rotation.y = yaw
	p.pitch = pitch
	p.cam.rotation.x = pitch
	p.velocity = Vector3.ZERO
	p.can_move = false
	p.set_physics_process(false)

func _ask(nm: String) -> void:
	pending_name = nm
	shoot = true
	# 截图前强制清掉黑幕：转场的 tween 可能还没跑完，
	# 否则拍出来就是纯黑（这个坑骗了我们好几轮）。
	game.hud_fade.modulate.a = 0.0
	if game.hud != null:
		game.hud.visible = true

func _on_post_draw() -> void:
	if not shoot:
		return
	shoot = false
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + pending_name + ".png")
	print("[SHOT] ", pending_name, " ", img.get_width(), "x", img.get_height())
	idx += 1
	if idx >= STEPS.size():
		quit(0)

func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			if frames == 8:
				game._on_new_game()
				phase = 1
		1:
			if game.state == "prologue":
				game._prologue_drop_letter()
				game.prologue_letter_read = true
				game.prologue_call_done = true
				game._prologue_act("door")
				phase = 2
		2:
			if game.case_mode == "laundry" and game.state == "play" and game.player.can_move:
				_aim(Vector3(-0.55, 0.05, -6.0), PI)
				wait = 0
				phase = 3
		3:
			wait += 1
			if wait == 20:
				_ask(STEPS[0])
			elif wait > 26:
				_aim(Vector3(-2.0, 3.58, 8.6), 2.35, -0.12)
				wait = 0
				phase = 4
		4:
			wait += 1
			if wait == 20:
				_ask(STEPS[1])
			elif wait > 26:
				var lc = game.laundry
				lc.t = 91.0 * 60.0
				lc._timeline()
				if lc.night != null:
					for k in range(40):
						lc.night._npc_step(0.2)
					lc.night._do_sit()
					if lc.night.lady != null:
						lc.night.lady.ap.play("SitIdle")
						lc.night.lady.ap.advance(1.0)
						lc.night.lady.current = "SitIdle"
						lc.night.lady._apply_seat_offset_instant()
				_aim(Vector3(-0.6, 3.58, 8.8), 2.55, -0.16)
				wait = 0
				phase = 5
		5:
			wait += 1
			if wait == 20:
				_ask(STEPS[2])
			elif wait > 26:
				var lc2 = game.laundry
				lc2.t = 221.0 * 60.0
				lc2._timeline()
				game._update_interaction()
				wait = 0
				phase = 6
		6:
			wait += 1
			if wait == 20:
				_ask(STEPS[3])
			elif wait > 26:
				game.laundry.clues["sweater"] = true
				game.laundry.choose_final("A")
				wait = 0
				phase = 7
		7:
			wait += 1
			if wait == 20:
				_ask(STEPS[4])
	return false
