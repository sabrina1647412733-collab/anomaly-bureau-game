extends Control
## 主菜单 / 存档 / 设置 / 暂停菜单
## 主菜单层级：诡异事务局（系列）→ 第一季「补丁」；具体案卷与权限只放在存档页

signal start_game
signal load_slot(index)
signal save_slot(index)
signal resume_game
signal to_menu
signal quit_game

var font: Font
var cfg := ConfigFile.new()
var slots_info: Array = []
var slot_mode := "load"
var settings_open := false
var pause_open := false
var center: Control
var slots_panel: Control
var slot_btns: Array = []
var sett: Control
var pause_panel: Control
var poster: TextureRect
var music_slider: HSlider
var sfx_slider: HSlider
var sens_slider: HSlider
var fog_slider: HSlider
var bright_slider: HSlider
var sub_slider: HSlider
var fs_btn: Button
var menu_rows: Array = []

func setup(f: Font) -> void:
    font = f
    _load_settings()
    _build_poster()
    _build_main()
    _build_slots()
    _build_settings()
    _build_pause()
    slots_panel.visible = false
    sett.visible = false
    pause_panel.visible = false

# ------------------------------------------------------------------ 设置读写
func _load_settings() -> void:
    if cfg.load("user://settings.cfg") != OK:
        cfg.set_value("audio", "music", 0.8)
        cfg.set_value("audio", "sfx", 1.0)
        cfg.set_value("input", "sens", 1.0)
        cfg.set_value("render", "fog", 1.0)
        cfg.set_value("render", "bright", 1.0)
        cfg.set_value("text", "speed", 1.0)

func _save_settings() -> void:
    cfg.set_value("audio", "music", music_slider.value / 100.0)
    cfg.set_value("audio", "sfx", sfx_slider.value / 100.0)
    cfg.set_value("input", "sens", sens_slider.value / 100.0)
    cfg.set_value("render", "fog", fog_slider.value / 100.0)
    cfg.set_value("render", "bright", bright_slider.value / 100.0)
    cfg.set_value("text", "speed", sub_slider.value / 100.0)
    cfg.save("user://settings.cfg")

func get_cfg() -> Dictionary:
    return {
        "music": float(cfg.get_value("audio", "music", 0.8)),
        "sfx": float(cfg.get_value("audio", "sfx", 1.0)),
        "sens": float(cfg.get_value("input", "sens", 1.0)),
        "fog": float(cfg.get_value("render", "fog", 1.0)),
        "bright": float(cfg.get_value("render", "bright", 1.0)),
        "speed": float(cfg.get_value("text", "speed", 1.0)),
    }

func apply_audio() -> void:
    var c := get_cfg()
    var mbus := AudioServer.get_bus_index("Music")
    var sbus := AudioServer.get_bus_index("SFX")
    if mbus >= 0:
        AudioServer.set_bus_volume_db(mbus, linear_to_db(clampf(c["music"], 0.001, 1.0)))
        AudioServer.set_bus_mute(mbus, c["music"] < 0.01)
    if sbus >= 0:
        AudioServer.set_bus_volume_db(sbus, linear_to_db(clampf(c["sfx"], 0.001, 1.0)))
        AudioServer.set_bus_mute(sbus, c["sfx"] < 0.01)

# ------------------------------------------------------------------ 控件工厂
func _fvar(embolden := 0.0, glyph_spacing := 0) -> FontVariation:
    var fv := FontVariation.new()
    fv.base_font = font
    fv.variation_embolden = embolden
    fv.spacing_glyph = glyph_spacing
    return fv

func _label(text: String, fs := 16, col := Color(0.88, 0.90, 0.94)) -> Label:
    var l := Label.new()
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", col)
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

func _flat_style(bg: Color, border: Color, border_w := 1) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.border_width_left = border_w
    sb.border_width_top = border_w
    sb.border_width_right = border_w
    sb.border_width_bottom = border_w
    sb.corner_radius_top_left = 0
    sb.corner_radius_top_right = 0
    sb.corner_radius_bottom_left = 0
    sb.corner_radius_bottom_right = 0
    return sb

func _panel_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.025, 0.040, 0.055, 0.94)
    sb.border_color = Color(0.42, 0.62, 0.70, 0.24)
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.content_margin_left = 26
    sb.content_margin_right = 26
    sb.content_margin_top = 22
    sb.content_margin_bottom = 22
    sb.shadow_color = Color(0, 0, 0, 0.55)
    sb.shadow_size = 24
    return sb

