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
    match f:
        20:
            game._on_start()
            print("[K] 开始 state=", game.state)
        30:
            _key(KEY_B)
        34:
            print("[K] 按 B → 背包可见=", game.bag.visible, " 选中=", game.bag.sel)
            _key(KEY_B)
        38:
            print("[K] 再按 B → 背包可见=", game.bag.visible)
            game.player.global_position = Vector3(-10.25, 0.25, 8.60)
            game.player.rotation.y = PI * 0.5
        46:
            print("[K] 站到值班室门前 → 提示=", game.prompt)
        50:
            _key(KEY_E)
        54:
            print("[K] 按 E → 值班室门 open=", game.doors[2]["open"], " 位置=", game.doors[2]["node"].position)
            game.player.global_position = Vector3(-15.35, 0.25, -36.0)
            game.player.rotation.y = PI * 0.5
        62:
            print("[K] 检修笼门前 → 提示=", game.prompt)
        66:
            _key(KEY_E)
        70:
            print("[K] 未合闸按 E → 检修笼门 open=", game.doors[1]["open"], "（应仍是 false）")
            game.power = true
        78:
            _key(KEY_E)
        82:
            print("[K] 合闸后按 E → 检修笼门 open=", game.doors[1]["open"])
            return true
    return false
