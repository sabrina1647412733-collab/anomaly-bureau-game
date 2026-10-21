extends SceneTree
## 洗衣店（跑在 0017 框架上）实机截图。用帧计数驱动，不在 _process 里 await。
##   --path . --script res://scripts/tests/laundry_case_shot.gd
const OUT := "res://_预览/洗衣店/0017框架/"

var game
var frames := 0
var idx := -1
var cool := 0
var shoot := false
var started := false
var shots := [
	{"n": "L1_门厅_北望", "p": Vector3(-0.55, 1.66, 14.0), "t": Vector3(0.3, 1.3, 0.0), "fov": 70.0},
	{"n": "L2_洗衣店_进门", "p": Vector3(0.0, 5.16, 10.0), "t": Vector3(-1.5, 4.4, 2.2), "fov": 76.0},
	{"n": "L3_洗衣店_机组", "p": Vector3(-1.2, 5.1, 9.4), "t": Vector3(-2.85, 4.35, 5.2), "fov": 74.0},
	{"n": "L4_7号机", "p": Vector3(0.0, 4.95, 5.2), "t": Vector3(0.0, 4.1, 2.4), "fov": 52.0},
	{"n": "L5_她坐长椅", "p": Vector3(-0.3, 4.62, 6.4), "t": Vector3(1.85, 4.25, 6.25), "fov": 52.0},
	{"n": "L6_后房", "p": Vector3(-1.15, 4.95, 1.55), "t": Vector3(-1.6, 4.25, -0.7), "fov": 74.0},
	{"n": "L7_403缝纫机", "p": Vector3(-0.9, 11.0, 5.0), "t": Vector3(0.1, 10.6, 3.1), "fov": 62.0},
	{"n": "L8_402老周", "p": Vector3(-2.1, 11.15, 4.9), "t": Vector3(-1.72, 10.95, 2.92), "fov": 46.0},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 10 and not started:
		started = true
		game.start_laundry_case()
	if frames == 40:
		# 让她进场并坐好（第一夜 01:10）
		var lc = game.laundry
		lc.t = 90.0 * 60.0
		lc._timeline()
		if lc.night != null:
			for i in range(40):
				lc.night._npc_step(0.2)
			lc.night._do_sit()
			if lc.night.lady != null:
				lc.night.lady.ap.play("SitIdle")
				lc.night.lady.ap.advance(1.0)
				lc.night.lady.current = "SitIdle"
				lc.night.lady._apply_seat_offset_instant()
	if frames < 60:
		return false
	if idx < 0:
		idx = 0
		_apply(idx)
		return false
	cool += 1
	if cool == 18:
		shoot = true
	return false

func _grab() -> void:
	if not shoot:
		return
	shoot = false
	if game == null or game.laundry == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + shots[idx]["n"] + ".png")
	print("[SHOT] ", shots[idx]["n"])
	idx += 1
	if idx >= shots.size():
		quit()
		return
	_apply(idx)
	cool = 0

func _apply(i: int) -> void:
	var s = shots[i]
	var cam: Camera3D = game.player.cam
	cam.current = true
	cam.fov = s["fov"]
	var off: Vector3 = game.laundry.world.position
	cam.look_at_from_position(s["p"] + off, s["t"] + off, Vector3.UP)
	if game.player.view_arm != null:
		game.player.view_arm.visible = false
