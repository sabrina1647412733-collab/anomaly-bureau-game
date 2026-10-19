extends SceneTree
const OUT := "res://_预览/截图/"
var game
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    _run()
func _settle(n := 10) -> void:
    for i in range(n):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        await process_frame
    await RenderingServer.frame_post_draw
func _shot(nm: String) -> void:
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    img.save_png(OUT + nm + ".png")
    print("[SHOT] ", nm)
func _run() -> void:
    await _settle(40)
    game.menu.show_slots("load")
    await _settle(15)
    await _shot("menu_slots_after")
    game.menu._show_settings(true)
    await _settle(15)
    await _shot("menu_settings_after")
    game.menu.show_pause()
    await _settle(15)
    await _shot("menu_pause_after")
    quit()
