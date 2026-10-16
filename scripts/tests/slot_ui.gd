extends SceneTree
var game
var frames := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    frames += 1
    if frames == 20:
        game.menu.set_slots(game.slots_info(), "load")
        game.menu.show_slots("load")
    elif frames == 90:
        var m = game.menu
        print("slots_panel rect=", m.slots_panel.get_global_rect(), " visible=", m.slots_panel.visible)
        var vb = m.slots_panel.get_child(0)
        print("vbox rect=", vb.get_global_rect())
        for c in vb.get_children():
            print("   child ", c.get_class(), " rect=", c.get_global_rect(), " vis=", c.visible)
        game.menu.show_slots("save")
    elif frames == 130:
        print("-- 切到存档模式后 --")
        var vb2 = game.menu.slots_panel.get_child(0)
        for c in vb2.get_children():
            print("   child ", c.get_class(), " rect=", c.get_global_rect())
        return true
    return false
