extends Control
## 主菜单 / 存档 / 设置 / 暂停菜单
## 主菜单层级：诡异事务局（系列）→ 第一季「补丁」；具体案卷与权限只放在存档页

const Archive := preload("res://scripts/archive.gd")

signal start_game
signal load_slot(index)
signal save_slot(index)
signal delete_slot(index)
signal resume_game
signal to_menu
signal quit_game
signal recover_player
signal auto_continue
var auto_button: Button
signal settings_changed

var font: Font
var cfg := ConfigFile.new()
var slots_info: Array = []
var slot_mode := "load"
var settings_open := false
var pause_open := false
var center: Control
var slots_panel: Control
var slot_btns: Array = []
var slot_delete_btns: Array = []
var case_rows: Array = []
var archive_summary: Label
var archive_summary_sub: Label
var archive_note: Label
var mode_hint: Label
var season_pips: Array = []
var ending_chips: Array = []
var pending_delete := -1
var pending_delete_t := 0.0
var _web_import_cb = null
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
var pause_dim: ColorRect

func setup(f: Font) -> void:
    font = f
    _load_settings()
    _build_poster()
    _build_main()
    _build_slots()
    _build_settings()
    _build_pause()
    for slider in [music_slider, sfx_slider, sens_slider, fog_slider, bright_slider, sub_slider]:
        slider.value_changed.connect(func(_value):
            _save_settings()
            settings_changed.emit())
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
    for bus_name in ["Voice", "Ambience"]:
        var index := AudioServer.get_bus_index(bus_name)
        var level: float = c["music"] if bus_name == "Ambience" else c["sfx"]
        if index >= 0:
            AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))
            AudioServer.set_bus_mute(index, level < 0.01)


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
    l.add_theme_font_size_override("font_size", maxi(fs, 12))
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

## 细线幽灵按钮：只留底边，适合「导出/导入/返回」这类次级动作
func _ghost_style(bg: Color, border: Color, left_w := 0, bottom_w := 1) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.border_width_left = left_w
    sb.border_width_top = 0
    sb.border_width_right = 0
    sb.border_width_bottom = bottom_w
    sb.content_margin_left = 14
    sb.content_margin_right = 14
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    return sb

## 状态小标签（已结案 / 进行中 / 未开始 / 尚未开启）
func _chip_style(fill: Color, border: Color, mx := 8, my := 2) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = fill
    sb.border_color = border
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.content_margin_left = mx
    sb.content_margin_right = mx
    sb.content_margin_top = my
    sb.content_margin_bottom = my
    return sb

func _primary_btn(text: String, fs := 15) -> Button:
    var b := _btn(text, fs)
    b.add_theme_stylebox_override("normal", _ghost_style(Color(0.886, 0.631, 0.29, 0.13), Color(0.886, 0.631, 0.29, 0.62), 3, 1))
    b.add_theme_stylebox_override("hover", _ghost_style(Color(0.886, 0.631, 0.29, 0.20), Color(0.886, 0.631, 0.29, 0.85), 3, 1))
    b.add_theme_stylebox_override("pressed", _ghost_style(Color(0.886, 0.631, 0.29, 0.26), Color(0.886, 0.631, 0.29, 0.95), 3, 1))
    b.add_theme_color_override("font_color", Color(0.96, 0.84, 0.66))
    return b

