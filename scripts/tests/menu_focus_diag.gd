extends SceneTree
var game
var f := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 30:
        print("[K] focus0=", root.gui_get_focus_owner())
        var ev := InputEventAction.new()
        ev.action = "ui_accept"
        ev.pressed = true
        root.push_input(ev)
    if f == 32:
        print("[K] focus1=", root.gui_get_focus_owner())
        var ev2 := InputEventAction.new()
        ev2.action = "ui_accept"
        ev2.pressed = true
        root.push_input(ev2)
    if f == 36:
        print("[K] state=", game.state, " focus2=", root.gui_get_focus_owner())
    if f == 46:
        quit()
    return false

