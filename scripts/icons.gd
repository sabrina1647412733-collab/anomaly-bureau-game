extends RefCounted
## 物品图标：全部用 _draw 画，不依赖任何贴图

static func icon(ci: CanvasItem, c: Vector2, s: float, id: String, col: Color, dim := false) -> void:
    var a := 0.32 if dim else 1.0
    var ln := Color(col.r, col.g, col.b, a)
    var soft := Color(col.r, col.g, col.b, a * 0.25)
    var fill := Color(col.r * 0.30, col.g * 0.30, col.b * 0.30, a)
    var body := Color(0.08, 0.11, 0.15, a)
    var lw := maxf(1.0, s * 0.045)
    match id:
        "red":      # 红灯延迟记录：继电器盒 + 红灯 + 打印条
            ci.draw_rect(Rect2(c.x - s * 0.46, c.y - 0.30 * s, s * 0.92, s * 0.60), body, true)
            ci.draw_rect(Rect2(c.x - s * 0.46, c.y - 0.30 * s, s * 0.92, s * 0.60), ln, false, lw)
            ci.draw_circle(Vector2(c.x - s * 0.26, c.y - 0.04 * s), s * 0.17, soft)
            ci.draw_circle(Vector2(c.x - s * 0.26, c.y - 0.04 * s), s * 0.10, ln)
            ci.draw_rect(Rect2(c.x - s * 0.04, c.y - 0.20 * s, s * 0.42, s * 0.36), fill, true)
            ci.draw_rect(Rect2(c.x - s * 0.04, c.y - 0.20 * s, s * 0.42, s * 0.36), ln, false, lw * 0.8)
            for k in range(3):
                ci.draw_rect(Rect2(c.x + s * 0.01, c.y - 0.13 * s + k * s * 0.11, s * 0.30, s * 0.035), ln, true)
        "tape":     # 倒放广播：磁带
            ci.draw_rect(Rect2(c.x - s * 0.48, c.y - 0.30 * s, s * 0.96, s * 0.60), body, true)
            ci.draw_rect(Rect2(c.x - s * 0.48, c.y - 0.30 * s, s * 0.96, s * 0.60), ln, false, lw)
            for rx in [-0.22, 0.22]:
                ci.draw_circle(Vector2(c.x + s * rx, c.y - 0.04 * s), s * 0.15, ln)
                ci.draw_circle(Vector2(c.x + s * rx, c.y - 0.04 * s), s * 0.06, body)
            ci.draw_rect(Rect2(c.x - s * 0.30, c.y + 0.14 * s, s * 0.60, s * 0.09), fill, true)
        "key":      # 停用钥匙
            ci.draw_circle(Vector2(c.x - s * 0.28, c.y - 0.06 * s), s * 0.20, body)
            ci.draw_circle(Vector2(c.x - s * 0.28, c.y - 0.06 * s), s * 0.20, ln, false, lw)
            ci.draw_circle(Vector2(c.x - s * 0.28, c.y - 0.06 * s), s * 0.08, body)
            ci.draw_rect(Rect2(c.x - s * 0.12, c.y - 0.10 * s, s * 0.58, s * 0.09), ln, true)
            ci.draw_rect(Rect2(c.x + 0.30 * s, c.y - 0.01 * s, s * 0.07, s * 0.16), ln, true)
            ci.draw_rect(Rect2(c.x + 0.16 * s, c.y - 0.01 * s, s * 0.07, s * 0.12), ln, true)
        "log":      # 巡检簿：掉了一角的纸
            var p := PackedVector2Array([
                Vector2(c.x - s * 0.36, c.y - s * 0.36), Vector2(c.x + s * 0.22, c.y - s * 0.36),
                Vector2(c.x + s * 0.40, c.y - s * 0.16), Vector2(c.x + s * 0.40, c.y + s * 0.36),
                Vector2(c.x - s * 0.36, c.y + s * 0.36)])
            ci.draw_colored_polygon(p, fill)
            for k in range(5):
                var v := p[k]
                var v2 := p[(k + 1) % 5]
                ci.draw_line(v, v2, ln, lw)
            for k2 in range(4):
                ci.draw_rect(Rect2(c.x - s * 0.24, c.y - s * 0.22 + k2 * s * 0.15, s * 0.50, s * 0.045), ln, true)
        "relay5":   # 五号继电器：线圈 + 绿灯 + 手柄
            ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.32, s * 0.88, s * 0.64), body, true)
            ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.32, s * 0.88, s * 0.64), ln, false, lw)
            for k in range(5):
                ci.draw_rect(Rect2(c.x - s * 0.32 + k * s * 0.11, c.y - s * 0.16, s * 0.05, s * 0.30), ln, true)
            ci.draw_circle(Vector2(c.x + s * 0.30, c.y - s * 0.18), s * 0.09, Color(0.30, 0.95, 0.62, a))
            ci.draw_line(Vector2(c.x - s * 0.34, c.y + s * 0.24), Vector2(c.x + s * 0.30, c.y + s * 0.10), ln, lw * 1.4)
