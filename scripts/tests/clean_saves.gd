extends SceneTree
func _init() -> void:
    for f in ["user://save_1.json", "user://save_2.json", "user://save_3.json"]:
        if FileAccess.file_exists(f):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
            print("已清理 ", f)
    quit()