func _panel_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.042, 0.068, 0.071, 0.98)
    sb.border_color = Color(0.52, 0.59, 0.52, 0.42)
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
    row.custom_minimum_size = Vector2(520, 30)
    row.add_theme_constant_override("separation", 12)
    var lb := _label(label, 13, Color(0.70, 0.78, 0.87))
    lb.custom_minimum_size = Vector2(112, 28)
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 100.0
    s.step = 1.0
    s.value = value * 100.0
    s.custom_minimum_size = Vector2(330, 22)
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var track := StyleBoxFlat.new()
    track.bg_color = Color(1, 1, 1, 0.09)
    track.content_margin_top = 2
    track.content_margin_bottom = 2
    s.add_theme_stylebox_override("slider", track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.886, 0.631, 0.29, 0.55)
    fill.content_margin_top = 2
    fill.content_margin_bottom = 2
    s.add_theme_stylebox_override("grabber_area", fill)
    s.add_theme_stylebox_override("grabber_area_highlight", fill)
    var val := _label("%d%%" % int(s.value), 10, Color(0.50, 0.58, 0.66))
    val.custom_minimum_size = Vector2(44, 28)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    s.value_changed.connect(func(v): val.text = "%d%%" % int(v))
    row.add_child(lb)
    row.add_child(s)
    row.add_child(val)
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
    var title := _label("诡异事务局", 80, Color(0.94, 0.92, 0.86))
    title.add_theme_font_override("font", _fvar(0.15, 2))
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
    var tag := _label("这个世界不是因为存在才被记录，\n而是因为被记录才存在。", 17, Color(0.65, 0.70, 0.69))
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

    auto_button = _btn("继续自动保存（暂无）", 16)
    auto_button.position = Vector2(88, 750)
    auto_button.size = Vector2(392, 48)
    auto_button.disabled = true
    auto_button.pressed.connect(func(): auto_continue.emit())
    center.add_child(auto_button)

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
    var case_card := Panel.new()
    case_card.position = Vector2(1040, 700)
    case_card.size = Vector2(472, 110)
    case_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    case_card.add_theme_stylebox_override("panel", _flat_style(Color(0.04, 0.065, 0.067, 0.93), Color(0.50, 0.57, 0.49, 0.38)))
    center.add_child(case_card)
    var dossier := _label("当前值班  /  案卷 00184", 12, Color(0.68, 0.70, 0.60))
    dossier.position = Vector2(22, 14)
    dossier.size = Vector2(426, 22)
    dossier.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    case_card.add_child(dossier)
    var case_name := _label("得利洗衣店", 26, Color(0.94, 0.90, 0.80))
    case_name.position = Vector2(22, 45)
    case_name.size = Vector2(260, 40)
    case_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    case_card.add_child(case_name)
    var shift := _label("第一夜\n23:40 — 04:02", 12, Color(0.63, 0.72, 0.68))
    shift.position = Vector2(294, 49)
    shift.size = Vector2(154, 42)
    shift.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    case_card.add_child(shift)

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

    var l := _label(lb_text, 21, Color(1.0, 0.85, 0.64) if primary else Color(0.81, 0.84, 0.80))
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

# ------------------------------------------------------------------ 案卷目录 / 存档槽位
func _build_slots() -> void:
    preload("res://scripts/case_slots_ui.gd").build(self)