func _btn(text: String, fs := 18) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", fs)
    b.add_theme_color_override("font_color", Color(0.82, 0.87, 0.92))
    b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.65))
    b.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.60))
    b.add_theme_color_override("font_disabled_color", Color(0.38, 0.44, 0.50))
    b.add_theme_stylebox_override("normal", _flat_style(Color(0.035, 0.060, 0.080, 0.82), Color(0.34, 0.46, 0.52, 0.26)))
    b.add_theme_stylebox_override("hover", _flat_style(Color(0.070, 0.105, 0.130, 0.92), Color(0.82, 0.60, 0.32, 0.52)))
    b.add_theme_stylebox_override("pressed", _flat_style(Color(0.16, 0.12, 0.07, 0.92), Color(0.82, 0.60, 0.32, 0.70)))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.custom_minimum_size = Vector2(300, 46)
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_stylebox_override("focus", _flat_style(Color(0, 0, 0, 0), Color(0.82, 0.60, 0.32, 0.75)))
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return b

func _line(w: float, col := Color(1, 1, 1, 0.08)) -> ColorRect:
    var r := ColorRect.new()
    r.color = col
    r.custom_minimum_size = Vector2(w, 1)
    r.size = Vector2(w, 1)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

func _slider(parent: Control, label: String, value: float) -> HSlider:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(460, 30)
    var lb := _label(label, 15, Color(0.68, 0.78, 0.88))
    lb.custom_minimum_size = Vector2(120, 28)
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 100.0
    s.step = 1.0
    s.value = value * 100.0
    s.custom_minimum_size = Vector2(320, 28)
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(lb)
    row.add_child(s)
    parent.add_child(row)
    return s

# ------------------------------------------------------------------ 背景
func _build_poster() -> void:
    poster = TextureRect.new()
    poster.position = Vector2.ZERO
    poster.size = Vector2(1600, 900)
    poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
    poster.modulate = Color(1.08, 1.08, 1.08, 1.0)
    if ResourceLoader.exists("res://assets/ui/menu_bureau_bg.png"):
        poster.texture = load("res://assets/ui/menu_bureau_bg.png")
    elif ResourceLoader.exists("res://assets/poster.png"):
        poster.texture = load("res://assets/poster.png")
    else:
        poster.visible = false
    add_child(poster)

    # 左侧压暗，保证标题与菜单可读；右侧保留档案室桌面
    var g := Gradient.new()
    g.set_color(0, Color(0.010, 0.020, 0.035, 0.92))
    g.set_color(1, Color(0.010, 0.020, 0.035, 0.02))
    g.add_point(0.26, Color(0.010, 0.020, 0.035, 0.84))
    g.add_point(0.44, Color(0.010, 0.020, 0.035, 0.54))
    g.add_point(0.62, Color(0.010, 0.020, 0.035, 0.22))
    g.add_point(0.82, Color(0.010, 0.020, 0.035, 0.05))
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.width = 512
    gt.height = 2
    gt.fill = GradientTexture2D.FILL_LINEAR
    gt.fill_from = Vector2(0, 0)
    gt.fill_to = Vector2(1, 0)
    var grad := TextureRect.new()
    grad.texture = gt
    grad.position = Vector2.ZERO
    grad.size = Vector2(1600, 900)
    grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    grad.stretch_mode = TextureRect.STRETCH_SCALE
    grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grad)

    var dim := ColorRect.new()
    dim.color = Color(0.005, 0.010, 0.018, 0.18)
    dim.position = Vector2.ZERO
    dim.size = Vector2(1600, 900)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)

