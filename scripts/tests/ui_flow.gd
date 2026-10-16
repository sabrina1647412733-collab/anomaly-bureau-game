extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func find_btn(node: Node, prefix: String) -> Button:
    for c in node.get_children():
        if c is Button and String(c.text).begins_with(prefix):
            return c
        var r := find_btn(c, prefix)
        if r != null:
            return r
    return null
func _mouse(b: Control, down: bool) -> void:
    var at := b.get_global_rect().get_center()
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = down
    ev.position = at
    ev.global_position = at
    root.push_input(ev)
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
            var b := find_btn(game.menu.center, "开")
            print("[F] 点开始 ", b != null)
            _mouse(b, true)
        24:
            var b := find_btn(game.menu.center, "开")
            _mouse(b, false)
        28:
            print("[F] 结果 state=", game.state, " 菜单可见=", game.menu.visible, " 鼠标锁定=", Input.mouse_mode)
            _esc()
        32:
            print("[F] Esc 后 state=", game.state, " 暂停面板=", game.menu.pause_panel.visible, " allow_capture=", game.player.allow_capture)
            var b := find_btn(game.menu.pause_panel, "继")
            _mouse(b, true)
        36:
            var b := find_btn(game.menu.pause_panel, "继")
            _mouse(b, false)
        40:
            print("[F] 点继续后 state=", game.state, " 菜单可见=", game.menu.visible, " 鼠标锁定=", Input.mouse_mode)
            _esc()
        44:
            var b := find_btn(game.menu.pause_panel, "设")
            _mouse(b, true)
        48:
            var b := find_btn(game.menu.pause_panel, "设")
            _mouse(b, false)
        52:
            print("[F] 设置面板=", game.menu.sett.visible, " 暂停面板=", game.menu.pause_panel.visible)
            var b := find_btn(game.menu.sett, "保")
            _mouse(b, true)
        56:
            var b := find_btn(game.menu.sett, "保")
            _mouse(b, false)
        60:
            print("[F] 从设置返回后 设置=", game.menu.sett.visible, " 暂停面板=", game.menu.pause_panel.visible, " state=", game.state)
            var b := find_btn(game.menu.pause_panel, "回")
            _mouse(b, true)
        64:
            var b := find_btn(game.menu.pause_panel, "回")
            _mouse(b, false)
        68:
            print("[F] 回主菜单后 state=", game.state, " center=", game.menu.center.visible, " 暂停=", game.menu.pause_panel.visible)
            return true
    return false
