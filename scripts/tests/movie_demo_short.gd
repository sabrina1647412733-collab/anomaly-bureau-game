extends SceneTree
## 答辩用短版演示片：约 22 秒，配 --write-movie 出片
var game
var f := 0

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
		45:
			game._on_start()
		80:
			_look(-14.35, -13.60, PI * 0.5, -0.04)
		170:
			_look(-6.0, 6.0, 0.0, 0.02)
		260:
			_look(-15.30, -14.00, PI * 0.5, -0.10)
		305:
			game._press_button(0)
		365:
			game._press_button(1)
		425:
			game._press_button(2)
		480:
			game.round = 0
			game._refresh_visibility()
			_look(-12.60, 28.20, PI * 0.5, -0.02)
		575:
			game.hud_end.modulate.a = 1.0
			game._show_end("B")
	return f > 660
