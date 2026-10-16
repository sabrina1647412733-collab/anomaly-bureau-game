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
    elif f == 30:
        print("[V] 第一人称 手臂可见=", game.player.view_arm.visible, " 身体可见=", game.player.body.visible)
        var s: Dictionary = game.builder.seats[0]
        game.player.sit_at(s["pos"], float(s["yaw"]))
    elif f == 40:
        print("[V] 坐下后 cam_mode=", game.player.cam_mode, "（0=第一人称，不被强制切换） sitting=", game.player.sitting, " 手臂=", game.player.view_arm.visible)
        game.player.stand_up()
        game.player.toggle_cam()
    elif f == 50:
        print("[V] 切第三人称 手臂=", game.player.view_arm.visible, " 身体=", game.player.body.visible)
        var back := Vector3(0, 0.55, 3.3).rotated(Vector3.RIGHT, 0.5)
        print("[V] pitch=+0.5（抬头）时相机相对高度 y=", "%.2f" % back.y, "（负=相机在角色下方 → 正常）")
        return true
    return false