func _build_legacy_slots() -> void:
    slots_panel = PanelContainer.new()
    slots_panel.position = Vector2(300, 60)
    slots_panel.size = Vector2(1000, 780)
    slots_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(slots_panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    slots_panel.add_child(v)

    # 顶部金色细线：档案室纸张的「装订线」
    v.add_child(_line(948, Color(0.886, 0.631, 0.29, 0.34)))

    # 标题行：案卷目录 + 档案导出/导入
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 12)
    v.add_child(head)
    var htitle := _label("案卷目录", 24, Color(0.93, 0.78, 0.52))
    htitle.add_theme_font_override("font", _fvar(0.35, 1))
    htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    head.add_child(htitle)
    var hen := _label("C A S E   F I L E S", 9, Color(0.36, 0.44, 0.52))
    hen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(hen)
    var hgap := Control.new()
    hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(hgap)
    head.add_child(_ghost_btn("导出档案", func(): _export_archive()))
    var vsep := ColorRect.new()
    vsep.color = Color(1, 1, 1, 0.10)
    vsep.custom_minimum_size = Vector2(1, 16)
    vsep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(vsep)
    head.add_child(_ghost_btn("导入档案", func(): _import_archive()))

    # 副标题 + 当前模式
    var subrow := HBoxContainer.new()
    subrow.add_theme_constant_override("separation", 12)
    v.add_child(subrow)
    var sub := _label("第一季 · 补丁　/　权限 D　/　档案室 · 长期记录", 9, Color(0.42, 0.50, 0.58))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    subrow.add_child(sub)
    mode_hint = _label("载入模式", 9, Color(0.76, 0.58, 0.34))
    subrow.add_child(mode_hint)

    # 汇总条：左边大数字，右边六案进度 + A/B/C 结局章
    var strip := HBoxContainer.new()
    strip.custom_minimum_size = Vector2(948, 46)
    strip.add_theme_constant_override("separation", 18)
    v.add_child(strip)
    var sum_v := VBoxContainer.new()
    sum_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sum_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    sum_v.add_theme_constant_override("separation", 0)
    archive_summary = _label("已结案 0/6 · 结局 0/3", 17, Color(0.93, 0.72, 0.40))
    archive_summary.add_theme_font_override("font", _fvar(0.45, 1))
    archive_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    sum_v.add_child(archive_summary)
    archive_summary_sub = _label("S E A S O N   P R O G R E S S   ·   0 0 1 7 — 0 0 2 2", 8, Color(0.37, 0.44, 0.51))
    archive_summary_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    sum_v.add_child(archive_summary_sub)
    strip.add_child(sum_v)

    var pips := HBoxContainer.new()
    pips.add_theme_constant_override("separation", 5)
    pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    season_pips.clear()
    for i in range(6):
        var pip := PanelContainer.new()
        pip.custom_minimum_size = Vector2(26, 7)
        pip.add_theme_stylebox_override("panel", _flat_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.10)))
        pips.add_child(pip)
        season_pips.append(pip)
    strip.add_child(pips)

    var end_box := HBoxContainer.new()
    end_box.add_theme_constant_override("separation", 4)
    end_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var end_lb := _label("结局", 8, Color(0.42, 0.49, 0.56))
    end_lb.custom_minimum_size = Vector2(26, 20)
    end_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    end_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    end_box.add_child(end_lb)
    ending_chips.clear()
    for key in Archive.ENDING_KEYS:
        var chip := PanelContainer.new()
        chip.custom_minimum_size = Vector2(20, 20)
        chip.add_theme_stylebox_override("panel", _chip_style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.12)))
        var cl := _label(str(key), 9, Color(0.40, 0.47, 0.54))
        cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        chip.add_child(cl)
        end_box.add_child(chip)
        ending_chips.append({"panel": chip, "label": cl})
    strip.add_child(end_box)
    v.add_child(_line(948, Color(1, 1, 1, 0.08)))

    # 案卷列表：0017 动态状态；0018–0022 与终章「尚未开启」
    case_rows.clear()
    for c in Archive.CASES:
        v.add_child(_case_row(c))
    v.add_child(_line(948, Color(1, 1, 1, 0.08)))

    # 槽位标题
    var slot_head := HBoxContainer.new()
    slot_head.add_theme_constant_override("separation", 10)
    v.add_child(slot_head)
    var slot_title := _label("存档槽位", 10, Color(0.60, 0.68, 0.76))
    slot_title.add_theme_font_override("font", _fvar(0.2, 1))
    slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    slot_head.add_child(slot_title)
    var slot_en := _label("S A V E   S L O T S", 8, Color(0.34, 0.41, 0.48))
    slot_en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    slot_head.add_child(slot_en)
    var sgap := Control.new()
    sgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slot_head.add_child(sgap)
    var slot_hint := _label("只存单局现场 · 删除不影响档案", 8, Color(0.42, 0.49, 0.56))
    slot_head.add_child(slot_hint)

    for i in range(3):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        var b := _btn("槽位 %d" % (i + 1), 13)
        b.custom_minimum_size = Vector2(846, 50)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.add_theme_stylebox_override("normal", _ghost_style(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.09), 0, 1))
        b.add_theme_stylebox_override("hover", _ghost_style(Color(0.886, 0.631, 0.29, 0.08), Color(0.886, 0.631, 0.29, 0.55), 2, 1))
        b.add_theme_stylebox_override("pressed", _ghost_style(Color(0.886, 0.631, 0.29, 0.14), Color(0.886, 0.631, 0.29, 0.80), 2, 1))
        b.add_theme_color_override("font_color", Color(0.80, 0.85, 0.90))
        b.pressed.connect(func(): _on_slot_pressed(i))
        slot_btns.append(b)
        row.add_child(b)
        var del := _btn("删除", 11)
        del.custom_minimum_size = Vector2(84, 30)
        del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        del.add_theme_stylebox_override("normal", _ghost_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.08), 0, 1))
        del.add_theme_stylebox_override("hover", _ghost_style(Color(0.60, 0.22, 0.18, 0.22), Color(0.78, 0.34, 0.28, 0.60), 0, 1))
        del.add_theme_stylebox_override("pressed", _ghost_style(Color(0.60, 0.22, 0.18, 0.32), Color(0.78, 0.34, 0.28, 0.80), 0, 1))
        del.add_theme_color_override("font_color", Color(0.60, 0.52, 0.52))
        del.add_theme_color_override("font_hover_color", Color(0.92, 0.68, 0.60))
        del.add_theme_color_override("font_disabled_color", Color(0.30, 0.34, 0.38))
        del.add_theme_stylebox_override("disabled", _ghost_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.035), 0, 1))
        del.pressed.connect(func(): _on_delete_pressed(i))
        slot_delete_btns.append(del)
        row.add_child(del)
        v.add_child(row)

    # 把页脚压到面板底部
    var fill := Control.new()
    fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(fill)

    var foot := HBoxContainer.new()
    foot.add_theme_constant_override("separation", 12)
    v.add_child(foot)
    archive_note = _label("", 9, Color(0.48, 0.56, 0.64))
    archive_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    archive_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    archive_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    foot.add_child(archive_note)
    var esc := _label("ESC  返 回", 7, Color(0.34, 0.41, 0.48))
    esc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    foot.add_child(esc)
    var back := _ghost_btn("返 回", func():
        slots_panel.visible = false
        if pause_open:
            pause_panel.visible = true
        else:
            center.visible = true
            focus_main()
    )
    back.custom_minimum_size = Vector2(96, 32)
    foot.add_child(back)

