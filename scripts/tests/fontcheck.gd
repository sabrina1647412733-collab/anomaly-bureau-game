extends SceneTree
func _init():
    var sf := SystemFont.new()
    sf.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"])
    sf.allow_system_fallback = true
    print("字体名: ", sf.get_font_name())
    print("字形数: ", sf.get_face_count())
    for ch in ["岚", "桥", "站", "继", "电", "器", "K", "0"]:
        var cp: int = String(ch).unicode_at(0)
        print("  字符 ", ch, " U+%04X 存在? " % cp, sf.has_char(cp))
    var sz := sf.get_string_size("岚桥站 0017", HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
    print("测量 \"岚桥站 0017\" @32px = ", sz)
    print("系统是否装了微软雅黑: ", OS.get_system_font_path("Microsoft YaHei", 400, 0, false))
    quit()
