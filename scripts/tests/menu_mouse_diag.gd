extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 40:
        var b: Button = _find(game.menu.center, "开")
        print("[M] btn rect=", b.get_global_rect() if b else "null")
        if b:
            var at := b.get_global_rect().get_center()
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = true
            ev.position = at
            ev.global_position = at
            ev.button_mask = MOUSE_BUTTON_MASK_LEFT
            Input.parse_input_event(ev)
    if f == 43:
        var b: Button = _find(game.menu.center, "开")
        if b:
            var at := b.get_global_rect().get_center()
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = false
            ev.position = at
            ev.global_position = at
            ev.button_mask = 0
            Input.parse_input_event(ev)
        print("[M] state=", game.state, " menu vis=", game.menu.visible)
    if f == 50:
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