# ------------------------------------------------------------------ 主菜单
func _build_main() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    size = Vector2(1600, 900)

    center = Control.new()
    center.position = Vector2.ZERO
    center.size = Vector2(1600, 900)
    center.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(center)

    # 顶部：系列 / 当前游戏 / 权限
    var head_l := HBoxContainer.new()
    head_l.position = Vector2(88, 48)
    head_l.size = Vector2(860, 28)
    head_l.add_theme_constant_override("separation", 13)
    center.add_child(head_l)
    var series_en := _label("A N O M A L Y   B U R E A U   S E R I E S", 9, Color(0.39, 0.47, 0.56))
    head_l.add_child(series_en)

    var head_r := HBoxContainer.new()
    head_r.position = Vector2(1150, 44)
    head_r.size = Vector2(362, 32)
    head_r.alignment = BoxContainer.ALIGNMENT_END
    head_r.add_theme_constant_override("separation", 14)
    center.add_child(head_r)

    var date := _label("2026 · 第一季", 10, Color(0.42, 0.50, 0.59))
    date.add_theme_font_override("font", _fvar(0.0, 1))
    head_r.add_child(date)

    # 左侧竖线
    var rail := ColorRect.new()
    rail.color = Color(0.886, 0.631, 0.29, 0.26)
    rail.position = Vector2(58, 112)
    rail.size = Vector2(1, 672)
    center.add_child(rail)
    for i in range(6):
        var tick := ColorRect.new()
        tick.color = Color(0.886, 0.631, 0.29, 0.42)
        tick.position = Vector2(54, 112 + i * 120)
        tick.size = Vector2(9, 1)
        center.add_child(tick)

    # 系列标题
    var title := _label("诡异事务局", 92, Color(0.91, 0.94, 0.97))
    title.add_theme_font_override("font", _fvar(1.12, 1))
    title.position = Vector2(88, 138)
    title.size = Vector2(760, 124)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    center.add_child(title)

    var en := _label("A N O M A L Y   B U R E A U", 10, Color(0.38, 0.46, 0.55))
    en.position = Vector2(92, 264)
    en.size = Vector2(520, 18)
    en.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    center.add_child(en)

    # 季名：只做小字，不抢主标题
    var season_line := ColorRect.new()
    season_line.color = Color(0.79, 0.62, 0.39, 0.50)
    season_line.position = Vector2(88, 302)
    season_line.size = Vector2(30, 1)
    center.add_child(season_line)
    var season := _label("第 一 季 · 补 丁", 11, Color(0.79, 0.62, 0.39))
    season.position = Vector2(130, 290)
    season.size = Vector2(420, 24)
    season.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    center.add_child(season)



    # 世界观句
    var tag := _label("这个世界不是因为存在才被记录，\n而是因为被记录才存在。", 14, Color(0.55, 0.61, 0.68))
    tag.position = Vector2(88, 330)
    tag.size = Vector2(540, 74)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    tag.add_theme_constant_override("line_spacing", 9)
    center.add_child(tag)

    # 系列级副标题：不写具体案卷编号
    var subline := HBoxContainer.new()
    subline.position = Vector2(88, 418)
    subline.size = Vector2(560, 20)
    subline.add_theme_constant_override("separation", 10)
    center.add_child(subline)
    var sbar := ColorRect.new()
    sbar.color = Color(0.886, 0.631, 0.29, 0.45)
    sbar.custom_minimum_size = Vector2(22, 1)
    sbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    subline.add_child(sbar)
    var stext := _label("六个案子 · 一份值班表 · 每个结局都要付账", 10, Color(0.42, 0.50, 0.58))
    stext.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    subline.add_child(stext)

    # 菜单
    var menu := VBoxContainer.new()
    menu.position = Vector2(88, 500)
    menu.size = Vector2(392, 240)
    menu.add_theme_constant_override("separation", 0)
    center.add_child(menu)
    menu_rows.clear()
    menu_rows.append(_menu_row("01", "开始值班", "CLOCK IN", true, func(): start_game.emit()))
    menu_rows.append(_menu_row("02", "载入存档", "LOAD RECORD", false, func(): show_slots("load")))
    menu_rows.append(_menu_row("03", "设置", "SETTINGS", false, func(): _show_settings(true)))
    menu_rows.append(_menu_row("04", "退出", "SIGN OFF", false, func(): quit_game.emit()))
    for b in menu_rows:
        menu.add_child(b)
    for i in range(menu_rows.size()):
        var r: Button = menu_rows[i]
        r.focus_neighbor_top = r.get_path_to(menu_rows[(i + menu_rows.size() - 1) % menu_rows.size()])
        r.focus_neighbor_bottom = r.get_path_to(menu_rows[(i + 1) % menu_rows.size()])
    call_deferred("focus_main")

    # 底部提示
    var hints := _label("↑ ↓  选择     ENTER  确认     ESC  返回", 9, Color(0.35, 0.42, 0.50))
    hints.add_theme_font_override("font", _fvar(0.1, 1))
    hints.position = Vector2(88, 850)
    hints.size = Vector2(520, 20)
    hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    center.add_child(hints)
    var foot := _label("●  外勤支援科 · 夜班", 9, Color(0.36, 0.44, 0.52))
    foot.position = Vector2(1212, 850)
    foot.size = Vector2(300, 20)
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    center.add_child(foot)

