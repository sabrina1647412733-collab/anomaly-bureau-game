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
    game._on_start()
    await _settle(24)
    game.player.global_position = Vector3(-6.0, 0.25, 6.0)
    game.player.rotation.y = 0.0
    game.player.pitch = 0.02
    game.player.cam.rotation.x = 0.02
    await _settle(30)
    await _shot("station_before")
    quit()
