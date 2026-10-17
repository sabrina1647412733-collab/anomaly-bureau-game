extends SceneTree
var game
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    _run()
func _run() -> void:
    for i in range(30): await process_frame
    game._on_start()
    game._show_final_choice()
    await process_frame
    print("[LAYOUT] final lines=", game.hud_end.get_line_count(), " min=", game.hud_end.get_minimum_size(), " size=", game.hud_end.size)
    for k in ["A","B","C"]:
        game._show_end(k)
        await process_frame
        print("[LAYOUT] ", k, " lines=", game.hud_end.get_line_count(), " min=", game.hud_end.get_minimum_size(), " size=", game.hud_end.size)
    quit()
