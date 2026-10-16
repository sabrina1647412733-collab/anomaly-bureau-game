extends SceneTree
var game
var frames := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    frames += 1
    if frames == 20:
        game._on_start()
    elif frames == 40:
        print("[S] 序章按钮: ", game.buttons.size(), " 轮次=", game.round)
        game._press_button(0); game._press_button(1)
        print("[S] 存档到槽位1: ", game.game_save(0))
        game.round = 0
        print("[S] 存档到槽位3: ", game.game_save(2))
        var info = game.slots_info()
        for i in range(3):
            print("   槽位", i + 1, " 存在=", info[i]["exists"], " 轮次=", info[i]["round"], " 钟=", info[i]["clock"], " 时间=", info[i]["time"])
    elif frames == 60:
        print("[S] 读槽位1: ", game.game_load(0), " → round=", game.round, " power=", game.power, " 按钮1=", game.buttons[0]["done"])
        print("[S] 读空槽位2: ", game.game_load(1))
        game.menu.set_slots(game.slots_info(), "load")
        game.menu.show_slots("load")
    elif frames == 80:
        for b in game.menu.slot_btns:
            print("   槽位按钮 rect=", b.get_global_rect(), " disabled=", b.disabled)
            print("        text=", b.text.replace("\n", " / "))
        print("[S] 主菜单 center.visible=", game.menu.center.visible, " slots.visible=", game.menu.slots_panel.visible)
        game.menu.show_slots("save")
        print("[S] 存档模式 disabled=", game.menu.slot_btns[0].disabled, game.menu.slot_btns[1].disabled, game.menu.slot_btns[2].disabled)
        return true
    return false