func _ghost_btn(text: String, cb: Callable) -> Button:
    var b := _btn(text, 10)
    b.custom_minimum_size = Vector2(88, 28)
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    b.add_theme_stylebox_override("normal", _ghost_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.10), 0, 1))
    b.add_theme_stylebox_override("hover", _ghost_style(Color(0.886, 0.631, 0.29, 0.10), Color(0.886, 0.631, 0.29, 0.62), 0, 1))
    b.add_theme_stylebox_override("pressed", _ghost_style(Color(0.886, 0.631, 0.29, 0.18), Color(0.886, 0.631, 0.29, 0.85), 0, 1))
    b.add_theme_color_override("font_color", Color(0.70, 0.76, 0.82))
    b.pressed.connect(cb)
    return b

func _case_row(c: Dictionary) -> Control:
    var is_open := bool(c.get("open", false))
    var row := PanelContainer.new()
    row.custom_minimum_size = Vector2(948, 44)
    var sb: StyleBoxFlat
    if is_open:
        sb = _flat_style(Color(0.886, 0.631, 0.29, 0.045), Color(0.886, 0.631, 0.29, 0.55))
        sb.border_width_left = 2
        sb.border_width_top = 0
        sb.border_width_right = 0
        sb.border_width_bottom = 1
    else:
        sb = _flat_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.055))
        sb.border_width_left = 0
        sb.border_width_top = 0
        sb.border_width_right = 0
        sb.border_width_bottom = 1
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 3
    sb.content_margin_bottom = 3
    row.add_theme_stylebox_override("panel", sb)

    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    row.add_child(h)

    var no := _label(str(c.get("no", "")), 11, Color(0.75, 0.55, 0.31) if is_open else Color(0.40, 0.46, 0.53))
    no.add_theme_font_override("font", _fvar(0.15, 1))
    no.custom_minimum_size = Vector2(56, 36)
    no.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    no.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    h.add_child(no)

    var mid := VBoxContainer.new()
    mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    mid.add_theme_constant_override("separation", 0)
    var t := _label(str(c.get("title", "")), 14, Color(0.86, 0.90, 0.95))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    mid.add_child(t)
    var s := _label(str(c.get("sub", "")), 8, Color(0.40, 0.46, 0.53))
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    mid.add_child(s)
    h.add_child(mid)

    # 状态章：已结案 / 进行中 / 未开始 / 尚未开启
    var st_chip := PanelContainer.new()
    st_chip.custom_minimum_size = Vector2(86, 24)
    st_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    st_chip.add_theme_stylebox_override("panel", _chip_style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.12)))
    var st := _label("尚未开启", 10, Color(0.42, 0.48, 0.55))
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    st_chip.add_child(st)
    h.add_child(st_chip)

    # 结局位：A/B/C 三枚小章 + 已见 X/3
    var end_box := HBoxContainer.new()
    end_box.custom_minimum_size = Vector2(196, 36)
    end_box.add_theme_constant_override("separation", 4)
    end_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var end_chips: Array = []
    for key in Archive.ENDING_KEYS:
        var chip := PanelContainer.new()
        chip.custom_minimum_size = Vector2(18, 18)
        chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        chip.add_theme_stylebox_override("panel", _chip_style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.10)))
        var cl := _label(str(key), 8, Color(0.38, 0.44, 0.51))
        cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        chip.add_child(cl)
        end_box.add_child(chip)
        end_chips.append({"panel": chip, "label": cl})
    var ends := _label("", 9, Color(0.55, 0.63, 0.71))
    ends.custom_minimum_size = Vector2(104, 36)
    ends.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ends.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    end_box.add_child(ends)
    h.add_child(end_box)

    case_rows.append({
        "def": c, "row": row, "no": no, "title": t, "sub": s,
        "status": st, "status_chip": st_chip, "ends": ends, "end_chips": end_chips,
    })
    return row

func _on_slot_pressed(i: int) -> void:
    if slot_mode == "load":
        load_slot.emit(i)
    else:
        save_slot.emit(i)

func _on_delete_pressed(i: int) -> void:
    if i < 0 or i >= slot_btns.size():
        return
    if not bool(slots_info[i].get("exists", false)):
        set_archive_note("槽位 %d 是空的，没有可删除的存档。" % (i + 1))
        return
    if pending_delete == i:
        _reset_pending_delete()
        delete_slot.emit(i)
        return
    _reset_pending_delete()
    pending_delete = i
    pending_delete_t = 4.0
    slot_delete_btns[i].text = "确认删除"
    set_archive_note("再点一次「确认删除」：只删槽位 %d，档案记录保留。" % (i + 1))

func _reset_pending_delete() -> void:
    if pending_delete >= 0 and pending_delete < slot_delete_btns.size():
        slot_delete_btns[pending_delete].text = "删除"
    pending_delete = -1
    pending_delete_t = 0.0

func _process(delta: float) -> void:
    if pause_dim != null:
        pause_dim.visible = pause_open
        poster.visible = not pause_open
    if pending_delete >= 0:
        pending_delete_t -= delta
        if pending_delete_t <= 0.0:
            _reset_pending_delete()

