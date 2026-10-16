extends SceneTree
var game
var frames := 0
var btn: Button = null
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    frames += 1
    if frames == 30:
        for c in game.menu.center.get_children():
            if c is Button and c.text.begins_with("开"):
                btn = c
        btn.button_down.connect(func(): print("[C] button_down ✓"))
        btn.button_up.connect(func(): print("[C] button_up ✓"))
        btn.pressed.connect(func(): print("[C] pressed ✓"))
        game.player.allow_capture = true
        var at := btn.get_global_rect().get_center()
        print("[C] 目标点 ", at, " 按钮 rect=", btn.get_global_rect())
        print("[C] 菜单 mouse_filter=", game.menu.mouse_filter, " visible=", game.menu.visible, " size=", game.menu.size)
        print("[C] 菜单 center pos=", game.menu.center.position, " global=", game.menu.center.get_global_rect())
        # 先推一个 motion，看 GUI 认为鼠标悬停在谁身上
        var mv := InputEventMouseMotion.new()
        mv.position = at
        mv.global_position = at
        root.push_input(mv)
    elif frames == 32:
        print("[C] 悬停控件 = ", root.gui_get_hovered_control())
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        ev.position = btn.get_global_rect().get_center()
        ev.global_position = ev.position
        root.push_input(ev)
    elif frames == 36:
        var ev2 := InputEventMouseButton.new()
        ev2.button_index = MOUSE_BUTTON_LEFT
        ev2.pressed = false
        ev2.position = btn.get_global_rect().get_center()
        ev2.global_position = ev2.position
        root.push_input(ev2)
    elif frames == 42:
        print("[C] 结果 state=", game.state, " round=", game.round, " menu.visible=", game.menu.visible)
        return true
    return false
