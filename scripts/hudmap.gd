extends Control
## 右上角：站台地图 + 任务/剧情导向面板（全部用 _draw 画）

var font: Font
var player_node: Node3D
var objectives: Array = []      # [{text, pos:Vector3, done:bool, kind:String}]
var people: Array = []          # [{name, pos:Vector3, col:Color}]
var round_title := "序章"
var round_hint := ""
var clue_labels := ["C01 红灯延迟记录", "C03 倒放广播", "C05 停用钥匙", "C06 巡检簿撕页"]
var clues := {}
var t := 0.0
var redraw_acc := 0.0

const X0 := -20.5
const Z0 := -124.0
const S := 2.20

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    t += delta
    redraw_acc += delta
    if redraw_acc >= 0.066:
        redraw_acc = 0.0
        queue_redraw()

func mp(x: float, z: float) -> Vector2:
    return Vector2(MAPX + (x - X0) * S, MAPY + (z - Z0) * S)

const MAPX := 258.0
const MAPY := 30.0
const MAPW := 96.0
const MAPH := 418.0
const PANX := 0.0
const PANW := 246.0

func _draw() -> void:
    _panel()
    _map()
    _objects()

func _panel() -> void:
    draw_rect(Rect2(PANX, 0, PANW, 330), Color(0.02, 0.03, 0.045, 0.82), true)
    draw_rect(Rect2(PANX, 0, PANW, 330), Color(0.36, 0.46, 0.56, 0.55), false, 1.0)
    draw_rect(Rect2(PANX, 0, 3, 330), Color(0.98, 0.70, 0.28, 0.95), true)
    var x := PANX + 14.0
    draw_string(font, Vector2(x, 22), "值 班 台 · " + round_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.85, 1.0))
    draw_line(Vector2(x, 30), Vector2(PANX + PANW - 14, 30), Color(0.35, 0.45, 0.55, 0.5), 1.0)
    var y := 52.0
    draw_string(font, Vector2(x, y), "当前目标", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.62, 0.70))
    y += 20.0
    if objectives.size() == 0:
        draw_string(font, Vector2(x, y), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.86, 0.92))
    for o in objectives:
        var done: bool = o.get("done", false)
        var col := Color(0.42, 0.52, 0.60) if done else Color(0.98, 0.94, 0.86)
        var mark := "✓ " if done else "▸ "
        var txt: String = str(o.get("text", ""))
        var lines := _wrap(txt, 15)
        for i in range(lines.size()):
            var prefix := mark if i == 0 else "   "
            draw_string(font, Vector2(x, y), prefix + lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
            y += 19.0
        if not done and player_node != null:
            var p: Vector3 = o.get("pos", Vector3.ZERO)
            var d: float = player_node.global_position.distance_to(p)
            draw_string(font, Vector2(PANX + PANW - 66, y - 19), "%d m" % int(round(d)),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.99, 0.72, 0.32))
        y += 4.0
    y += 8.0
    draw_line(Vector2(x, y - 8), Vector2(PANX + PANW - 14, y - 8), Color(0.35, 0.45, 0.55, 0.4), 1.0)
    draw_string(font, Vector2(x, y + 6), "记录", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.62, 0.70))
    y += 24.0
    for c in clue_labels:
        var has: bool = clues.has(c)
        var cc := Color(0.45, 0.88, 1.0) if has else Color(0.34, 0.40, 0.46)
        draw_string(font, Vector2(x, y), ("[x] " if has else "[  ] ") + str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cc)
        y += 18.0
    if round_hint != "":
        draw_line(Vector2(x, y - 4), Vector2(PANX + PANW - 14, y - 4), Color(0.35, 0.45, 0.55, 0.4), 1.0)
        y += 16.0
        for l in _wrap(round_hint, 15):
            draw_string(font, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.78, 0.86))
            y += 17.0
    draw_string(font, Vector2(x, 320), "WASD 走 · 空格 跳 · ←→ 转头 · F 手电", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.40, 0.47, 0.55))