func set_slots(info: Array, mode: String) -> void:
    slots_info = info
    slot_mode = mode
    refresh_archive()
    _refresh_mode_hint()
    _refresh_slot_texts()

func _refresh_slot_texts() -> void:
    for i in range(slot_btns.size()):
        var b: Button = slot_btns[i]
        var d: Dictionary = slots_info[i] if i < slots_info.size() else {"exists": false}
        var exists: bool = bool(d.get("exists", false))
        if exists:
            b.text = "槽位 %d　·　%s　%s\n　　　　　%s" % [i + 1, d.get("round", ""), d.get("clock", ""), d.get("time", "")]
            b.add_theme_color_override("font_color", Color(0.82, 0.87, 0.92))
        else:
            b.text = "槽位 %d　·　空" % (i + 1)
            if slot_mode == "save":
                b.text += "　·　点击写入"
                b.add_theme_color_override("font_color", Color(0.90, 0.77, 0.56))
            else:
                b.add_theme_color_override("font_color", Color(0.56, 0.62, 0.69))
        _style_slot_btn(b, exists)
        b.disabled = (slot_mode == "load" and (not exists or bool(d.get("legacy", false))))
        if i < slot_delete_btns.size():
            slot_delete_btns[i].disabled = not exists

func _style_slot_btn(b: Button, exists: bool) -> void:
    if exists:
        b.add_theme_stylebox_override("normal", _ghost_style(Color(0.886, 0.631, 0.29, 0.035), Color(0.886, 0.631, 0.29, 0.34), 2, 1))
    else:
        b.add_theme_stylebox_override("normal", _ghost_style(Color(1, 1, 1, 0.012), Color(1, 1, 1, 0.07), 0, 1))
    b.add_theme_stylebox_override("disabled", _ghost_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.04), 0, 1))
    b.add_theme_stylebox_override("hover", _ghost_style(Color(0.886, 0.631, 0.29, 0.09), Color(0.886, 0.631, 0.29, 0.58), 2, 1))
    b.add_theme_stylebox_override("pressed", _ghost_style(Color(0.886, 0.631, 0.29, 0.16), Color(0.886, 0.631, 0.29, 0.82), 2, 1))

func show_slots(mode: String) -> void:
    slot_mode = mode
    _reset_pending_delete()
    center.visible = false
    pause_panel.visible = false
    sett.visible = false
    slots_panel.visible = true
    refresh_archive()
    _refresh_mode_hint()
    _refresh_slot_texts()
    for button in slot_btns:
        if not button.disabled:
            button.grab_focus()
            break

func _refresh_mode_hint() -> void:
    if mode_hint == null:
        return
    mode_hint.text = "载入模式 · 选择槽位继续" if slot_mode == "load" else "存档模式 · 选择槽位写入"

# ------------------------------------------------------------------ 档案：显示 / 导出 / 导入
func _set_chip(chip: Dictionary, fill: Color, border: Color, font_col: Color) -> void:
    var p: PanelContainer = chip["panel"]
    var l: Label = chip["label"]
    # 结局章（A/B/C）比较小，收紧内边距；状态章用默认 8px
    var mx := 2 if p.custom_minimum_size.x <= 22 else 8
    p.add_theme_stylebox_override("panel", _chip_style(fill, border, mx, 2))
    l.add_theme_color_override("font_color", font_col)

func _set_status_chip(chip: Dictionary, text: String, tone: String) -> void:
    var l: Label = chip["label"]
    l.text = text
    match tone:
        "done":
            _set_chip(chip, Color(0.886, 0.631, 0.29, 0.15), Color(0.886, 0.631, 0.29, 0.60), Color(0.98, 0.82, 0.55))
        "active":
            _set_chip(chip, Color(0.36, 0.60, 0.78, 0.13), Color(0.42, 0.66, 0.84, 0.48), Color(0.66, 0.84, 0.96))
        "idle":
            _set_chip(chip, Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.13), Color(0.52, 0.59, 0.66))
        _:
            _set_chip(chip, Color(0, 0, 0, 0), Color(1, 1, 1, 0.07), Color(0.36, 0.42, 0.48))

