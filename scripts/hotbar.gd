extends Control
## 屏幕下方一排在物品栏（5 格 + 图标 + 当前选中说明）

signal sel_changed(v)

const ICONS := preload("res://scripts/icons.gd")
const SLOT := 58.0
const GAP := 8.0
const N := 5
const TOP := 820.0          # 格子顶边（底部留 22px）

var font: Font
var items: Array = []
var sel := 0

func setup(f: Font) -> void:
    font = f
    position = Vector2.ZERO
    size = Vector2(1600, 900)
    mouse_filter = Control.MOUSE_FILTER_PASS

func _process(_d: float) -> void:
    queue_redraw()          # ← 之前漏了这句，所以永远不刷新

func slot_rect(i: int) -> Rect2:
    var total := N * SLOT + (N - 1) * GAP
    var x0 := (1600.0 - total) * 0.5
    return Rect2(x0 + i * (SLOT + GAP), TOP, SLOT, SLOT)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        for i in range(N):
            if slot_rect(i).has_point(event.position):
                sel = i
                sel_changed.emit(sel)
                accept_event()
                return

func _draw() -> void:
    for i in range(N):
        var r := slot_rect(i)
        var got := i < items.size() and bool(items[i]["got"])
        draw_rect(r, Color(0.02, 0.03, 0.05, 0.72), true)
        if i == sel:
            draw_rect(r.grow(2.0), Color(0.88, 0.64, 0.29, 0.95), false, 2.0)
        else:
            draw_rect(r, Color(0.34, 0.41, 0.49, 0.45), false, 1.0)
        if got:
            var d: Dictionary = items[i]["def"]
            ICONS.icon(self, r.get_center(), SLOT * 0.66, String(d["id"]), Color(d["col"]), false)
        draw_string(font, r.position + Vector2(5, 15), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
            Color(0.62, 0.70, 0.78) if got else Color(0.34, 0.40, 0.47))
    # 选中物品的一行说明（放在格子上方）
    if sel < items.size():
        var dd: Dictionary = items[sel]["def"]
        var g2 := bool(items[sel]["got"])
        var t := String(dd["name"]) + ("　—　" + String(dd["where"]) if g2 else "　—　还没找到")
        draw_string(font, Vector2(0, TOP - 12), t, HORIZONTAL_ALIGNMENT_CENTER, 1600, 14,
            Color(0.90, 0.93, 0.97) if g2 else Color(0.44, 0.50, 0.58))
    # 操作提示挪到左下角，避免和字幕/格子打架
    draw_string(font, Vector2(28, TOP + 24), "B 背包　·　1~5 选择", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.40, 0.47, 0.55))
