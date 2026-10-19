extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 30:
        var b: Button = _find(game.menu.center, "开")
        print("[D] btn=", b, " rect=", b.get_global_rect() if b else "null", " mf=", b.mouse_filter if b else -1, " disabled=", b.disabled if b else true)
        print("[D] state before=", game.state)
        if b:
            b.emit_signal("pressed")
        print("[D] state after direct=", game.state)
    if f == 34:
        var b: Button = _find(game.menu.center, "开")
        if b:
            var at := b.get_global_rect().get_center()
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = true
            ev.position = at
            ev.global_position = at
            root.push_input(ev)
        print("[D] state after mouse=", game.state)
    if f == 40:
        quit()
    return false
func _find(node: Node, prefix: String) -> Button:
    for c in node.get_children():
        if c is Button:
            for ch in c.get_children():
                if ch is Label and String(ch.text).begins_with(prefix):
                    return c
        var r := _find(c, prefix)
        if r != null:
            return r
    return null
