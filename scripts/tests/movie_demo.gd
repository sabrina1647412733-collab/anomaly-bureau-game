extends SceneTree
## 演示片驱动：脚本化跑一段 40 秒的演示路径，配合 --write-movie 出片。
## 只读地摆机位 / 触发既有方法，不改游戏逻辑。
var game
var f := 0
var cut_started := false

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _look(x: float, z: float, yaw: float, pitch_v: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.allow_capture = false
	game.player.global_position = Vector3(x, 0.25, z)
	game.player.rotation.y = yaw
	game.player.pitch = pitch_v
	game.player.cam.rotation.x = pitch_v

func _process(_d: float) -> bool:
	f += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match f:
		3:
			_look(-14.35, -13.60, PI * 0.5, -0.04)
		60:
			game._on_start()
		100:
			_look(-14.35, -13.60, PI * 0.5, -0.04)   # 序章 · 调度台
		210:
			_look(-6.0, 6.0, 0.0, 0.02)               # 车站全景
		330:
			_look(-15.30, -14.00, PI * 0.5, -0.10)    # 三个按钮
		380:
			game._press_button(0)
		450:
			game._press_button(1)
		520:
			game._press_button(2)
		600:
			_look(-6.0, -2.0, 0.0, 0.0)               # 站台 · 等车
		700:
			game.round = 0
			game._refresh_visibility()
			_look(-12.60, 28.20, PI * 0.5, -0.02)     # 第 1 轮 · 林岚
		840:
			game._toggle_bag(true)                    # 线索板 / 背包
		980:
			game._toggle_bag(false)
		1010:
			game._begin_cutscene()                    # 循环过场
			cut_started = true
		1230:
			game.hud_end.modulate.a = 1.0
			game._show_end("B")                       # 结局 B
	return f > 1400
