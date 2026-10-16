extends SceneTree
## 把截图降采样成字符画，便于无显示器时检查画面
const W := 48
const H := 18
func _initialize() -> void:
    for nm in ["frame105", "frame113", "frame128", "frame143", "frame158", "frame173", "frame190", "frame205"]:
        var p: String = "res://_shot/" + str(nm) + ".png"
        if not FileAccess.file_exists(p):
            print(nm, " 不存在")
            continue
        var img := Image.load_from_file(ProjectSettings.globalize_path(p))
        if img == null:
            print(nm, " 读不出")
            continue
        print("── ", nm, " ── ", img.get_width(), "x", img.get_height())
        var ramp := " .:-=+*#%@"
        for ry in range(H):
            var line := ""
            for rx in range(W):
                var x := int(float(rx) / float(W) * float(img.get_width()))
                var y := int(float(ry) / float(H) * float(img.get_height()))
                var c := img.get_pixel(x, y)
                var l := clampf(c.r * 0.30 + c.g * 0.59 + c.b * 0.11, 0.0, 1.0)
                var k := clampi(int(l * 9.99), 0, 9)
                line += ramp[k]
            print(line)
    quit()
