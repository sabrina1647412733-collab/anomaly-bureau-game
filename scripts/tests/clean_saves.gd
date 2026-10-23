extends SceneTree
func _init() -> void:
    if not OS.get_cmdline_user_args().has("--verify"):
        push_error("此工具只清理--verify验证目录，不删除玩家存档。")
        quit(1)
        return
    for name in ["save_1.json","save_2.json","save_3.json"]:
        var f=preload("res://scripts/storage_paths.gd").file(name)
        if FileAccess.file_exists(f):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
            print("已清理 ", f)
    quit()
