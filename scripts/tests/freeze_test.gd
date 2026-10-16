extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 20:
        game._on_start()
        game.clock_min = 1456.95
    elif f == 300:
        print("[F] 预览中 phase=", game.cut_phase, " can_move=", game.player.can_move, " 过场机位在用=", (game.cutcam != null and game.cutcam.current))
    elif f == 700:
        print("[F] 下一轮开始后 round=", game.round, " state=", game.state)
        print("[F] ★ can_move=", game.player.can_move, "（必须 true）")
        print("[F] ★ 玩家相机在用=", game.player.cam.current, "（必须 true）")
        print("[F] ★ 过场机位已释放=", game.cutcam == null, "（必须 true）")
        print("[F] 鼠标锁定=", Input.mouse_mode, "（2=CAPTURED）")
        return true
    return false
