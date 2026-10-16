extends SceneTree
const W := 60
const H := 20
var ref: Image
func _lum(img: Image, x: int, y: int) -> float:
    var acc := 0.0
    var n := 0
    for dy in range(3):
        for dx in range(3):
            var px := clampi(x + dx - 1, 0, img.get_width() - 1)
            var py := clampi(y + dy - 1, 0, img.get_height() - 1)
            var c := img.get_pixel(px, py)
            acc += c.r * 0.30 + c.g * 0.59 + c.b * 0.11
            n += 1
    return acc / float(n)
func _initialize() -> void:
    ref = Image.load_from_file(ProjectSettings.globalize_path("res://_shot/shot00000003.png"))
    for nm in ["shot00000004", "shot00000006", "shot00000008", "shot00000010", "shot00000012"]:
        var img := Image.load_from_file(ProjectSettings.globalize_path("res://_shot/" + nm + ".png"))
        if img == null or ref == null:
            print(nm, " 读不出")
            continue
        print("── ", nm, "（# = 与空场景差异 > 0.022）")
        for ry in range(H):
            var line := ""
            var mx := 0.0
            for rx in range(W):
                var x := int((float(rx) + 0.5) / float(W) * float(img.get_width()))
                var y := int((float(ry) + 0.5) / float(H) * float(img.get_height()))
                var d := absf(_lum(img, x, y) - _lum(ref, x, y))
                mx = maxf(mx, d)
                line += "#" if d > 0.022 else (":" if d > 0.008 else ".")
            print(line, "  max=%.3f" % mx)
    quit()
