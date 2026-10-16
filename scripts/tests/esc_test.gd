extends SceneTree
var game
var f := 0
var scene_ok := false
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _esc() -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = KEY_ESCAPE
    ev.pressed = true
    root.push_input(ev)
func _process(_d: float) -> bool:
    f += 1
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    match f:
        20:
            game._on_start()
            print("[E] 开始后 state=", game.state, " 菜单=", game.menu.visible, " 时钟在走=", game.state == "play")
        30:
            _esc()
        34:
            print("[E] 第一次 Esc: state=", game.state, " 暂停面板=", game.menu.pause_panel.visible, " 菜单=", game.menu.visible, " 鼠标=", Input.mouse_mode)
        40:
            _esc()
        44:
            print("[E] 第二次 Esc: state=", game.state, " 菜单=", game.menu.visible, " 鼠标=", Input.mouse_mode, " allow_capture=", game.player.allow_capture)
        50:
            _esc()
        54:
            print("[E] 第三次 Esc: state=", game.state, " 暂停面板=", game.menu.pause_panel.visible)
        60:
            var b: Button = game.menu.pause_panel.get_child(0).get_child(3)
            print("[E] 暂停菜单按钮文字=", b.text)
            return true
    return false
