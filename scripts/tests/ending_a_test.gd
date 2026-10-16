extends SceneTree
## 结局 A（不改环线）依然要走通：过场 → 二选一 → 公开
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _key_down(code: int) -> void:
    var e1 := InputEventKey.new()
    e1.physical_keycode = code
    e1.pressed = true
    Input.parse_input_event(e1)
func _key_up(code: int) -> void:
    var e2 := InputEventKey.new()
    e2.physical_keycode = code
    e2.pressed = false
    Input.parse_input_event(e2)
func _key(code: int) -> void:
    var e1 := InputEventKey.new()
    e1.physical_keycode = code
    e1.pressed = true
    Input.parse_input_event(e1)
    var e2 := InputEventKey.new()
    e2.physical_keycode = code
    e2.pressed = false
    Input.parse_input_event(e2)
func _process(_d: float) -> bool:
    f += 1
    match f:
        20:
            game._on_start()
            game.round = 3
            for it in game.items:
                it["got"] = true
            game.handle = true
            game.late = false
            game.clock_min = 1457.2
        600:
            print("[A] 过场后 state=", game.state, " 有选择=", game.choice != null, " 结局=", game.shown_end)
        620:
            _key_down(KEY_E)
        660:
            _key_up(KEY_E)
        700:
            print("[A] 按 E 后 state=", game.state, " 结局=", game.shown_end, "（应为 A）")
            print("[A] 结局文字长度=", game.hud_end.text.length(), " 标题=", game.hud_end_title.text)
            return true
    return false
