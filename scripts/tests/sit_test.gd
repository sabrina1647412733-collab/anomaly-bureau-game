extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _key(code: int) -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = code
    ev.pressed = true
    root.push_input(ev)
    var ev2 := InputEventKey.new()
    ev2.physical_keycode = code
    ev2.pressed = false
    root.push_input(ev2)
func _process(_d: float) -> bool:
    f += 1
    if f == 20:
        game._on_start()
    elif f == 30:
        print("[S] 座位数=", game.builder.seats.size(), " 第一个座位=", game.builder.seats[0]["pos"], " 朝向=", "%.2f" % game.builder.seats[0]["yaw"])
        print("[S] 视角模式=", game.player.cam_mode, " 身体可见=", game.player.body.visible)
        _key(KEY_V)
    elif f == 40:
        print("[S] 按 V 后 视角模式=", game.player.cam_mode, " 身体可见=", game.player.body.visible)
        var s: Dictionary = game.builder.seats[0]
        game.player.sit_at(s["pos"], float(s["yaw"]))
    elif f == 60:
        print("[S] 坐下后 sitting=", game.player.sitting, " can_move=", game.player.can_move, " 位置=", game.player.global_position)
        print("[S] 提示=", game.prompt)
        game._interact()
    elif f == 80:
        print("[S] 起身后 sitting=", game.player.sitting, " can_move=", game.player.can_move)
        return true
    return false
