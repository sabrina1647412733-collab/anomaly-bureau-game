extends Control
## 主菜单 / 存档槽位 / 设置 / 暂停菜单（纯代码 UI，1600x900 绝对布局）

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
var center: VBoxContainer
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
func _btn(text: String, fs := 18) -> Button:
    var b := Button.new()
    b.text = text
    var th := Theme.new()
    th.default_font = font
    th.default_font_size = fs
    b.theme = th
    b.add_theme_font_size_override("font_size", fs)
    b.custom_minimum_size = Vector2(300, 46)
    return b

func _label(text: String, fs := 16, col := Color(0.88, 0.90, 0.94)) -> Label:
    var l := Label.new()
    var th := Theme.new()
    th.default_font = font
    th.default_font_size = fs
    l.theme = th
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", col)
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

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

# ------------------------------------------------------------------ 海报背景
func _build_poster() -> void:
    poster = TextureRect.new()
    poster.position = Vector2.ZERO
    poster.size = Vector2(1600, 900)
    poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists("res://assets/poster.png"):
        poster.texture = load("res://assets/poster.png")
    else:
        poster.visible = false
    add_child(poster)

# ------------------------------------------------------------------ 主菜单
func _build_main() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    size = Vector2(1600, 900)
    var dim := ColorRect.new()
    dim.color = Color(0.010, 0.018, 0.030, 0.28)
    dim.position = Vector2.ZERO
    dim.size = Vector2(1600, 900)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    var grad := ColorRect.new()
    grad.color = Color(0.006, 0.012, 0.022, 0.60)
    grad.position = Vector2.ZERO
    grad.size = Vector2(700, 900)
    grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grad)

    center = VBoxContainer.new()
    center.position = Vector2(90, 150)
    center.size = Vector2(520, 620)
    center.alignment = BoxContainer.ALIGNMENT_BEGIN
    center.add_theme_constant_override("separation", 8)
    add_child(center)

    center.add_child(_label("最后一班地铁", 30, Color(0.62, 0.72, 0.84)))
    var t := _label("0017", 92, Color(0.95, 0.74, 0.36))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    center.add_child(t)
    var tag := _label("岚桥站 · 二十七个零点十七分 · 你只有这 27 分钟", 15, Color(0.52, 0.62, 0.74))
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    center.add_child(tag)
    center.add_child(_label("", 26))

    var b_start := _btn("开 始 新 的 一 夜", 20)
    var b_load := _btn("载 入 存 档", 18)
    var b_set := _btn("设 置", 18)
    var b_quit := _btn("退 出", 18)
    for b in [b_start, b_load, b_set, b_quit]:
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        center.add_child(b)
    b_start.pressed.connect(func(): start_game.emit())
    b_load.pressed.connect(func(): show_slots("load"))
    b_set.pressed.connect(func(): _show_settings(true))
    b_quit.pressed.connect(func(): quit_game.emit())

    var hint := _label("WASD 走 · 空格 跳 · E 交互 · T 提前结束本班 · Esc 暂停", 13, Color(0.40, 0.48, 0.58))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    hint.position = Vector2(92, 838)
    hint.size = Vector2(760, 20)
    add_child(hint)

# ------------------------------------------------------------------ 存档槽位
func _build_slots() -> void:
    slots_panel = PanelContainer.new()
    slots_panel.position = Vector2(520, 230)
    slots_panel.size = Vector2(560, 420)
    add_child(slots_panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    slots_panel.add_child(v)
    v.add_child(_label("存 档", 26, Color(0.88, 0.64, 0.29)))
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
    sett.position = Vector2(500, 170)
    sett.size = Vector2(600, 560)
    add_child(sett)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    sett.add_child(v)
    v.add_child(_label("设 置", 26, Color(0.88, 0.64, 0.29)))
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

func show_pause() -> void:
    pause_open = true
    center.visible = false
    sett.visible = false
    slots_panel.visible = false
    pause_panel.visible = true

# ------------------------------------------------------------------ 暂停
func _build_pause() -> void:
    pause_panel = PanelContainer.new()
    pause_panel.position = Vector2(620, 280)
    pause_panel.size = Vector2(360, 340)
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