func focus_main() -> void:
    if menu_rows.size() > 0 and center.visible:
        var b: Button = menu_rows[0]
        if is_instance_valid(b):
            b.grab_focus()
func _menu_row(idx: String, lb_text: String, en_text: String, primary: bool, cb: Callable) -> Button:
    var h := 62.0 if primary else 56.0
    var b := Button.new()
    b.custom_minimum_size = Vector2(392, h)
    b.focus_mode = Control.FOCUS_ALL
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.add_theme_stylebox_override("focus", _flat_style(Color(0, 0, 0, 0), Color(0.886, 0.631, 0.29, 0.75)))
    b.add_theme_stylebox_override("normal", _row_style(primary, false))
    b.add_theme_stylebox_override("hover", _row_style(primary, true))
    b.add_theme_stylebox_override("pressed", _row_style(primary, true))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.pressed.connect(cb)

    var i := _label(idx, 10, Color(0.75, 0.55, 0.31) if primary else Color(0.38, 0.45, 0.54))
    i.position = Vector2(18, 0)
    i.size = Vector2(36, h)
    i.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    i.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    i.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(i)

    var l := _label(lb_text, 18, Color(1.0, 0.85, 0.64) if primary else Color(0.76, 0.81, 0.87))
    if primary:
        l.add_theme_font_override("font", _fvar(0.35, 0))
    l.position = Vector2(54, 0)
    l.size = Vector2(190, h)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(l)

    var e := _label(en_text, 8, Color(0.66, 0.48, 0.27) if primary else Color(0.34, 0.41, 0.49))
    e.position = Vector2(236, 0)
    e.size = Vector2(112, h)
    e.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    e.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(e)

    var c := _label("›", 15, Color(0.94, 0.73, 0.45) if primary else Color(0.53, 0.60, 0.68))
    c.position = Vector2(356, 0)
    c.size = Vector2(20, h)
    c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(c)
    return b

func _row_style(primary: bool, hover: bool) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.corner_radius_top_left = 0
    sb.corner_radius_top_right = 0
    sb.corner_radius_bottom_left = 0
    sb.corner_radius_bottom_right = 0
    if primary:
        sb.bg_color = Color(0.886, 0.631, 0.29, 0.21 if hover else 0.14)
        sb.border_color = Color(0.886, 0.631, 0.29, 0.95)
        sb.border_width_left = 3
        sb.border_width_bottom = 1
    else:
        sb.bg_color = Color(1, 1, 1, 0.040 if hover else 0.0)
        sb.border_color = Color(1, 1, 1, 0.065)
        sb.border_width_bottom = 1
    return sb

# ------------------------------------------------------------------ 存档槽位
func _build_slots() -> void:
    slots_panel = PanelContainer.new()
    slots_panel.position = Vector2(500, 190)
    slots_panel.size = Vector2(600, 500)
    slots_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(slots_panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    slots_panel.add_child(v)

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 12)
    v.add_child(head)
    var htitle := _label("案卷目录", 24, Color(0.88, 0.64, 0.29))
    htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    head.add_child(htitle)
    var hen := _label("C A S E   F I L E S", 9, Color(0.36, 0.44, 0.52))
    hen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(hen)
    var sub := _label("第一季 · 补丁　/　权限 D　/　0017 岚桥站 · 半秒", 9, Color(0.42, 0.50, 0.58))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    v.add_child(sub)
    v.add_child(_line(548, Color(1, 1, 1, 0.08)))

    for i in range(3):
        var b := _btn("槽位 %d" % (i + 1), 16)
        b.custom_minimum_size = Vector2(500, 62)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func(): _on_slot_pressed(i))
        slot_btns.append(b)
        v.add_child(b)
    var back := _btn("返 回", 16)
    back.custom_minimum_size = Vector2(200, 40)
    back.pressed.connect(func():
        slots_panel.visible = false
        if pause_open:
            pause_panel.visible = true
        else:
            center.visible = true
            focus_main()
    )
    var bh := HBoxContainer.new()
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    bh.add_child(back)
    v.add_child(bh)

func _on_slot_pressed(i: int) -> void:
    if slot_mode == "load":
        load_slot.emit(i)
    else:
        save_slot.emit(i)