func refresh_archive() -> void:
    if case_rows.is_empty():
        var progress := preload("res://scripts/case_save.gd").read_progress()
        var completed: bool = progress.get("campaign_version",0)==3 and progress.get("endings",[]).has("A")
        archive_summary.text = "第一案 · 唯一结局   ·   %s" % ("已认领 / 已归档" if completed else "三夜调查中")
        return
    var d := Archive.load_data()
    if archive_summary != null:
        archive_summary.text = Archive.summary_text(d)
    var cases: Dictionary = d.get("cases", {})

    # 六案进度条：金=已结案，蓝=进行中，灰=未开始/尚未开启
    for i in range(season_pips.size()):
        if i >= Archive.CASES.size():
            break
        var cdef: Dictionary = Archive.CASES[i]
        var e: Dictionary = cases.get(cdef["id"], Archive.empty_case())
        var fill := Color(1, 1, 1, 0.05)
        var border := Color(1, 1, 1, 0.10)
        if bool(e.get("completed", false)):
            fill = Color(0.886, 0.631, 0.29, 0.62)
            border = Color(0.886, 0.631, 0.29, 0.90)
        elif bool(e.get("started", false)):
            fill = Color(0.42, 0.66, 0.84, 0.55)
            border = Color(0.42, 0.66, 0.84, 0.75)
        season_pips[i].add_theme_stylebox_override("panel", _flat_style(fill, border))

    # 0017 的 A/B/C 结局章
    var first: Dictionary = cases.get("0017", Archive.empty_case())
    var first_ends: Array = first.get("endings", [])
    for j in range(ending_chips.size()):
        var key: String = Archive.ENDING_KEYS[j]
        if first_ends.has(key):
            _set_chip(ending_chips[j], Color(0.886, 0.631, 0.29, 0.20), Color(0.886, 0.631, 0.29, 0.70), Color(0.99, 0.84, 0.58))
        else:
            _set_chip(ending_chips[j], Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.10), Color(0.36, 0.42, 0.49))

    for row in case_rows:
        var c: Dictionary = row["def"]
        var e: Dictionary = cases.get(c.get("id", ""), Archive.empty_case())
        var title_label: Label = row["title"]
        var sub_label: Label = row["sub"]
        var status_label: Label = row["status"]
        var ends_label: Label = row["ends"]
        var no_label: Label = row["no"]
        var row_panel: PanelContainer = row["row"]
        var status_chip: Dictionary = {"panel": row["status_chip"], "label": row["status"]}
        var end_chips: Array = row["end_chips"]

        if not bool(c.get("open", false)):
            var lsb := _flat_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.055))
            lsb.border_width_left = 0
            lsb.border_width_top = 0
            lsb.border_width_right = 0
            lsb.border_width_bottom = 1
            lsb.content_margin_left = 12
            lsb.content_margin_right = 12
            lsb.content_margin_top = 3
            lsb.content_margin_bottom = 3
            row_panel.add_theme_stylebox_override("panel", lsb)
            title_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75))
            no_label.add_theme_color_override("font_color", Color(0.38, 0.44, 0.51))
            sub_label.text = str(c.get("sub", ""))
            sub_label.add_theme_color_override("font_color", Color(0.37, 0.43, 0.49))
            _set_status_chip(status_chip, "尚未开启", "locked")
            ends_label.text = ""
            for chip in end_chips:
                var p: PanelContainer = chip["panel"]
                p.visible = false
            continue

        # 0017：未开始 / 进行中 / 已结案 + 已见 X/3 结局
        var status := Archive.status_of(e)
        var seen := Archive.endings_seen(e)
        var tone := "idle"
        var accent := Color(1, 1, 1, 0.18)
        var bg := Color(0, 0, 0, 0)
        if status == "已结案":
            tone = "done"
            accent = Color(0.886, 0.631, 0.29, 0.72)
            bg = Color(0.886, 0.631, 0.29, 0.055)
        elif status == "进行中":
            tone = "active"
            accent = Color(0.42, 0.66, 0.84, 0.55)
            bg = Color(0.36, 0.60, 0.78, 0.045)
        _set_status_chip(status_chip, status, tone)
        ends_label.text = "已见 %d/%d 结局" % [seen, Archive.ENDING_KEYS.size()]

        # 行样式：左侧色条跟着状态走
        var sb := _flat_style(bg, accent)
        sb.border_width_left = 2
        sb.border_width_top = 0
        sb.border_width_right = 0
        sb.border_width_bottom = 1
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        sb.content_margin_top = 3
        sb.content_margin_bottom = 3
        row_panel.add_theme_stylebox_override("panel", sb)

        title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97) if status != "未开始" else Color(0.74, 0.80, 0.86))
        no_label.add_theme_color_override("font_color", Color(0.86, 0.66, 0.39) if status != "未开始" else Color(0.62, 0.50, 0.35))

        for j in range(end_chips.size()):
            var key: String = Archive.ENDING_KEYS[j]
            var p: PanelContainer = end_chips[j]["panel"]
            p.visible = true
            if e.get("endings", []).has(key):
                _set_chip(end_chips[j], Color(0.886, 0.631, 0.29, 0.22), Color(0.886, 0.631, 0.29, 0.72), Color(0.99, 0.84, 0.58))
            else:
                _set_chip(end_chips[j], Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.10), Color(0.36, 0.42, 0.49))

        # 最佳记录：轮次 + 时钟（只在有进度时显示）
        var bits := PackedStringArray([str(c.get("sub", ""))])
        var best_r := int(e.get("best_round", -1))
        var best_c := float(e.get("best_clock", -1.0))
        if bool(e.get("started", false)) or int(e.get("plays", 0)) > 0:
            bits.append("游玩 %d 次" % int(e.get("plays", 0)))
            if best_r >= 0:
                bits.append("最佳：第 %d 轮" % (best_r + 1))
            if best_c > 0.0:
                bits.append(Archive.clock_text(best_c))
        sub_label.text = "　·　".join(bits)
        sub_label.add_theme_color_override("font_color", Color(0.42, 0.49, 0.56))

