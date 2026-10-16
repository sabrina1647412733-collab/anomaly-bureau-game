extends SceneTree
var game
var f := 0
var step := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 20:
        game._on_start()
        game.clock_min = 1456.95
    elif f == 90:      # 列车正在驶过时按跳过
        print("[S] 跳过前 phase=", game.cut_phase)
        game._skip_cutscene()
    elif f == 105:
        print("[S] 第一下跳过 → phase=", game.cut_phase, "（应到 end）")
    elif f == 160:
        print("[S] 现在 phase=", game.cut_phase, "（应到 preview，正在环绕）")
        game._skip_cutscene()
    elif f == 180:
        print("[S] 第二下跳过 → phase=", game.cut_phase)
        game._skip_cutscene()
    elif f == 200:
        print("[S] 最终 round=", game.round, " state=", game.state)
        return true
    return false