func set_slots(info: Array, mode: String) -> void:
    slots_info = info
    slot_mode = mode
    for i in range(slot_btns.size()):
        var b: Button = slot_btns[i]
        var d: Dictionary = info[i]
        if bool(d.get("exists", false)):
            b.text = "槽位 %d　%s　%s\n　　　　%s" % [i + 1, d.get("round", ""), d.get("clock", ""), d.get("time", "")]
        else:
            b.text = "槽位 %d　　空" % (i + 1)
        b.disabled = (mode == "load" and not bool(d.get("exists", false)))

func show_slots(mode: String) -> void:
    slot_mode = mode
    center.visible = false
    sett.visible = false
    slots_panel.visible = true
    for i in range(slot_btns.size()):
        var b: Button = slot_btns[i]
        b.disabled = (mode == "load" and not bool(slots_info[i].get("exists", false)))

# ------------------------------------------------------------------ 设置
func _build_settings() -> void:
    sett = PanelContainer.new()
    sett.position = Vector2(500, 150)
    sett.size = Vector2(600, 600)
    sett.add_theme_stylebox_override("panel", _panel_style())
    add_child(sett)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    sett.add_child(v)
    var st := _label("设 置", 26, Color(0.88, 0.64, 0.29))
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    v.add_child(st)
    music_slider = _slider(v, "音乐音量", float(cfg.get_value("audio", "music", 0.8)))
    sfx_slider = _slider(v, "音效音量", float(cfg.get_value("audio", "sfx", 1.0)))
    sens_slider = _slider(v, "鼠标灵敏度", float(cfg.get_value("input", "sens", 1.0)))
    fog_slider = _slider(v, "雾气浓度", float(cfg.get_value("render", "fog", 1.0)))
    bright_slider = _slider(v, "画面亮度", float(cfg.get_value("render", "bright", 1.0)))
    sub_slider = _slider(v, "字幕速度", float(cfg.get_value("text", "speed", 1.0)))
    fs_btn = _btn("显示模式：窗口", 16)
    fs_btn.custom_minimum_size = Vector2(300, 42)
    fs_btn.pressed.connect(func():
        var fs := DisplayServer.window_get_mode()
        var on := fs != DisplayServer.WINDOW_MODE_FULLSCREEN
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
        fs_btn.text = "显示模式：全屏" if on else "显示模式：窗口"
    )
    var fh := HBoxContainer.new()
    fh.alignment = BoxContainer.ALIGNMENT_CENTER
    fh.add_child(fs_btn)
    v.add_child(fh)
    var back := _btn("保 存 并 返 回", 16)
    back.custom_minimum_size = Vector2(260, 42)
    back.pressed.connect(func():
        _save_settings()
        apply_audio()
        _show_settings(false)
    )
    var bh := HBoxContainer.new()
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    bh.add_child(back)
    v.add_child(bh)

func _show_settings(on: bool) -> void:
    settings_open = on
    sett.visible = on
    slots_panel.visible = false
    if on:
        center.visible = false
        pause_panel.visible = false
    else:
        if pause_open:
            pause_panel.visible = true
        else:
            center.visible = true
            focus_main()

func show_pause() -> void:
    pause_open = true
    center.visible = false
    sett.visible = false
    slots_panel.visible = false
    pause_panel.visible = true

# ------------------------------------------------------------------ 暂停
func _build_pause() -> void:
    pause_panel = PanelContainer.new()
    pause_panel.position = Vector2(620, 260)
    pause_panel.size = Vector2(360, 360)
    pause_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(pause_panel)
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 10)
    pause_panel.add_child(v)
    v.add_child(_label("暂 停", 26, Color(0.88, 0.64, 0.29)))
    var b1 := _btn("继 续", 16)
    var b2 := _btn("存 档", 16)
    var b3 := _btn("设 置", 16)
    var b4 := _btn("回 主 菜 单", 16)
    for b in [b1, b2, b3, b4]:
        b.custom_minimum_size = Vector2(300, 42)
        v.add_child(b)
    b1.pressed.connect(func(): hide_all(); resume_game.emit())
    b2.pressed.connect(func(): _pause_wants_save.emit())
    b3.pressed.connect(func(): _show_settings(true))
    b4.pressed.connect(func(): hide_all(); to_menu.emit())

signal _pause_wants_save

func hide_all() -> void:
    pause_open = false
    pause_panel.visible = false
    sett.visible = false
    slots_panel.visible = false
    settings_open = false
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
        if settings_open:
            _save_settings()
            apply_audio()
            _show_settings(false)





