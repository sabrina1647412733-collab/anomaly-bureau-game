extends SceneTree
## 诊断
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _dump(tag: String) -> void:
    print(tag, " state=", game.state, " phase=", game.cut_phase, " round=", game.round,
        " 菜单=", game.menu.visible, " 头 z=%.0f" % game.train.cars[0].position.z,
        " dv=", game.divert, " t=%.2f" % game.cut_t)
func _process(_d: float) -> bool:
    f += 1
    match f:
        3:
            game._on_start()
            game.round = 3
            for it in game.items:
                it["got"] = true
            game.divert = true
            _dump("f3")
        6:
            game._begin_divert_end()
            _dump("f6")
        8:
            _dump("f8")
        12:
            _dump("f12")
        30:
            _dump("f30")
        60:
            _dump("f60")
        140:
            _dump("f140")
        200:
            _dump("f200")
    return f > 205
