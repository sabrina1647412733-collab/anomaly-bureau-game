extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 30:
        game.menu.show_pause()
        print("[P] pause shown")
    if f == 38:
        var b: Button = _find(game.menu.pause_panel, "继")
        print("[P] btn=", b, " rect=", b.get_global_rect() if b else "null", " mf=", b.mouse_filter if b else -1)
        if b:
            var at := b.get_global_rect().get_center()
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = true
            ev.position = at
            ev.global_position = at
            ev.button_mask = MOUSE_BUTTON_MASK_LEFT
            root.push_input(ev)
    if f == 42:
        var b: Button = _find(game.menu.pause_panel, "继")
        if b:
            var at := b.get_global_rect().get_center()
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = false
            ev.position = at
            ev.global_position = at
            root.push_input(ev)
        print("[P] pause visible=", game.menu.pause_panel.visible, " state=", game.state)
    if f == 50:
        quit()
    return false
func _find(node: Node, prefix: String) -> Button:
    for c in node.get_children():
        if c is Button and String(c.text).begins_with(prefix):
            return c
        var r := _find(c, prefix)
        if r != null:
            return r
    return null