func _map() -> void:
    draw_rect(Rect2(MAPX - 6, MAPY - 22, MAPW + 12, MAPH + 12), Color(0.02, 0.03, 0.045, 0.82), true)
    draw_rect(Rect2(MAPX - 6, MAPY - 22, MAPW + 12, MAPH + 12), Color(0.36, 0.46, 0.56, 0.55), false, 1.0)
    draw_string(font, Vector2(MAPX, MAPY - 8), "站 区 图", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.85, 1.0))
    draw_string(font, Vector2(MAPX + 58, MAPY - 8), "N↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.62, 0.72, 0.82))
    # 轨行区（北端接岔区）
    draw_rect(Rect2(mp(0.0, Z0), Vector2(8.0 * S, (60.0 - Z0) * S)), Color(0.10, 0.11, 0.13, 0.95), true)
    # 岔区厅
    draw_rect(Rect2(mp(8.0, -122.0), Vector2(10.6 * S, 56.2 * S)), Color(0.15, 0.14, 0.12, 0.96), true)
    # 检修环线侧线
    draw_rect(Rect2(mp(13.6, -65.8), Vector2(5.0 * S, 131.8 * S)), Color(0.16, 0.15, 0.13, 0.92), true)
    # 道岔
    draw_line(mp(4.0, -118.0), mp(15.5, -66.0), Color(0.55, 0.78, 1.0, 0.85), 1.8)
    draw_circle(mp(0.9, -108.0), 2.6, Color(0.85, 0.25, 0.20, 0.95))
    draw_string(font, Vector2(mp(0.9, -108.0).x + 5, mp(0.9, -108.0).y + 4), "岔", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.80, 0.55))
    draw_string(font, Vector2(mp(15.5, -40.0).x + 4, mp(15.5, -40.0).y), "环线", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.60, 0.72, 0.60))
    draw_rect(Rect2(mp(0.0, 56.0), Vector2(8.0 * S, 4.0 * S)), Color(0.07, 0.08, 0.10, 0.9), true)
    # 检修环线侧龛
    draw_rect(Rect2(mp(8.0, -65.5), Vector2((12.6 - 8.0) * S, 8.0 * S)), Color(0.22, 0.20, 0.16, 0.95), true)
    # 站台
    draw_rect(Rect2(mp(-18.0, -56.0), Vector2(18.0 * S, 112.0 * S)), Color(0.19, 0.21, 0.24, 0.98), true)
    # 站台黄线
    draw_line(mp(-1.0, -56.0), mp(-1.0, 56.0), Color(0.85, 0.66, 0.20, 0.85), 1.5)
    # 信号室 / 检修笼
    draw_rect(Rect2(mp(-18.0, 24.0), Vector2(3.8 * S, 8.5 * S)), Color(0.30, 0.34, 0.40, 1.0), true)
    draw_rect(Rect2(mp(-18.0, -38.0), Vector2(1.7 * S, 4.0 * S)), Color(0.30, 0.34, 0.40, 1.0), true)
    # 柱
    for i in range(8):
        var z := -40.0 + float(i) * 12.0
        draw_rect(Rect2(mp(-9.1, z - 0.5), Vector2(1.0 * S, 1.0 * S)), Color(0.34, 0.38, 0.44, 1.0), true)
    # 出口卷帘
    draw_line(mp(-18.0, 50.0), mp(0.0, 50.0), Color(0.55, 0.60, 0.66, 0.9), 2.0)
    draw_string(font, Vector2(mp(-8.0, 50.0).x - 8, mp(-8.0, 50.0).y + 12), "出口", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.62, 0.68))
    draw_string(font, Vector2(mp(-8.5, -30.0).x - 10, mp(-8.5, -30.0).y), "站台", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.42, 0.47, 0.54))
    draw_string(font, Vector2(mp(4.0, -20.0).x - 8, mp(4.0, -20.0).y), "轨行区", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.40, 0.44, 0.50))

func _objects() -> void:
    # 目标点
    for o in objectives:
        if o.get("done", false):
            continue
        var p := mp(o["pos"].x, o["pos"].z)
        var pulse := 3.6 + sin(t * 4.0) * 1.2
        draw_circle(p, pulse + 3.0, Color(0.30, 0.70, 0.95, 0.22))
        draw_circle(p, 3.2, Color(0.55, 0.92, 1.0, 0.95))
    # 人物
    for pe in people:
        var p2 := mp(pe["pos"].x, pe["pos"].z)
        draw_circle(p2, 3.4, pe.get("col", Color(1, 0.8, 0.4)))
    # 玩家（箭头）
    if player_node != null:
        var pp := mp(player_node.global_position.x, player_node.global_position.z)
        var yaw := player_node.rotation.y
        var dir := Vector2(sin(yaw), -cos(yaw))
        var per := Vector2(dir.y, -dir.x)
        var a := pp + dir * 6.0
        var b := pp - dir * 4.0 + per * 4.0
        var c := pp - dir * 4.0 - per * 4.0
        draw_colored_polygon(PackedVector2Array([a, b, c]), Color(0.98, 0.78, 0.30, 1.0))
        draw_circle(pp, 1.6, Color(1, 1, 1, 0.9))

func _wrap(s: String, n: int) -> Array:
    var out := []
    var cur := ""
    for ch in s:
        cur += ch
        if cur.length() >= n:
            out.append(cur)
            cur = ""
    if cur != "":
        out.append(cur)
    if out.size() == 0:
        out.append("")
    return out
