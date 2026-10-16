extends SceneTree
## 无头驱动：菜单 → 开始 → 序章 → 过场 → 下一轮，并测存读档
var game
var frames := 0
var step := 0

func _initialize() -> void:
    var scn = load("res://scenes/main.tscn").instantiate()
    root.add_child(scn)
    game = scn

func _process(_delta: float) -> bool:
    frames += 1
    if frames == 20:
        print("[T] 菜单状态 state=", game.state, " round=", game.round, " 有存档=", game.game_has_save())
        game._on_start()
    elif frames == 40:
        print("[T] 开始后 state=", game.state, " round=", game.round, " 钟=", game.clock_min)
        print("[T] 人物可见: ", _npcs())
        print("[T] 物品可见: ", _items())
        game._press_button(0)
        print("[T] 按下第一个钮 → 钟=", "%.2f" % game.clock_min)
    elif frames == 60:
        print("[T] 存档: ", game.game_save(0), " 文件存在=", game.game_has_save())
        game.clock_min = 1456.95
    elif frames == 100:
        print("[T] 到点后 state=", game.state, " (应为 cutscene)")
    elif frames == 700:
        print("[T] 过场结束 → state=", game.state, " round=", game.round, " (应进入第 1 轮=0)")
        print("[T] 人物可见: ", _npcs())
        game.clock_min = 1456.95
    elif frames == 1000:
        print("[T] 第二轮开始 round=", game.round, " 人物: ", _npcs())
        print("[T] 读档测试: ", game.game_load(0), " → round=", game.round)
        return true
    return false

func _npcs() -> String:
    var s := []
    for np in game.npcs:
        if np["node"].visible:
            s.append(np["name"])
    return "[" + ", ".join(s) + "]"

func _items() -> String:
    var s := []
    for it in game.items:
        if it["node"].visible:
            s.append(str(it["def"]["name"]))
    return "[" + ", ".join(s) + "]"