func set_archive_note(text: String) -> void:
    if archive_note != null:
        archive_note.text = text

func _export_archive() -> void:
    var text := Archive.export_text()
    # 始终留一份在 user://，便于排查；桌面端再让玩家选路径。
    Archive.export_to_file()
    if OS.has_feature("web"):
        var jb = Engine.get_singleton("JavaScriptBridge")
        if jb != null:
            jb.download_buffer(text.to_utf8_buffer(), "anomaly_bureau_archive.json")
            set_archive_note("档案已导出（浏览器下载 anomaly_bureau_archive.json）。")
        else:
            set_archive_note("导出失败：浏览器桥不可用。")
        return
    var dlg := FileDialog.new()
    dlg.title = "导出档案"
    dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dlg.access = FileDialog.ACCESS_FILESYSTEM
    dlg.use_native_dialog = true
    dlg.filters = PackedStringArray(["*.json ; 档案 JSON"])
    dlg.current_file = "anomaly_bureau_archive.json"
    dlg.file_selected.connect(func(path: String):
        var f := FileAccess.open(path, FileAccess.WRITE)
        if f == null:
            set_archive_note("导出失败：无法写入该路径。")
        else:
            f.store_string(text)
            f.close()
            set_archive_note("档案已导出到 " + path)
        dlg.queue_free()
    )
    dlg.canceled.connect(func(): dlg.queue_free())
    add_child(dlg)
    dlg.popup_centered_ratio(0.6)

func _import_archive() -> void:
    if OS.has_feature("web"):
        _import_archive_web()
        return
    var dlg := FileDialog.new()
    dlg.title = "导入档案"
    dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dlg.access = FileDialog.ACCESS_FILESYSTEM
    dlg.use_native_dialog = true
    dlg.filters = PackedStringArray(["*.json ; 档案 JSON"])
    dlg.file_selected.connect(func(path: String):
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null:
            set_archive_note("导入失败：无法读取该文件。")
        else:
            var txt := f.get_as_text()
            f.close()
            _apply_import_text(txt)
        dlg.queue_free()
    )
    dlg.canceled.connect(func(): dlg.queue_free())
    add_child(dlg)
    dlg.popup_centered_ratio(0.6)

func _import_archive_web() -> void:
    var jb = Engine.get_singleton("JavaScriptBridge")
    if jb == null:
        set_archive_note("导入失败：浏览器桥不可用。")
        return
    if _web_import_cb == null:
        _web_import_cb = jb.create_callback(_on_web_import_text)
    var win = jb.get_interface("window")
    if win != null:
        win.set("__dshArchiveImport", _web_import_cb)
    jb.eval("""
    (function () {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = '.json,application/json';
      input.style.display = 'none';
      document.body.appendChild(input);
      input.onchange = function () {
        var file = input.files && input.files[0];
        if (!file) { document.body.removeChild(input); return; }
        var reader = new FileReader();
        reader.onload = function () {
          if (window.__dshArchiveImport) window.__dshArchiveImport(String(reader.result));
          document.body.removeChild(input);
        };
        reader.readAsText(file);
      };
      input.click();
    })();
    """, true)
    set_archive_note("请选择要导入的档案 JSON。")

func _on_web_import_text(args: Array) -> void:
    if args.is_empty():
        return
    _apply_import_text(str(args[0]))

func _apply_import_text(text: String) -> void:
    var res := Archive.import_text(text)
    if bool(res.get("ok", false)):
        refresh_archive()
        var added := int(res.get("added_endings", 0))
        if added > 0:
            set_archive_note("档案已导入并合并，新增 %d 个结局。" % added)
        else:
            set_archive_note("档案已导入并合并。")
    else:
        set_archive_note("导入失败：" + str(res.get("error", "未知错误")))

