extends SceneTree
const W := 76
const H := 22
func _initialize() -> void:
    for nm in ["shot00000005", "shot00000007", "shot00000009", "shot00000011", "shot00000012"]:
        var p: String = "res://_shot/" + str(nm) + ".png"
        if not FileAccess.file_exists(p):
            print(nm, " 不存在")
            continue
        var img := Image.load_from_file(ProjectSettings.globalize_path(p))
        if img == null:
            print(nm, " 读不出")
            continue
        print("── ", nm)
        var ramp := " .:-=+*#%@"
        for ry in range(H):
            var line := ""
            for rx in range(W):
                var x := int(float(rx) / float(W) * float(img.get_width()))
                var y := int(float(ry) / float(H) * float(img.get_height()))
                var c := img.get_pixel(x, y)
                var l := clampf(c.r * 0.30 + c.g * 0.59 + c.b * 0.11, 0.0, 1.0)
                line += ramp[clampi(int(l * 9.99), 0, 9)]
            print(line)
    quit()
