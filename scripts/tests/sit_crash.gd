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
    elif f == 40:
        var s: Dictionary = game.builder.seats[0]
        print("[C] 座位 ", s["pos"])
        # 站到椅子正前方（按椅子朝向的反方向退 0.9 米）
        var yaw := float(s["yaw"])
        var face := Vector3(-sin(yaw), 0, -cos(yaw))          # 椅子的朝向
        game.player.global_position = s["pos"] + face * 1.0   # 站在椅子正前方
        game.player.rotation.y = yaw + PI                     # 转身面对椅子
        print("[C] 站位 ", game.player.global_position)
    elif f == 60:
        print("[C] 提示=", game.prompt)
    elif f == 66:
        print("[C] 按 E（走真实交互路径）")
        game._interact()
    elif f == 70:
        print("[C] 交互后 sitting=", game.player.sitting, " cam_mode=", game.player.cam_mode)
    elif f == 200:
        print("[C] 200 帧后仍在运行 sitting=", game.player.sitting, " state=", game.state)
        return true
    return false
