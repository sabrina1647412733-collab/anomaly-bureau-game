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
        var s: Dictionary = game.builder.seats[0]
        game.player.sit_at(s["pos"], float(s["yaw"]))
    elif f == 40:
        var p = game.player
        print("[P] sitting=", p.sitting, " cam_mode=", p.cam_mode)
        print("[P] 髋 y=", "%.2f" % p.parts["hip"].position.y, "（站姿=0.86，坐姿应≈0.46）")
        print("[P] 头 y=", "%.2f" % p.parts["head"].position.y, "（站姿=1.44，坐姿应≈1.04）")
        print("[P] 大腿 rot.x=", "%.2f" % p.parts["hipL"].rotation.x, "（应 +1.57 = 向前平放）")
        print("[P] 小腿 rot.x=", "%.2f" % p.parts["kneeL"].rotation.x, "（应 -1.57 = 垂下）")
        print("[P] 上臂 rot.x=", "%.2f" % p.parts["shoulderL"].rotation.x)
    elif f == 60:
        print("[P] 60 帧后仍在运行")
        return true
    return false
