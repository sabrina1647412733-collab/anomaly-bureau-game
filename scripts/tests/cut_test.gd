extends SceneTree
var game
var f := 0
var last_phase := ""
var t0 := -1
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    if f == 20:
        game._on_start()
        game.clock_min = 1456.95
    elif f > 40:
        if t0 < 0:
            t0 = f
            print("[R] 到点 state=", game.state, " phase=", game.cut_phase)
        if game.cut_phase != last_phase:
            last_phase = game.cut_phase
            var extra := ""
            if last_phase == "preview":
                extra = "  环绕中心=%s 半径=%.1f" % [game.preview_center, game.preview_r]
                for np in game.npcs:
                    if np["node"].visible:
                        extra += "  可见人物:" + String(np["name"])
            print("  [phase→] %s%s（第 %d 帧 ≈ %.1f 秒）" % [last_phase, extra, f - t0, (f - t0) / 60.0])
        if game.round == 0 and game.state == "play":
            print("[R] 完整一轮过场 = %.1f 秒" % ((f - t0) / 60.0))
            return true
    return false
