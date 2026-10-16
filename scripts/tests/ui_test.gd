extends SceneTree
var game
var frames := 0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    frames += 1
    if frames == 30:
        var m = game.menu
        print("[UI] menu.visible=", m.visible, " size=", m.size)
        print("[UI] center visible=", m.center.visible, " pos=", m.center.global_position, " size=", m.center.size)
        for c in m.center.get_children():
            var txt := ""
            if c is Button: txt = "  text=" + c.text
            if c is Label: txt = "  text=" + c.text
            print("   - ", c.get_class(), " visible=", c.visible, " rect=", c.get_global_rect(), txt)
        print("[UI] sett.visible=", m.sett.visible, " pause.visible=", m.pause_panel.visible)
        print("[UI] 字体=", m.font.get_font_name() if m.font else "null")
        # 查看设置面板内容
        for c in m.sett.get_children():
            for cc in c.get_children():
                if cc is HSlider: print("   设置滑条 value=", cc.value, " rect=", cc.get_global_rect())
                elif cc is Label: print("   设置标签 text=", cc.text)
        return true
    return false
