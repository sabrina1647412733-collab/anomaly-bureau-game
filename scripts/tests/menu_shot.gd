extends SceneTree
const OUT := "res://_预览/截图/"
var frames := 0
var game
func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    frames += 1
    if frames == 8:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if frames == 45:
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        img.save_png(OUT + "menu_after.png")
        print("[SHOT] menu_after ", img.get_width(), "x", img.get_height())
        quit()
    return false