# ------------------------------------------------------------------ 设置
func _build_settings() -> void:
    sett = PanelContainer.new()
    sett.position = Vector2(500, 200)
    sett.size = Vector2(600, 500)
    sett.add_theme_stylebox_override("panel", _panel_style())
    add_child(sett)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    sett.add_child(v)
    v.add_child(_line(548, Color(0.886, 0.631, 0.29, 0.30)))
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 10)
    v.add_child(head)
    var st := _label("设 置", 24, Color(0.93, 0.78, 0.52))
    st.add_theme_font_override("font", _fvar(0.35, 1))
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    head.add_child(st)
    var se := _label("S E T T I N G S", 9, Color(0.36, 0.44, 0.52))
    se.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(se)
    var sub := _label("声音 / 输入 / 渲染 / 文本　·　修改后立即生效", 9, Color(0.44, 0.52, 0.60))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    v.add_child(sub)
    v.add_child(_line(548, Color(1, 1, 1, 0.08)))

    music_slider = _slider(v, "音乐音量", float(cfg.get_value("audio", "music", 0.8)))
    sfx_slider = _slider(v, "音效音量", float(cfg.get_value("audio", "sfx", 1.0)))
    sens_slider = _slider(v, "鼠标灵敏度", float(cfg.get_value("input", "sens", 1.0)))
    sens_slider.min_value = 20
    sens_slider.max_value = 200
    fog_slider = _slider(v, "雾气浓度", float(cfg.get_value("render", "fog", 1.0)))
    bright_slider = _slider(v, "画面亮度", float(cfg.get_value("render", "bright", 1.0)))
    bright_slider.min_value = 40
    bright_slider.max_value = 150
    sub_slider = _slider(v, "字幕速度", float(cfg.get_value("text", "speed", 1.0)))
    sub_slider.min_value = 30
    sub_slider.max_value = 200

    v.add_child(_line(548, Color(1, 1, 1, 0.08)))
    fs_btn = _ghost_btn("显示模式：窗口", func():
        var fs := DisplayServer.window_get_mode()
        var on := fs != DisplayServer.WINDOW_MODE_FULLSCREEN
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
        fs_btn.text = "显示模式：全屏" if on else "显示模式：窗口"
    )
    fs_btn.custom_minimum_size = Vector2(300, 36)
    var fh := HBoxContainer.new()
    fh.alignment = BoxContainer.ALIGNMENT_CENTER
    fh.add_child(fs_btn)
    v.add_child(fh)

    var back := _primary_btn("保 存 并 返 回", 15)
    back.custom_minimum_size = Vector2(300, 40)
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
        music_slider.grab_focus()
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
    var stack := pause_panel.get_child(0)
    for child in stack.get_children():
        if child is Button:
            child.grab_focus()
            break

# ------------------------------------------------------------------ 暂停
func _build_pause() -> void:
    pause_dim = ColorRect.new()
    pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_dim.color = Color(0.01, 0.02, 0.025, 0.78)
    pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pause_dim.visible = false
    add_child(pause_dim)
    move_child(pause_dim, 1)
    pause_panel = PanelContainer.new()
    pause_panel.position = Vector2(620, 230)
    pause_panel.size = Vector2(360, 440)
    pause_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(pause_panel)
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 8)
    pause_panel.add_child(v)
    v.add_child(_line(308, Color(0.886, 0.631, 0.29, 0.30)))
    var head := HBoxContainer.new()
    head.alignment = BoxContainer.ALIGNMENT_CENTER
    head.add_theme_constant_override("separation", 9)
    var t := _label("暂 停", 22, Color(0.93, 0.78, 0.52))
    t.add_theme_font_override("font", _fvar(0.35, 1))
    head.add_child(t)
    var en := _label("P A U S E D", 8, Color(0.36, 0.44, 0.52))
    en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(en)
    v.add_child(head)

    var b1 := _primary_btn("继 续", 15)
    var b2 := _btn("存 档", 15)
    var b3 := _btn("设 置", 15)
    var b4 := _btn("回 主 菜 单", 15)
    var recover := _btn("脱困修正  /  F8", 15)
    var quit := _btn("保存并退出游戏", 15)
    for b in [b1, b2, b3, recover, b4, quit]:
        b.custom_minimum_size = Vector2(292, 42)
        if b != b1:
            b.add_theme_stylebox_override("normal", _ghost_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.10), 0, 1))
            b.add_theme_stylebox_override("hover", _ghost_style(Color(0.886, 0.631, 0.29, 0.09), Color(0.886, 0.631, 0.29, 0.55), 2, 1))
            b.add_theme_stylebox_override("pressed", _ghost_style(Color(0.886, 0.631, 0.29, 0.16), Color(0.886, 0.631, 0.29, 0.80), 2, 1))
        v.add_child(b)
    b1.pressed.connect(func(): hide_all(); resume_game.emit())
    b2.pressed.connect(func(): _pause_wants_save.emit())
    b3.pressed.connect(func(): _show_settings(true))
    b4.pressed.connect(func(): hide_all(); to_menu.emit())
    recover.pressed.connect(func(): recover_player.emit())
    quit.pressed.connect(func(): quit_game.emit())

signal _pause_wants_save

func hide_all() -> void:
    _reset_pending_delete()
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
            get_viewport().set_input_as_handled()
        elif slots_panel.visible:
            slots_panel.visible = false
            if pause_open:
                show_pause()
            else:
                center.visible = true
                focus_main()
            get_viewport().set_input_as_handled()





