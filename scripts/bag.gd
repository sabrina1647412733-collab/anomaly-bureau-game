extends Control
## 背包：物品栏（带图标）+ 物品详情

signal sel_changed(v)

const ICONS := preload("res://scripts/icons.gd")
const SLOT := 92.0
const GAP := 16.0
const N := 5

var font: Font
var items_ref: Array = []
var sel := 0
var name_lab: Label
var sub_lab: Label
var desc_lab: Label

func setup(f: Font) -> void:
    font = f
    size = Vector2(1600, 900)
    mouse_filter = Control.MOUSE_FILTER_STOP
    name_lab = _lab("", 30, Color(0.95, 0.74, 0.36), Vector2(436, 462), Vector2(730, 42))
    sub_lab = _lab("", 14, Color(0.55, 0.66, 0.78), Vector2(438, 508), Vector2(730, 24))
    desc_lab = _lab("", 16, Color(0.86, 0.90, 0.95), Vector2(438, 542), Vector2(730, 150))
    desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_lab.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _lab(t: String, fs: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
    var l := Label.new()
    var th := Theme.new()
    th.default_font = font
    th.default_font_size = fs
    l.theme = th
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", col)
    l.text = t
    l.position = pos
    l.size = sz
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(l)
    return l

func slot_rect(i: int) -> Rect2:
    var total := N * SLOT + (N - 1) * GAP
    var x0 := (1600.0 - total) * 0.5
    return Rect2(x0 + i * (SLOT + GAP), 268.0, SLOT, SLOT)

func refresh(items: Array, s := -1) -> void:
    items_ref = items
    if s >= 0:
        sel = s
    _update()

func move(d: int) -> void:
    sel = clampi(sel + d, 0, N - 1)
    _update()
    sel_changed.emit(sel)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        for i in range(N):
            if slot_rect(i).has_point(event.position):
                sel = i
                _update()
                sel_changed.emit(sel)
                accept_event()
                return

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_LEFT or event.physical_keycode == KEY_UP:
            move(-1)
        elif event.physical_keycode == KEY_RIGHT or event.physical_keycode == KEY_DOWN:
            move(1)

func _update() -> void:
    if sel >= items_ref.size():
        return
    var it: Dictionary = items_ref[sel]
    var d: Dictionary = it["def"]
    var got := bool(it["got"])
    if got:
        name_lab.text = str(d["name"])
        sub_lab.text = "拾自　" + str(d["where"]) + "　·　已收回"
        desc_lab.text = str(d.get("desc", ""))
    else:
        name_lab.text = "？？？"
        sub_lab.text = "还没找到　·　大概在：" + str(d["where"])
        desc_lab.text = "这条记录还没回到你手里。"
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1600, 900), Color(0.006, 0.012, 0.020, 0.78), true)
    draw_rect(Rect2(400, 140, 800, 620), Color(0.020, 0.030, 0.045, 0.96), true)
    draw_rect(Rect2(400, 140, 800, 620), Color(0.36, 0.46, 0.56, 0.55), false, 1.0)
    draw_rect(Rect2(400, 140, 3, 620), Color(0.88, 0.64, 0.29, 0.95), true)
    draw_string(font, Vector2(436, 200), "背 包　·　值班员随身", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.88, 0.64, 0.29))
    var g0 := 0
    for it in items_ref:
        if bool(it["got"]):
            g0 += 1
    draw_string(font, Vector2(940, 200), "已回收 %d / 5" % g0, HORIZONTAL_ALIGNMENT_RIGHT, 224, 15, Color(0.55, 0.66, 0.78))
    draw_line(Vector2(436, 216), Vector2(1164, 216), Color(0.34, 0.42, 0.50, 0.6), 1.0)
    for i in range(N):
        var r := slot_rect(i)
        var got := i < items_ref.size() and bool(items_ref[i]["got"])
        draw_rect(r, Color(0.03, 0.045, 0.062, 0.95), true)
        if i == sel:
            draw_rect(r.grow(3.0), Color(0.88, 0.64, 0.29, 0.95), false, 2.0)
        else:
            draw_rect(r, Color(0.34, 0.41, 0.49, 0.5), false, 1.0)
        if got:
            var d: Dictionary = items_ref[i]["def"]
            ICONS.icon(self, r.get_center(), SLOT * 0.66, String(d["id"]), Color(d["col"]), false)
        else:
            draw_string(font, r.position + Vector2(34, 60), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.30, 0.36, 0.44))
        draw_string(font, r.position + Vector2(6, 18), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.63, 0.71))
    draw_line(Vector2(436, 400), Vector2(1164, 400), Color(0.34, 0.42, 0.50, 0.6), 1.0)
    draw_string(font, Vector2(436, 430), "物品详情", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.50, 0.58, 0.66))
    draw_string(font, Vector2(0, 730), "← → 或点击选择　·　B / Esc 关闭　·　时间不会等你", HORIZONTAL_ALIGNMENT_CENTER, 1600, 13, Color(0.44, 0.52, 0.60))
