extends RefCounted
## 岚桥站的站体布局：把几何/灯光/道具摆进 StationBuilder
## 只做「盖房子」，玩法在 game.gd

const SB := preload("res://scripts/station.gd")

const PX0 := -18.0
const PX1 := 0.0
const TX0 := 0.0
const TX1 := 8.0
const ZS0 := -56.0
const ZS1 := 56.0
const FY := 0.0
const TY := -1.15
const CH := 5.0
const ZTUN := -190.0
const BORE_R := 4.0
const BORE_SP := 1.0
const QZ0 := -122.0     # 岔区北端
const QZ1 := -65.8      # 岔区南端（检修环线北墙外皮）
const QX1 := 18.6       # 岔区 / 侧线东墙内侧
const QY := 4.30        # 岔区吊顶下表面
const SX0 := 13.6       # 侧线隧道西墙内侧
const SX1 := 18.6       # 侧线隧道东墙内侧
const SZ1 := 110.0      # 侧线隧道南端
const BR_X0 := 4.0      # 主线中心
const BR_X1 := 15.5     # 侧线中心
const BR_Z0 := -118.0   # 道岔起点
const BR_Z1 := -70.0    # 道岔终点（拐完再进洞）

var b            # StationBuilder
var font: Font

func _v(x: float, y: float, z: float) -> Vector3:
    return Vector3(x, y, z)

func build() -> void:
    ground()
    walls()
    vault()
    platform_edge()
    columns_and_lights()
    track()
    tunnel()
    niche()
    branch_area()
    props()
    rooms()
    signage()
    details()
    tunnel_detail()

# ------------------------------------------------------------------ 地坪 / 墙 / 顶
func ground() -> void:
    b.slab("floor", PX0 - 0.6, ZS0 - 0.6, PX1, ZS1 + 0.6, FY, 1.2, true)
    b.slab("rust", TX0, ZTUN, TX1, 200.0, TY, 1.2, true)

func walls() -> void:
    b.box("panel", _v(PX0 - 0.5, FY, ZS0 - 0.6), _v(PX0, CH, ZS1 + 0.6), true, "p")
    b.box("panel", _v(TX1, TY, ZS0), _v(TX1 + 0.7, CH, ZS1), true, "n")
    b.box("panel", _v(PX0 - 0.6, FY, ZS0 - 0.6), _v(TX0, CH + 1.4, ZS0), true, "f")
    b.box("panel", _v(PX0 - 0.6, FY, ZS1), _v(TX0, CH + 1.4, ZS1 + 0.6), true, "k")
    b.box("ceil", _v(TX0, CH, ZS0 - 0.6), _v(TX1 + 0.7, CH + 0.6, ZS1 + 0.6), true, "b")   # 轨行区平顶

# ------------------------------------------------------------------ 站台厅拱顶
## 浅桶形拱顶（半正弦剖面）+ 每 6m 一道拱肋，替掉原来的平板吊顶
func vault() -> void:
    var sag := 1.15
    var x0 := PX0
    var x1 := TX0
    var segs := 26
    var zz0 := ZS0 - 0.6
    var zz1 := ZS1 + 0.6
    for i in range(segs):
        var t0 := float(i) / float(segs)
        var t1 := float(i + 1) / float(segs)
        var xa := lerpf(x0, x1, t0)
        var xb := lerpf(x0, x1, t1)
        var ya := CH + sag * sin(PI * t0)
        var yb := CH + sag * sin(PI * t1)
        var tm := (t0 + t1) * 0.5
        var slope := sag * PI / (x1 - x0) * cos(PI * tm)
        var n := Vector3(slope, -1.0, 0.0).normalized()
        b.quad("ceil", Vector3(xa, ya, zz0), Vector3(xb, yb, zz0), Vector3(xb, yb, zz1), Vector3(xa, ya, zz1), n)
    # 拱肋
    var zr := zz0
    while zr < zz1:
        for i in range(segs):
            var t0 := float(i) / float(segs)
            var t1 := float(i + 1) / float(segs)
            var xa := lerpf(x0, x1, t0)
            var xb := lerpf(x0, x1, t1)
            var ya := CH + sag * sin(PI * t0) - 0.055
            var yb := CH + sag * sin(PI * t1) - 0.055
            var tm := (t0 + t1) * 0.5
            var slope := sag * PI / (x1 - x0) * cos(PI * tm)
            var n := Vector3(slope, -1.0, 0.0).normalized()
            b.quad("metalD", Vector3(xa, ya, zr), Vector3(xb, yb, zr), Vector3(xb, yb, zr + 0.40), Vector3(xa, ya, zr + 0.40), n)
        zr += 6.0

func platform_edge() -> void:
    b.box("conc", _v(-0.35, TY, ZS0), _v(0.0, FY, ZS1), false, "p")
    b.box("white", _v(-0.62, FY, ZS0), _v(0.0, FY + 0.02, ZS1), false, "t")
    b.box("edge", _v(-1.42, FY, ZS0), _v(-0.66, FY + 0.025, ZS1), false, "t")
    # 墙裙彩色带（后墙蓝+琥珀 / 对侧墙绿）
    b.box("trainC", _v(PX0 + 0.02, FY + 0.02, ZS0), _v(PX0 + 0.07, 0.90, ZS1), false, "p")
    b.box("hazard", _v(PX0 + 0.02, 0.90, ZS0), _v(PX0 + 0.07, 0.96, ZS1), false, "p")
    b.box("exit", _v(TX1 - 0.07, FY + 0.02, ZS0), _v(TX1 - 0.02, 0.90, ZS1), false, "n")

# ------------------------------------------------------------------ 柱 / 灯
func columns_and_lights() -> void:
    for i in range(8):
        var z := -40.0 + float(i) * 12.0
        var cx := -8.60
        # 圆柱柱：柱础（圆台）→ 柱身 → 柱头（外扩圆台）
        b.cyl("colTile", cx, z, FY + 0.12, CH - 0.22, 0.42, 0.42, 14, false, false)
        b.cyl("metalD", cx, z, FY, FY + 0.12, 0.55, 0.46, 14, false, true)
        b.cyl("metalD", cx, z, CH - 0.22, CH, 0.46, 0.56, 14, true, false)
        # 站名环带（琥珀 + 蓝牌）
        b.cyl("colAmber", cx, z, 1.38, 1.60, 0.435, 0.435, 14, false, false)
        b.cyl("sign", cx, z, 1.42, 1.54, 0.448, 0.448, 14, false, false)
        b.add_collider(_v(cx - 0.52, FY, z - 0.52), _v(cx + 0.52, CH, z + 0.52))
    # 站台灯带
    for i in range(22):
        var z := -52.5 + float(i) * 5.0
        b.box("lamp", _v(-12.6, CH - 0.13, z - 0.22), _v(-4.4, CH - 0.02, z + 0.22), false, "b")
        b.box("metalD", _v(-12.8, CH - 0.20, z - 0.34), _v(-4.2, CH - 0.06, z + 0.34), false)
        if i % 2 == 0:
            b.light(_v(-8.5, CH - 0.7, z), Color(0.88, 0.64, 0.29), 4.0, 12.0, i % 4 == 0)
    # 轨行区灯带（冷白）
    for i in range(11):
        var z := -50.0 + float(i) * 10.0
        b.box("lampC", _v(1.6, CH - 0.13, z - 1.5), _v(6.4, CH - 0.02, z + 1.5), false, "b")
        b.box("metalD", _v(1.4, CH - 0.20, z - 1.7), _v(6.6, CH - 0.06, z + 1.7), false)
        b.light(_v(4.0, CH - 0.9, z), Color(0.35, 0.62, 0.83), 2.6, 13.0, false)
    # 广告灯箱（站台主要光源）
    var adz := [-27.0, -22.0, -10.0, 2.0, 17.5, 46.0]
    var adtint := ["glow|5aa8ff", "glow|ffc98a", "glow|dfefff"]
    for i in range(adz.size()):
        var az: float = adz[i]
        b.box("metalD", _v(PX0, 1.15, az - 1.35), _v(PX0 + 0.24, 2.85, az + 1.35), false)
        b.box(adtint[i % adtint.size()], _v(PX0 + 0.25, 1.32, az - 1.16), _v(PX0 + 0.33, 2.68, az + 1.16), false, "p")
        b.box(adtint[(i + 1) % adtint.size()], _v(PX0 + 0.34, 1.60, az - 0.85), _v(PX0 + 0.38, 2.40, az + 0.85), false, "p")
        b.box("lamp", _v(PX0 + 0.02, 1.25, az - 1.2), _v(PX0 + 0.10, 2.75, az + 1.2), false)
        b.light(_v(PX0 + 1.8, 2.0, az), [Color(1.0, 0.87, 0.66), Color(0.86, 0.92, 1.0)][i % 2], 9.0, 17.0, i % 3 == 1)

# ------------------------------------------------------------------ 轨道
func track() -> void:
    for rx in [3.28, 4.72]:
        b.box("metal", _v(rx - 0.045, TY, ZTUN), _v(rx + 0.045, TY + 0.16, 200.0), false)
    var z := -80.0
    while z < 80.0:
        b.box("conc", _v(2.55, TY - 0.02, z), _v(5.45, TY + 0.03, z + 0.26), false)
        z += 0.9
    b.box("dark", _v(TX1 - 0.7, TY, ZTUN), _v(TX1 - 0.15, TY + 0.30, 200.0), false)
    for sz in [40.0, -20.0, 12.0]:
        b.box("metalD", _v(2.0, TY, sz - 0.10), _v(2.30, TY + 3.0, sz + 0.10), true)
        b.box("dark", _v(1.95, TY + 2.35, sz - 0.19), _v(2.35, TY + 3.0, sz + 0.19), false)
        b.box("lampC", _v(2.0, TY + 2.62, sz - 0.22), _v(2.06, TY + 2.82, sz - 0.14), false, "n")

# ------------------------------------------------------------------ 隧道
func bore_profile(open_from := 99.0) -> PackedVector2Array:
    var pts := PackedVector2Array()
    pts.append(Vector2(TX0, TY))
    pts.append(Vector2(TX0, 1.0))
    for i in range(1, 19):
        var a: float = PI * (1.0 - float(i) / 18.0)
        pts.append(Vector2(4.0 + cos(a) * 4.0, 1.0 + sin(a) * 4.0))
    pts.append(Vector2(TX1, 1.0))
    if open_from > 90.0:
        pts.append(Vector2(TX1, TY))
    else:
        pts.append(Vector2(TX1, open_from))
    return pts

func tunnel() -> void:
    # 北段：完整圆拱到岔区北端；岔区那一段东侧敞开，并入岔区厅
    b.extrude("tunnel", bore_profile(), ZTUN, QZ0)
    b.extrude("tunnel", bore_profile_open(QY), QZ0, QZ1)
    # 南段：站体南端以外仍是完整隧道
    b.extrude("tunnel", bore_profile(), ZS1, 200.0)
    # 碰撞（简化：两侧墙 + 平顶）
    b.box("tunnel", _v(-0.6, TY, ZTUN), _v(0.05, CH, ZS0), true)
    b.box("tunnel", _v(-0.6, TY, ZS1), _v(0.05, CH, 200.0), true)
    b.box("tunnel", _v(TX1 - 0.05, TY, ZTUN), _v(TX1 + 1.0, CH, QZ0), true)
    b.box("tunnel", _v(TX1 - 0.05, TY, -56.0), _v(TX1 + 1.0, CH, 200.0), true)
    b.box("tunnel", _v(0.0, 4.9, ZTUN), _v(TX1, 5.6, ZS0), true)
    b.box("tunnel", _v(0.0, 4.9, ZS1), _v(TX1, 5.6, 200.0), true)
    b.box("tunnel", _v(-1.0, TY, ZTUN - 1.0), _v(TX1 + 1.0, CH, ZTUN), true)
    for i in range(6):
        var z := -170.0 + float(i) * 22.0
        b.box("lampC", _v(TX1 - 0.40, 3.05, z - 1.1), _v(TX1 - 0.16, 3.20, z + 1.1), false, "n")
        if i < 4:
            var l: OmniLight3D = b.light(_v(TX1 - 1.1, 2.9, z), Color(0.35, 0.62, 0.83), 1.8, 14.0, false)
            l.set_meta("flicker", randf() * 10.0)

func bore_profile_open(y_cut := 4.30) -> PackedVector2Array:
    # 东侧（+X）不封口：拱顶走到切口高度就停，好让岔区接上平顶
    var pts := PackedVector2Array()
    pts.append(Vector2(TX0, TY))
    pts.append(Vector2(TX0, BORE_SP))
    var ac := asin(clampf((y_cut - BORE_SP) / BORE_R, 0.0, 1.0))
    for i in range(1, 19):
        var a: float = PI * (1.0 - float(i) / 18.0)
        if a < ac:
            break
        pts.append(Vector2(4.0 + cos(a) * BORE_R, BORE_SP + sin(a) * BORE_R))
    pts.append(Vector2(4.0 + cos(ac) * BORE_R, y_cut))
    return pts

# ------------------------------------------------------------------ 检修环线侧龛
func niche() -> void:
    var z0 := -65.5
    var z1 := -57.5
    var x1 := 12.4
    # 地面 / 顶 / 三道墙
    b.box("rust", _v(TX1, TY - 0.4, z0), _v(x1, TY, z1), true, "t")
    # 北墙留一个门洞通往岔区（x 9.4~12.4）
    b.box("rust", _v(TX1, TY, z0 - 0.3), _v(9.4, 1.9, z0), true, "f")
    b.box("rust", _v(12.4, TY, z0 - 0.3), _v(x1 + 0.4, 1.9, z0), true, "f")
    b.box("rust", _v(9.4, 1.45, z0 - 0.3), _v(12.4, 1.9, z0), true, "f")
    b.box("rust", _v(TX1, TY, z1), _v(x1 + 0.4, 1.9, z1 + 0.3), true, "k")
    b.box("rust", _v(x1, TY, z0 - 0.3), _v(x1 + 0.4, 1.9, z1 + 0.3), true, "n")
    b.box("rust", _v(TX1, 1.62, z0), _v(x1 + 0.4, 1.95, z1), true, "b")
    # 靠里侧的检修走道（高 0.25 的混凝土台）
    b.box("conc", _v(10.5, TY, z0 + 0.2), _v(x1, TY + 0.25, z1 - 0.2), true, "t")
    b.box("hazard", _v(10.499, TY + 0.25, z0 + 0.2), _v(10.621, TY + 0.29, z1 - 0.2), false)
    # 电缆槽 + 管路
    for i in range(3):
        var y := TY + 0.40 + float(i) * 0.32
        b.box("dark", _v(x1 - 0.42, y, z0 + 0.4), _v(x1 - 0.10, y + 0.22, z1 - 0.4), false)
    b.box("metalD", _v(TX1 + 0.02, TY + 1.15, z0 + 0.5), _v(TX1 + 0.30, TY + 1.45, z1 - 0.5), false)
    # 三盏壁灯（中间那盏是坏的）
    for i in range(3):
        var zz := z0 + 1.6 + float(i) * 2.6
        b.box("metalD", _v(x1 - 0.45, TY + 2.05, zz - 0.55), _v(x1 - 0.12, TY + 2.20, zz + 0.55), false)
        b.box("lampC" if i != 1 else "dark", _v(x1 - 0.44, TY + 1.98, zz - 0.45), _v(x1 - 0.14, TY + 2.06, zz + 0.45), false, "k")
        if i != 1:
            b.light(_v(x1 - 1.1, TY + 1.7, zz), Color(0.62, 0.72, 0.92), 1.7, 9.0, false)
    # 工作台（放停用钥匙）+ 台钳
    desk(9.9, -62.4, 11.0, -59.8, TY + 0.86, TY)
    b.box("dark", _v(10.1, TY + 0.86, -61.6), _v(10.5, TY + 1.02, -61.2), false)
    b.add_collider(_v(10.1, TY + 0.86, -61.6), _v(10.5, TY + 1.02, -61.2))
    # 梯子（靠尽头墙）
    for i in range(7):
        var y2 := TY + 0.28 + float(i) * 0.34
        b.cyl_dir("metal", Vector3(11.60, y2, z0 + 0.39), 0.0, 0.60, 0.020, 8, true)
    for xx in [11.32, 11.88]:
        b.cyl("metal", xx, z0 + 0.39, TY, TY + 2.34, 0.026, 0.026, 8, true, true)
    # 地面排水格栅 + 标牌 + 涂鸦
    b.box("dark", _v(9.2, TY + 0.01, -60.6), _v(10.1, TY + 0.04, -59.7), false)
    for i in range(5):
        b.box("metalD", _v(9.25, TY + 0.02, -60.5 + float(i) * 0.18), _v(10.05, TY + 0.045, -60.45 + float(i) * 0.18), false)
    b.plaque("检修环线", _v(TX1 + 0.02, TY + 1.70, -60.0), 0.95, 0.26, "x", 1, Color(1.0, 0.82, 0.42))
    b.plaque("禁止单人进入", _v(x1 - 0.02, TY + 1.30, -63.6), 0.80, 0.22, "x", -1, Color(0.95, 0.55, 0.45))
    b.label3d("0017", _v(x1 - 0.05, TY + 1.30, -63.4), 0.55, Color(0.92, 0.34, 0.26), -PI * 0.5)
# ------------------------------------------------------------------ 道具
func props() -> void:
    # 绿色候车区地面色线 + 彩色小告示牌
    for i in range(3):
        var mz := -34.0 + float(i) * 26.0
        b.box("exit", _v(-3.0, FY + 0.02, mz), _v(-2.5, FY + 0.035, mz + 9.0), false, "t")
        b.box("exit", _v(-3.0, FY + 0.02, mz), _v(-1.2, FY + 0.035, mz + 0.5), false, "t")
        b.box("exit", _v(-3.0, FY + 0.02, mz + 8.5), _v(-1.2, FY + 0.035, mz + 9.0), false, "t")
    var boardCol := ["glow|5aa8ff", "glow|ffc98a", "glow|dfefff"]
    for i in range(6):
        var bz := -46.0 + float(i) * 15.0
        b.box("metalD", _v(PX0, 1.55, bz), _v(PX0 + 0.10, 2.35, bz + 1.30), false)
        b.box(boardCol[i % boardCol.size()], _v(PX0 + 0.10, 1.62, bz + 0.08), _v(PX0 + 0.14, 2.28, bz + 1.22), false, "p")
    # 长椅 / 售货机 / 垃圾箱（精修版）
    for bz in [Vector2(15.2, 19.2), Vector2(-8.0, -4.0)]:
        bench(-15.10, bz.x, -13.90, bz.y)
    vending(-17.85, 20.5, -17.05, 22.7)
    for gz in [-34.3, -43.6]:
        bin(-17.2, gz + 0.3)
    # 检修箱（放旧继电器）
    b.box("metalD", _v(-17.1, FY, -21.4), _v(-16.1, 0.78, -19.4), true)
    dispatch_console(-17.70, -16.20, -15.70, -12.00)
    chair(-15.05, -14.60, FY, PI * 0.5)
    # 配电柜
    b.box("metalD", _v(-17.75, FY, -30.7), _v(-17.15, 1.95, -29.3), true)
    b.box("metalD", _v(-17.12, FY, -30.65), _v(-17.05, 1.90, -29.35), false)
    b.light(_v(-16.6, 1.6, -30.0), Color(0.35, 0.62, 0.83), 1.8, 7.0, false)
    # 检修笼
    var cg0 := -38.0; var cg1 := -34.0; var cx := -16.30
    for zz in [cg0, cg1]:
        b.box("metalD", _v(cx - 0.03, 0.07, zz - 0.03), _v(cx + 0.03, 2.18, zz + 0.03), false)
        b.box("metalD", _v(PX0, 0.0, zz - 0.06), _v(cx, 2.25, zz + 0.06), true)
    var z := cg0 + 0.28
    while z < cg1 - 0.05:
        if not (z > -36.9 and z < -35.1):
            b.box("metalD", _v(cx - 0.03, 0.07, z - 0.022), _v(cx + 0.03, 2.18, z + 0.022), false)
        z += 0.30
    b.box("metalD", _v(cx - 0.05, 2.18, cg0), _v(cx + 0.05, 2.25, cg1), false)
    b.box("metalD", _v(cx - 0.05, FY, cg0), _v(cx + 0.05, 0.07, cg1), false)
    b.box("metalD", _v(cx - 0.10, FY, cg0), _v(cx + 0.10, 2.25, -36.9), true)
    b.box("metalD", _v(cx - 0.10, FY, -35.1), _v(cx + 0.10, 2.25, cg1), true)
    b.box("metalD", _v(PX0 + 0.1, FY, cg0 + 0.2), _v(cx - 0.35, 0.06, cg1 - 0.2), false)
    b.box("metalD", _v(PX0 + 0.1, 1.10, cg0 + 0.2), _v(cx - 0.35, 1.16, cg1 - 0.2), false)
    b.light(_v(cx - 0.6, 1.9, (cg0 + cg1) * 0.5), Color(0.88, 0.64, 0.29), 2.4, 7.0, false)
    # 轨行区垫脚箱（可跳上去）
    for cz in [-30.0, 20.0]:
        b.box("metalD", _v(0.35, TY, cz - 0.90), _v(1.95, TY + 0.62, cz + 0.90), true)
        b.box("hazard", _v(0.345, TY + 0.62, cz - 0.905), _v(1.955, TY + 0.665, cz - 0.595), false)
    # 检修梯（斜坡，可走回站台）
    ramp(0.30, 1.30, -54.0, -48.0, TY + 0.02, FY + 0.02)
    # 消防与警示（彩色点缀）
    for ez in [-51.0, 51.0]:
        b.box("metalD", _v(-17.90, 1.15, ez), _v(-17.62, 1.62, ez + 0.32), true)
        b.box("red", _v(-17.88, 1.20, ez + 0.03), _v(-17.64, 1.57, ez + 0.29), false, "p")
        b.box("metalD", _v(-17.90, 0.20, ez + 0.70), _v(-17.60, 1.05, ez + 1.70), true)
        b.box("red", _v(-17.86, 0.26, ez + 0.76), _v(-17.64, 0.99, ez + 1.64), false, "p")
    for cz in [-24.0, 24.0]:
        b.box("hazard", _v(-2.42, FY, cz - 0.18), _v(-2.02, FY + 0.55, cz + 0.18), true)
        b.box("dark", _v(-2.38, FY + 0.30, cz - 0.14), _v(-2.06, FY + 0.42, cz + 0.14), false)
    b.box("exit", _v(-6.0, 2.00, -56.02), _v(-3.0, 2.40, -55.98), false, "f")

func ramp(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
    b.quad("conc", _v(x0, y0, z0), _v(x1, y0, z0), _v(x1, y1, z1), _v(x0, y1, z1), Vector3(0, 1, 0))
    b.quad("conc", _v(x0, y0 - 0.9, z0), _v(x1, y0 - 0.9, z0), _v(x1, y0, z0), _v(x0, y0, z0), Vector3(0, 0, -1))
    b.quad("conc", _v(x0, y1, z1), _v(x1, y1, z1), _v(x1, y1 - 0.9, z1), _v(x0, y1 - 0.9, z1), Vector3(0, 0, 1))
    b.quad("conc", _v(x0, y0, z0), _v(x0, y1, z1), _v(x0, y1 - 0.9, z1), _v(x0, y0 - 0.9, z0), Vector3(-1, 0, 0))
    b.quad("conc", _v(x1, y1, z1), _v(x1, y0, z0), _v(x1, y0 - 0.9, z0), _v(x1, y1 - 0.9, z1), Vector3(1, 0, 0))
    b.slope_collider(x0, x1, z0, z1, y0, y1)

# ------------------------------------------------------------------ 房间
func rooms() -> void:
    # 信号室
    var rx1 := -14.2; var rz0 := 24.0; var rz1 := 32.5; var rh := 3.2
    var dz0 := 27.0; var dz1 := 29.6
    b.box("panel", _v(rx1 - 0.22, FY, rz0), _v(rx1, rh, dz0), true)
    b.box("panel", _v(rx1 - 0.22, FY, dz1), _v(rx1, rh, rz1), true)
    b.box("panel", _v(rx1 - 0.22, 2.30, dz0), _v(rx1, rh, dz1), true)
    b.box("panel", _v(PX0, FY, rz0 - 0.22), _v(rx1, rh, rz0), true)
    b.box("panel", _v(PX0, FY, rz1), _v(rx1, rh, rz1 + 0.22), true)
    b.box("ceil", _v(PX0, rh, rz0 - 0.22), _v(rx1 + 0.22, rh + 0.45, rz1 + 0.22), true, "b")
    b.box("metalD", _v(PX0, FY - 0.18, rz0), _v(rx1, FY + 0.02, rz1), false, "t")
    relay_cabinet(PX0 + 0.15, rz0 + 0.55, PX0 + 1.05, rz1 - 0.55, 2.05)
    b.box("lamp", _v(rx1 - 2.6, rh - 0.15, 26.0), _v(rx1 - 0.5, rh - 0.04, 26.45), false, "b")
    b.light(_v(-16.2, 2.4, 26.2), Color(0.90, 0.70, 0.45), 2.8, 9.0, true)
    # 南半间的第二盏顶灯：继电器柜全长 7.4 m，一盏灯照不到南端
    b.box("lamp", _v(rx1 - 2.6, rh - 0.15, 29.9), _v(rx1 - 0.5, rh - 0.04, 30.35), false, "b")
    b.light(_v(-16.2, 2.4, 30.15), Color(0.90, 0.70, 0.45), 2.6, 9.0, false)
    # 值班室 / 广播台（带门洞，门由 game.gd 装）
    small_room(-11.00, 2.5, 14.5, 3.5, 7.6, 9.6, "值班室", "duty")
    small_room(-11.50, 33.0, 45.0, 3.3, 37.6, 39.6, "广播台", "studio")
    # 总调度手柄底座
    b.box("metalD", _v(-16.96, FY, 30.42), _v(-16.44, 1.02, 31.18), true)

func small_room(x1: float, z0: float, z1: float, h: float, dz0: float, dz1: float, nm: String, kind := "duty") -> void:
    # ---- 墙体 ----
    b.box("panel", _v(PX0, FY, z0 - 0.22), _v(x1, h, z0), true)
    b.box("panel", _v(PX0, FY, z1), _v(x1, h, z1 + 0.22), true)
    b.box("panel", _v(x1 - 0.22, FY, z0), _v(x1, h, dz0), true)
    b.box("panel", _v(x1 - 0.22, FY, dz1), _v(x1, h, z1), true)
    b.box("panel", _v(x1 - 0.22, 2.25, dz0), _v(x1, h, dz1), true)
    b.box("ceil", _v(PX0, h, z0 - 0.22), _v(x1 + 0.22, h + 0.45, z1 + 0.22), true, "b")
    b.box("metalD", _v(PX0 + 0.05, FY - 0.18, z0 + 0.05), _v(x1 - 0.22, FY + 0.02, z1 - 0.05), false, "t")
    # ---- 灯 ----
    b.box("lamp", _v(x1 - 3.0, h - 0.14, (z0 + z1) * 0.5 - 0.2), _v(x1 - 1.2, h - 0.04, (z0 + z1) * 0.5 + 0.2), false, "b")
    b.light(_v((PX0 + x1) * 0.5, h - 0.7, (z0 + z1) * 0.5), Color(0.88, 0.64, 0.29), 3.2, 9.5, false)
    b.plaque(nm, _v(x1 - 0.01, 1.78, dz1 + 0.62), 0.66, 0.20, "x", 1, Color(0.45, 0.72, 0.95))
    # ---- 家具：全部贴墙，门前 x1-2.4 之内留空 ----
    cabinet(PX0 + 0.15, z0 + 0.5, PX0 + 0.95, z1 - 0.5, 1.05)          # 后墙一排矮柜
    if kind == "duty":
        desk(x1 - 6.2, z0 + 0.28, x1 - 4.2, z0 + 2.48)                # 靠北墙办公桌
        chair(x1 - 5.4, z0 + 1.45, FY, PI * 0.5)
        locker(PX0 + 1.05, z1 - 2.7, PX0 + 1.95, z1 - 0.45, 1.9)      # 立式更衣柜
        desk(x1 - 4.4, z1 - 3.7, x1 - 2.6, z1 - 1.3)                  # 南侧会议桌
        chair(x1 - 4.85, z1 - 2.5, FY, -PI * 0.5)
        chair(x1 - 2.15, z1 - 2.5, FY, PI * 0.5)
        # 饮水机：圆角机箱 + 接水盘 + 冷热出水灯 + 半透明水桶
        b.box("metalD", _v(PX0 + 2.15, FY, z1 - 1.05), _v(PX0 + 2.80, 0.95, z1 - 0.45), true, "all", 0.035)
        b.box("dark", _v(PX0 + 2.28, 0.42, z1 - 1.09), _v(PX0 + 2.67, 0.80, z1 - 1.04), false)
        b.box("lampC", _v(PX0 + 2.31, 0.56, z1 - 1.10), _v(PX0 + 2.43, 0.63, z1 - 1.06), false, "k")
        b.box("red", _v(PX0 + 2.52, 0.56, z1 - 1.10), _v(PX0 + 2.64, 0.63, z1 - 1.06), false, "k")
        b.box("metalD", _v(PX0 + 2.26, 0.30, z1 - 1.14), _v(PX0 + 2.69, 0.345, z1 - 1.01), false)
        b.cyl("glass|dcefff", PX0 + 2.475, z1 - 0.75, 0.95, 1.06, 0.095, 0.095, 10, true, false)
        b.cyl("glass|dcefff", PX0 + 2.475, z1 - 0.75, 1.06, 1.44, 0.195, 0.155, 12, true, false)
        b.cyl("glass|dcefff", PX0 + 2.475, z1 - 0.75, 1.44, 1.50, 0.155, 0.095, 12, true, false)
    else:
        desk(x1 - 5.6, z0 + 0.30, x1 - 3.6, z0 + 2.00, 0.92)          # 调音台
        chair(x1 - 4.25, z0 + 1.30, FY, PI * 0.5)
        cabinet(PX0 + 1.05, z1 - 3.5, PX0 + 2.00, z1 - 0.5, 1.8)      # 磁带架
        for i in range(4):
            b.box("dark", _v(PX0 + 1.10, 0.25 + float(i) * 0.36, z1 - 3.45), _v(PX0 + 1.95, 0.33 + float(i) * 0.36, z1 - 0.55), false)
        b.box("glass", _v(x1 - 0.16, 1.15, dz1 + 0.7), _v(x1 - 0.07, 2.15, z1 - 0.4), false, "p")   # 观察窗
        b.box("lampC", _v(x1 - 0.20, 2.35, dz1 + 0.8), _v(x1 - 0.10, 2.44, z1 - 0.5), false, "p")

func dispatch_console(x0: float, z0: float, x1: float, z1: float) -> void:
    # Blender 生成的低多边形调度台（assets/props/console.glb）
    # 模型 4.20 长 × 1.89 深 × 1.77 高，正面朝 +Y → 导入 Godot 后朝 -Z，转 -90° 让正面朝 +X
    var c := Vector3((x0 + x1) * 0.5, FY, (z0 + z1) * 0.5)
    b.prop("res://assets/props/console.glb", c, -PI * 0.5)
    b.add_collider(Vector3(x0, FY, z0), Vector3(x1, 1.15, z1))
    b.light(_v(x0 + 0.8, 3.1, (z0 + z1) * 0.5), Color(0.85, 0.90, 1.0), 3.4, 9.0, false)   # 夜班调度席灯

func relay_cabinet(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    # 五号继电器柜（7.40 m 长）：
    #   踢脚 → 圆角柜体 → 门框与三副铰链 → 玻璃观察窗（上腔五排继电器 / 下腔端子排）
    #   → 铭牌 → 柜内灯带 → 柜顶指示灯 → 底部电缆槽
    var zc := (z0 + z1) * 0.5
    var xd := x1 + 0.17                      # 柜门面（玻璃 / 门框）所在的 x
    var yD0 := FY + 0.20                     # 门体下沿
    var yD1 := h - 0.05                      # 门体上沿
    var yw0 := FY + 0.46                     # 观察窗下沿
    var yw1 := 1.78                          # 观察窗上沿
    var zw0 := z0 + 0.34                     # 观察窗北沿
    var zw1 := z1 - 0.28                     # 观察窗南沿
    var ymid := 0.88                         # 上下两腔的分界横档
    # ---- 踢脚 + 圆角柜体（正面留给柜门，故单独加一个整柜碰撞盒）----
    b.box("dark", _v(x0 + 0.05, FY, z0 + 0.05), _v(x1 - 0.05, FY + 0.10, z1 - 0.05), false)
    b.box("metalD", _v(x0, FY + 0.10, z0), _v(x1, h, z1), false, "all", 0.045)
    b.add_collider(_v(x0, FY, z0), _v(xd + 0.06, h, z1))
    # ---- 柜门内衬：浅色背板，让继电器和端子排读得出来 ----
    b.box("panel", _v(x1, FY + 0.16, zw0 - 0.04), _v(x1 + 0.014, yw1 + 0.04, zw1 + 0.04), false, "p")
    # ---- 门框：上 / 下 / 北 / 南 四条压条 ----
    for bar in [[yD0, yw0, z0 + 0.06, z1 - 0.06], [yw1, yD1, z0 + 0.06, z1 - 0.06],
                [yw0, yw1, z0 + 0.06, zw0], [yw0, yw1, zw1, z1 - 0.06]]:
        b.box("metalD", _v(xd - 0.014, bar[0], bar[2]), _v(xd + 0.014, bar[1], bar[3]), false, "all", 0.010)
    # ---- 玻璃观察窗 + 上下腔分界横档 + 下腔小铭牌 ----
    b.box("glass", _v(xd - 0.007, yw0, zw0), _v(xd + 0.007, yw1, zw1), false)
    b.box("metalD", _v(xd - 0.017, ymid - 0.045, zw0), _v(xd + 0.017, ymid + 0.045, zw1), false, "all", 0.010)
    b.plaque("端子排", _v(xd + 0.016, yw0 - 0.085, zc), 0.38, 0.12, "x", 1, Color(0.62, 0.78, 0.95))
    # ---- 上腔：五排继电器（第 5 排是坏的那一排，指示灯转红）----
    var rstep := (zw1 - 0.10 - (zw0 + 0.10) - 0.34) / 9.0
    for i in range(5):
        var ry := 1.02 + float(i) * 0.17
        b.box("dark", _v(x1 + 0.014, ry - 0.062, zw0 + 0.06), _v(x1 + 0.105, ry + 0.062, zw1 - 0.06), false)
        for k in range(10):
            var rz := zw0 + 0.10 + float(k) * rstep
            b.box("metal", _v(x1 + 0.105, ry - 0.046, rz), _v(x1 + 0.140, ry + 0.046, rz + 0.34), false)
        b.box("red" if i == 4 else "lampC", _v(x1 + 0.140, ry - 0.058, zw0 + 0.10),
            _v(x1 + 0.157, ry - 0.030, zw1 - 0.10), false, "p")
        b.label3d(str(i + 1), _v(x1 + 0.145, ry + 0.028, zw0 + 0.045), 0.115,
                Color(0.98, 0.42, 0.36) if i == 4 else Color(0.86, 0.90, 0.96), PI * 0.5)
    b.box("lamp", _v(x1 + 0.100, yw1 - 0.045, zw0 + 0.15), _v(x1 + 0.140, yw1 - 0.010, zw1 - 0.15), false)
    # ---- 下腔：端子排（14 组）----
    var tstep := (zw1 - 0.16 - (zw0 + 0.16) - 0.30) / 13.0
    b.box("dark", _v(x1 + 0.014, 0.50, zw0 + 0.05), _v(x1 + 0.085, 0.76, zw1 - 0.05), false)
    for k in range(14):
        var tz := zw0 + 0.16 + float(k) * tstep
        b.box("metal", _v(x1 + 0.085, 0.53, tz), _v(x1 + 0.128, 0.73, tz + 0.30), false)
        b.box("dark", _v(x1 + 0.128, 0.595, tz + 0.05), _v(x1 + 0.140, 0.665, tz + 0.25), false, "p")
    b.box("lamp", _v(x1 + 0.085, 0.775, zw0 + 0.15), _v(x1 + 0.125, 0.812, zw1 - 0.15), false)
    # ---- 三副铰链（北端）----
    for hy in [0.52, 1.16, 1.72]:
        b.cyl("metal", xd + 0.010, z0 + 0.15, hy - 0.10, hy + 0.10, 0.026, 0.026, 8, true, true)
        b.box("dark", _v(xd - 0.014, hy - 0.035, z0 + 0.09), _v(xd + 0.012, hy + 0.035, z0 + 0.21), false)
    # ---- 把手 + 锁（南端）----
    b.box("metal", _v(xd + 0.014, 0.98, z1 - 0.20), _v(xd + 0.048, 1.30, z1 - 0.14), false)
    for hy2 in [1.02, 1.26]:
        b.box("metalD", _v(xd, hy2, z1 - 0.20), _v(xd + 0.020, hy2 + 0.04, z1 - 0.14), false)
    b.box("dark", _v(xd + 0.014, 0.84, z1 - 0.21), _v(xd + 0.028, 0.94, z1 - 0.13), false)
    # ---- 铭牌（带四颗螺钉）+ 柜顶指示灯 ----
    b.plaque("五号继电器", _v(xd + 0.014, 1.90, zc), 0.72, 0.19, "x", 1, Color(0.94, 0.52, 0.46))
    for sx in [-0.30, 0.30]:
        b.box("metal", _v(xd + 0.014, 1.852, zc + sx - 0.012), _v(xd + 0.030, 1.948, zc + sx + 0.012), false, "p")
    for lp in [[zw0 + 0.24, "lamp"], [zw1 - 0.62, "red"]]:
        var lz0: float = lp[0]
        b.box("dark", _v(xd + 0.006, 1.820, lz0), _v(xd + 0.030, 1.960, lz0 + 0.38), false)
        b.box(lp[1], _v(xd + 0.026, 1.836, lz0 + 0.04), _v(xd + 0.062, 1.944, lz0 + 0.34), false, "all", 0.010)
    # ---- 底部电缆槽：槽体 + 两根电缆 + 六副支架 ----
    b.box("dark", _v(xd - 0.13, FY + 0.02, z0 + 0.10), _v(xd + 0.02, FY + 0.055, z1 - 0.10), false)
    for wx in [xd - 0.13, xd - 0.005]:
        b.box("metalD", _v(wx, FY + 0.055, z0 + 0.10), _v(wx + 0.025, FY + 0.175, z1 - 0.10), false)
    for cy in [0.100, 0.132]:
        b.cyl_z("dark", xd - 0.070, FY + cy, z0 + 0.16, z1 - 0.16, 0.021, 8, true)
    for k in range(6):
        var bz := z0 + 0.55 + float(k) * 1.26
        b.box("metalD", _v(xd - 0.145, FY + 0.175, bz), _v(xd + 0.030, FY + 0.198, bz + 0.06), false)
    # ---- 柜内照明：三盏小灯（把五排继电器和端子排照出来）----
    for lz in [z0 + 1.9, zc, z1 - 1.9]:
        b.light(_v(x1 + 0.09, 1.52, lz), Color(0.95, 0.88, 0.74), 1.9, 2.8, false)
func bench(x0: float, z0: float, x1: float, z1: float, base := FY) -> void:
    # 长椅：木条坐板 + 木条靠背 + 圆管腿 / 圆管横撑
    var ySeat := base + 0.44
    var zc := (z0 + z1) * 0.5
    for i in range(3):
        var xx := x0 + 0.05 + float(i) * 0.30
        b.box("wood", _v(xx, ySeat, z0), _v(xx + 0.24, ySeat + 0.05, z1), false, "all", 0.015)
    for i in range(2):
        var y := base + 0.62 + float(i) * 0.20
        var xx2 := x0 + 0.02 - float(i) * 0.045
        b.box("wood", _v(xx2, y, z0), _v(xx2 + 0.15, y + 0.14, z1), false, "all", 0.020)
    for zz in [z0 + 0.22, zc, z1 - 0.22]:
        for xx3 in [x0 + 0.10, x1 - 0.10]:
            b.cyl("metalD", xx3, zz, base, ySeat, 0.032, 0.032, 8, false, false)
        b.box("metalD", _v(x0 + 0.03, ySeat - 0.05, zz - 0.03), _v(x1 - 0.03, ySeat, zz + 0.03), false)
        b.cyl("metalD", x0 + 0.04, zz, ySeat, base + 1.00, 0.030, 0.030, 8, false, false)
    for xx4 in [x0 + 0.10, x1 - 0.10]:
        b.cyl_z("metalD", xx4, base + 0.36, z0 + 0.16, z1 - 0.16, 0.026, 8, true)
    b.add_collider(_v(x0, base, z0), _v(x1, base + 0.50, z1))
    b.light(_v(x0 + 0.50, base + 1.42, zc), Color(0.92, 0.86, 0.76), 3.2, 3.8, false)
    b.seats.append({"pos": Vector3(x0 + 0.62, base, z0 + (z1 - z0) * 0.30), "yaw": -PI * 0.5})
    b.seats.append({"pos": Vector3(x0 + 0.62, base, z0 + (z1 - z0) * 0.70), "yaw": -PI * 0.5})

func vending(x0: float, z0: float, x1: float, z1: float, base := FY) -> void:
    # 自动售货机：圆角外壳 → 玻璃橱窗（三层货道 / 商品 / 价签）→ 取货口 → 面板与退币口 → 顶部灯箱
    var h := base + 1.95
    var hz := base + 1.64
    var xf := x1 + 0.20                      # 机器正面（玻璃 / 面板）所在的 x
    var zw0 := z0 + 0.10                     # 橱窗北沿
    var zw1 := z1 - 0.78                     # 橱窗南沿（南边留给面板）
    b.box("dark", _v(x0 + 0.05, base, z0 + 0.05), _v(x1 - 0.05, base + 0.09, z1 - 0.05), false)
    b.box("metalD", _v(x0, base + 0.09, z0), _v(x1, hz, z1), false, "all", 0.055)
    b.box("metalD", _v(x0, hz, z0 + 0.04), _v(x1, h, z1 - 0.04), false, "all", 0.050)
    b.add_collider(_v(x0, base, z0), _v(xf + 0.04, h, z1))
    # ---- 橱窗：深色内衬 + 三层货道 ----
    b.box("dark", _v(x1, base + 0.44, zw0), _v(x1 + 0.008, base + 1.60, zw1), false, "p")
    for si in range(3):
        var sy := base + 0.62 + float(si) * 0.34
        b.box("metal", _v(x1 + 0.008, sy, zw0 + 0.02), _v(x1 + 0.19, sy + 0.022, zw1 - 0.02), false, "t")
        b.box("lampC", _v(x1 + 0.170, sy + 0.024, zw0 + 0.04), _v(x1 + 0.190, sy + 0.062, zw1 - 0.04), false, "p")
        for gi in range(3):
            var gz := zw0 + 0.08 + float(gi) * 0.42
            b.box(["red", "lamp", "lampC", "exit"][(si + gi) % 4],
                  _v(x1 + 0.020, sy + 0.024, gz), _v(x1 + 0.165, sy + 0.345, gz + 0.30), false)
    # ---- 玻璃 + 上下压条 ----
    b.box("glass", _v(xf - 0.010, base + 0.46, zw0 - 0.02), _v(xf + 0.006, base + 1.62, zw1 + 0.02), false)
    b.box("metalD", _v(xf - 0.020, base + 0.42, zw0 - 0.04), _v(xf + 0.012, base + 0.48, zw1 + 0.04), false)
    b.box("metalD", _v(xf - 0.020, base + 1.60, zw0 - 0.04), _v(xf + 0.012, base + 1.66, zw1 + 0.04), false)
    # ---- 取货口（带挡板）----
    b.box("dark", _v(xf - 0.055, base + 0.20, z0 + 0.34), _v(xf + 0.006, base + 0.44, zw1 - 0.06), false)
    b.box("metalD", _v(xf - 0.06, base + 0.44, z0 + 0.32), _v(xf + 0.016, base + 0.50, zw1 - 0.04), false, "t")
    b.box("metalD", _v(xf - 0.06, base + 0.20, z0 + 0.32), _v(xf + 0.016, base + 0.24, zw1 - 0.04), false, "b")
    # ---- 面板：显示屏 + 按键 + 退币口 ----
    b.box("dark", _v(xf - 0.035, base + 1.00, zw1 + 0.04), _v(xf + 0.006, base + 1.58, z1 - 0.10), false)
    b.box("sign", _v(xf - 0.001, base + 1.34, zw1 + 0.10), _v(xf + 0.010, base + 1.52, z1 - 0.18), false, "p")
    for i in range(6):
        b.box("metalD", _v(xf - 0.001, base + 1.06 + float(i % 3) * 0.09, zw1 + 0.12 + float(i / 3) * 0.24),
              _v(xf + 0.010, base + 1.13 + float(i % 3) * 0.09, zw1 + 0.20 + float(i / 3) * 0.24), false, "p")
    b.box("dark", _v(xf - 0.001, base + 0.90, zw1 + 0.14), _v(xf + 0.012, base + 0.97, zw1 + 0.46), false, "p")
    b.box("lampC", _v(xf + 0.011, base + 0.925, zw1 + 0.18), _v(xf + 0.020, base + 0.945, zw1 + 0.42), false, "p")
    b.box("dark", _v(xf - 0.001, base + 0.78, z1 - 0.44), _v(xf + 0.012, base + 0.85, z1 - 0.16), false, "p")
    # ---- 顶部灯箱 + 铭牌 ----
    b.box("lamp", _v(xf - 0.012, h - 0.28, z0 + 0.14), _v(xf + 0.010, h - 0.10, z1 - 0.14), false, "p")
    b.plaque("自动售货", _v(xf + 0.006, h - 0.19, (zw0 + zw1) * 0.5), 0.58, 0.16, "x", 1, Color(0.58, 0.82, 1.0))
    b.light(_v(x1 + 0.10, base + 1.24, (zw0 + zw1) * 0.5), Color(0.72, 0.86, 1.0), 1.7, 2.6, false)
    b.light(_v(xf + 0.55, base + 1.30, z1 - 0.40), Color(0.78, 0.86, 1.0), 1.4, 2.6, false)

func bin(cx: float, cz: float, base := FY) -> void:
    # 垃圾桶：圆桶身 + 桶箍 + 压圈 + 内胆 + 烟灰盘
    b.cyl("dark", cx, cz, base, base + 0.03, 0.23, 0.24, 12, false, false)
    b.cyl("metalD", cx, cz, base + 0.03, base + 0.70, 0.235, 0.245, 12, false, false)
    b.cyl("metal", cx, cz, base + 0.30, base + 0.335, 0.240, 0.243, 12, false, false)
    b.cyl("metal", cx, cz, base + 0.55, base + 0.585, 0.243, 0.246, 12, false, false)
    b.cyl("dark", cx, cz, base + 0.70, base + 0.735, 0.248, 0.248, 12, false, false)
    b.cyl("metal", cx, cz, base + 0.735, base + 0.775, 0.252, 0.242, 12, true, false)
    b.cyl("dark", cx, cz, base + 0.735, base + 0.90, 0.205, 0.200, 12, true, false)
    b.cyl("metalD", cx, cz, base + 0.90, base + 0.955, 0.215, 0.205, 12, true, false)
    for i in range(4):
        var a := TAU * float(i) / 4.0 + 0.4
        b.box("dark", _v(cx + cos(a) * 0.10 - 0.022, base + 0.930, cz + sin(a) * 0.10 - 0.022),
              _v(cx + cos(a) * 0.10 + 0.022, base + 0.958, cz + sin(a) * 0.10 + 0.022), false)
    b.add_collider(_v(cx - 0.27, base, cz - 0.27), _v(cx + 0.27, base + 0.98, cz + 0.27))

func turnstile(cx: float, cz: float, base := FY) -> void:
    # 闸机：底座法兰 + 圆柱立柱 + 三辊 + 刷卡面板 + 状态灯
    var h := base + 1.02
    b.cyl("dark", cx, cz, base, base + 0.05, 0.30, 0.29, 12, true, false)
    b.cyl("metalD", cx, cz, base + 0.05, h, 0.185, 0.176, 12, true, false)
    b.cyl("metal", cx, cz, h, h + 0.11, 0.198, 0.186, 12, true, false)
    b.cyl("lampC", cx, cz, base + 0.90, base + 0.965, 0.184, 0.184, 12, false, false)
    b.cyl("red", cx, cz, base + 0.815, base + 0.875, 0.184, 0.184, 12, false, false)
    b.add_collider(_v(cx - 0.30, base, cz - 0.30), _v(cx + 0.30, h + 0.11, cz + 0.30))
    # 刷卡面板（朝 -Z：乘客从站台侧走过来）
    b.box("dark", _v(cx - 0.14, base + 0.50, cz - 0.21), _v(cx + 0.14, base + 0.80, cz - 0.172), false)
    b.box("sign", _v(cx - 0.12, base + 0.58, cz - 0.220), _v(cx + 0.12, base + 0.76, cz - 0.208), false, "k")
    b.box("lampC", _v(cx - 0.03, base + 0.53, cz - 0.220), _v(cx + 0.03, base + 0.565, cz - 0.208), false, "k")
    b.box("metalD", _v(cx - 0.16, base + 0.84, cz - 0.20), _v(cx + 0.16, base + 0.88, cz - 0.14), false, "t")
    # 三辊：三根圆管绕立柱 120 度分布
    for i in range(3):
        var a := TAU * float(i) / 3.0 + 0.35
        b.cyl_dir("metal", Vector3(cx + cos(a) * 0.40, base + 0.90, cz + sin(a) * 0.40),
                  a, 0.62, 0.030, 8, true)

func cabinet(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    b.box("metalD", _v(x0, FY, z0), _v(x1, h, z1), true, "all", 0.040)
    b.box("dark", _v(x0, h * 0.42, z0 - 0.01), _v(x1, h * 0.46, z1 + 0.01), false)
    var n := int(maxf(1.0, (z1 - z0) / 0.55))
    for i in range(n):
        var zz := z0 + (z1 - z0) * (float(i) + 0.5) / float(n)
        b.box("dark", _v(x1 - 0.02, 0.08, zz - 0.02), _v(x1 + 0.01, h - 0.08, zz + 0.02), false)
        b.cyl_z("lampC", x1 + 0.025, h * 0.55, zz - 0.05, zz + 0.05, 0.016, 8, true)

func locker(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    b.box("metalD", _v(x0, FY, z0), _v(x1, h, z1), true, "all", 0.040)
    for i in range(3):
        var zz := z0 + (z1 - z0) * (float(i) + 0.5) / 3.0
        b.box("dark", _v(x1 - 0.02, 0.06, zz - 0.02), _v(x1 + 0.01, h - 0.06, zz + 0.02), false)
        b.cyl_z("lampC", x1 + 0.025, h * 0.50, zz - 0.06, zz + 0.06, 0.016, 8, true)
        b.box("metalD", _v(x1 - 0.01, h * 0.72, zz - 0.12), _v(x1 + 0.012, h * 0.75, zz + 0.12), false, "p")
    b.box("dark", _v(x0, h - 0.06, z0), _v(x1, h, z1), false)

func desk(x0: float, z0: float, x1: float, z1: float, h := 0.76, base := FY) -> void:
    b.box("metalD", _v(x0, h - 0.05, z0), _v(x1, h, z1), false, "all", 0.030)      # 台面（圆角）
    b.add_collider(_v(x0, base, z0), _v(x1, h, z1))
    b.box("dark", _v(x0 + 0.04, base + 0.08, z0 + 0.04), _v(x1 - 0.04, h - 0.05, z0 + 0.10), false)
    b.box("dark", _v(x0 + 0.04, base + 0.08, z1 - 0.10), _v(x1 - 0.04, h - 0.05, z1 - 0.04), false)
    b.box("metalD", _v(x1 - 0.55, base + 0.42, z0 + 0.06), _v(x1 - 0.06, h - 0.05, z1 - 0.06), true, "all", 0.028)
    b.box("dark", _v(x1 - 0.53, base + 0.52, z0 + 0.05), _v(x1 - 0.08, base + 0.58, z1 - 0.05), false)
    b.cyl_z("lampC", x1 - 0.048, base + 0.60, z0 + 0.10, z1 - 0.10, 0.016, 8, true)
    b.box("dark", _v(x0 + 0.10, base + 0.20, z0 + 0.12), _v(x1 - 0.60, base + 0.24, z1 - 0.12), false)

func chair(cx: float, cz: float, base := FY, yaw := 0.0) -> void:
    var c := Vector3(cx, base, cz)
    var ca := cos(yaw)
    var sa := sin(yaw)
    var R := func(l: Vector3) -> Vector3: return Vector3(c.x + l.x * ca + l.z * sa, c.y + l.y, c.z - l.x * sa + l.z * ca)
    b.box_rot("dark", R.call(Vector3(0, 0.44, 0)), Vector3(0.46, 0.05, 0.46), yaw, false)          # 座面
    b.box_rot("metalD", R.call(Vector3(0, 0.415, 0)), Vector3(0.40, 0.03, 0.40), yaw, false)        # 座面下框
    b.box_rot("dark", R.call(Vector3(0, 0.68, 0.20)), Vector3(0.44, 0.40, 0.07), yaw, false)        # 靠背
    for dx in [-0.18, 0.18]:
        for dz in [-0.18, 0.18]:
            var p: Vector3 = R.call(Vector3(dx, 0, dz))
            b.cyl("metalD", p.x, p.z, base, base + 0.42, 0.024, 0.024, 8, false, false)             # 圆管腿
    for dx2 in [-0.16, 0.16]:
        var p2: Vector3 = R.call(Vector3(dx2, 0, 0.19))
        b.cyl("metalD", p2.x, p2.z, base + 0.44, base + 0.90, 0.022, 0.022, 8, false, false)        # 靠背立杆
    b.add_collider(_v(cx - 0.30, base, cz - 0.30), _v(cx + 0.30, base + 0.50, cz + 0.30))
    b.seats.append({"pos": Vector3(cx - sin(yaw) * 0.02, base, cz - cos(yaw) * 0.02), "yaw": yaw})

# ------------------------------------------------------------------ 站体细节构件
## 门套：门洞两侧门边 + 门楣（向 +X 凸出 0.13）
func door_frame(x: float, dz0: float, dz1: float, dh: float) -> void:
    var t := 0.08
    for zz in [dz0 - t, dz1]:
        b.box("metalD", _v(x - 0.02, FY, zz), _v(x + 0.13, dh + 0.09, zz + t), false, "all", 0.018)
    b.box("metalD", _v(x - 0.02, dh + 0.01, dz0 - t), _v(x + 0.13, dh + 0.09, dz1 + t), false, "all", 0.018)

## 圆管栏杆（沿 x 方向一道）
func railing(x0: float, x1: float, z: float) -> void:
    var n := int(maxf(1.0, absf(x1 - x0) / 2.0))
    for i in range(n + 1):
        var x := lerpf(x0, x1, float(i) / float(n))
        b.cyl("metal", x, z, FY, FY + 1.06, 0.036, 0.030, 8, true, false)
    for yy in [FY + 1.00, FY + 0.58]:
        b.cyl_dir("metal", Vector3((x0 + x1) * 0.5, yy, z), 0.0, absf(x1 - x0), 0.030, 8, true)
    b.cyl_dir("metal", Vector3((x0 + x1) * 0.5, FY + 0.20, z), 0.0, absf(x1 - x0), 0.022, 8, true)
    b.add_collider(_v(minf(x0, x1), FY, z - 0.06), _v(maxf(x0, x1), FY + 1.06, z + 0.06))

## 圆管栏杆（沿 z 方向一道，站在 y_base 的台面上）
func railing_z(x: float, z0: float, z1: float, y_base: float) -> void:
    var n := int(maxf(1.0, absf(z1 - z0) / 2.0))
    for i in range(n + 1):
        var z := lerpf(z0, z1, float(i) / float(n))
        b.cyl("metal", x, z, y_base, y_base + 1.00, 0.036, 0.030, 8, true, false)
    for yy in [y_base + 0.94, y_base + 0.54]:
        b.cyl_z("metal", x, yy, z0, z1, 0.030, 8, true)
    b.add_collider(_v(x - 0.06, y_base, minf(z0, z1)), _v(x + 0.06, y_base + 1.00, maxf(z0, z1)))

## 标牌包边：面板四周一圈金属边框
func sign_frame(cx: float, cy: float, w: float, h: float, z: float, depth: float) -> void:
    var t := 0.07
    var hw := w * 0.5
    var hh := h * 0.5
    var z0 := z - depth * 0.5 - 0.02
    var z1 := z + depth * 0.5 + 0.02
    b.box("metal", _v(cx - hw - t, cy + hh, z0), _v(cx + hw + t, cy + hh + t, z1), false)
    b.box("metal", _v(cx - hw - t, cy - hh - t, z0), _v(cx + hw + t, cy - hh, z1), false)
    b.box("metal", _v(cx - hw - t, cy - hh, z0), _v(cx - hw, cy + hh, z1), false)
    b.box("metal", _v(cx + hw, cy - hh, z0), _v(cx + hw + t, cy + hh, z1), false)

# ------------------------------------------------------------------ 站体细节
func details() -> void:
    # 三处门洞的门套
    door_frame(-14.20, 27.00, 29.60, 2.24)
    door_frame(-11.00, 7.60, 9.60, 2.19)
    door_frame(-11.50, 37.60, 39.60, 2.19)
    # 站台端头圆管栏杆：北端一整道；南端留 3.2 m 检修口
    railing(-17.30, -0.90, -54.40)
    railing(-17.30, -9.10, 49.30)
    railing(-5.90, -0.90, 49.30)
    # 检修环线检修走道栏杆
    railing_z(10.45, -64.60, -58.30, TY + 0.25)
    # 后墙分缝：每 2.4 m 一道竖缝 + 一道通长横缝
    var zz := ZS0 + 1.2
    while zz < ZS1 - 0.6:
        b.box("dark", _v(PX0 + 0.005, FY + 0.02, zz - 0.012), _v(PX0 + 0.030, CH - 0.10, zz + 0.012), false, "p")
        zz += 2.4
    b.box("metalD", _v(PX0 + 0.005, 2.62, ZS0), _v(PX0 + 0.030, 2.68, ZS1), false, "p")
    # 柱脚防撞条：黄环 + 黑胶环
    for i in range(8):
        var cz := -40.0 + float(i) * 12.0
        b.cyl("hazard", -8.60, cz, FY + 0.13, FY + 0.28, 0.475, 0.475, 14, false, false)
        b.cyl("rubber", -8.60, cz, FY + 0.28, FY + 0.36, 0.462, 0.462, 14, false, false)

# ------------------------------------------------------------------ 隧道口 / 电缆桥架 / 检修梯
## 洞口拱圈：比洞身略大一圈的收边
func arch_ring(z: float, depth: float) -> void:
    var ri := BORE_R + 0.01
    var ro := BORE_R + 0.17
    var segs := 18
    var cen := Vector3(4.0, BORE_SP, 0.0)
    for i in range(segs):
        var a0: float = PI * (1.0 - float(i) / float(segs))
        var a1: float = PI * (1.0 - float(i + 1) / float(segs))
        var am := (a0 + a1) * 0.5
        var n := Vector3(cos(am), sin(am), 0.0).normalized()
        var o0 := cen + Vector3(cos(a0), sin(a0), 0.0) * ro
        var o1 := cen + Vector3(cos(a1), sin(a1), 0.0) * ro
        var q0 := cen + Vector3(cos(a0), sin(a0), 0.0) * ri
        var q1 := cen + Vector3(cos(a1), sin(a1), 0.0) * ri
        b.quad("conc", Vector3(o0.x, o0.y, z), Vector3(o1.x, o1.y, z), Vector3(o1.x, o1.y, z + depth), Vector3(o0.x, o0.y, z + depth), n)
        b.quad("conc", Vector3(q1.x, q1.y, z), Vector3(q0.x, q0.y, z), Vector3(q0.x, q0.y, z + depth), Vector3(q1.x, q1.y, z + depth), -n)
        b.quad("conc", Vector3(q0.x, q0.y, z), Vector3(q1.x, q1.y, z), Vector3(o1.x, o1.y, z), Vector3(o0.x, o0.y, z), Vector3(0, 0, -1))
        b.quad("conc", Vector3(o0.x, o0.y, z + depth), Vector3(o1.x, o1.y, z + depth), Vector3(q1.x, q1.y, z + depth), Vector3(q0.x, q0.y, z + depth), Vector3(0, 0, 1))

func tunnel_detail() -> void:
    # 两个隧道口的拱形收边
    arch_ring(ZS0 - 0.55, 0.55)
    arch_ring(ZS1, 0.55)
    # 电缆桥架：隧道东壁的梯式桥架 + 两根电缆 + 支架
    var bx := TX1 - 0.45
    var by := TY + 3.05
    b.box("metalD", _v(bx - 0.32, by, -122.0), _v(bx + 0.02, by + 0.05, -58.0), false)
    b.box("metalD", _v(bx - 0.32, by, -122.0), _v(bx - 0.27, by + 0.24, -58.0), false)
    b.box("metalD", _v(bx - 0.03, by, -122.0), _v(bx + 0.02, by + 0.24, -58.0), false)
    b.cyl_z("dark", bx - 0.22, by + 0.11, -122.0, -58.0, 0.032, 8, true)
    b.cyl_z("dark", bx - 0.10, by + 0.11, -122.0, -58.0, 0.032, 8, true)
    var tz := -121.0
    while tz < -58.0:
        b.box("metalD", _v(bx - 0.30, by + 0.17, tz), _v(bx, by + 0.23, tz + 0.06), false)
        b.box("metalD", _v(bx + 0.00, by - 0.04, tz), _v(bx + 0.30, by + 0.02, tz + 0.06), false)
        tz += 3.5
    # 洞口附近的检修梯（圆管横档 + 圆管立杆）
    for i in range(8):
        var ly := TY + 0.32 + float(i) * 0.34
        b.cyl_dir("metal", Vector3(6.55, ly, -59.5), 0.0, 0.56, 0.020, 8, true)
    for lx in [6.29, 6.81]:
        b.cyl("metal", lx, -59.5, TY, TY + 2.94, 0.026, 0.026, 8, true, true)

# ------------------------------------------------------------------ 标识
func signage() -> void:
    # 出口卷帘 + 闸机
    b.box("metalD", _v(PX0, FY, ZS1 - 6.0), _v(TX0, 3.1, ZS1 - 5.6), true)
    for i in range(12):
        b.box("metalD", _v(PX0 + 0.02, FY + 0.02 + float(i) * 0.26, ZS1 - 5.98), _v(TX0 - 0.02, FY + 0.20 + float(i) * 0.26, ZS1 - 5.62), false)
    b.box("hazard", _v(PX0, 1.35, ZS1 - 6.02), _v(TX0, 1.75, ZS1 - 5.58), false)
    for i in range(3):
        turnstile(-10.5 + float(i) * 3.4, ZS1 - 13.0)
    # 悬挂站牌 + 时钟
    # 三块吊挂站牌：面板 + 四边包边 + 两根圆管吊杆 + 顶座
    for sg in [[-30.0, 3.10, 4.16], [20.0, 3.10, 4.16], [-2.0, 3.30, 3.96]]:
        var sz: float = sg[0]
        b.box("metalD", _v(-5.55, sg[1], sz - 0.10), _v(-4.45, sg[2], sz + 0.10), false)
        sign_frame(-5.00, (sg[1] + sg[2]) * 0.5, 1.10, sg[2] - sg[1], sz, 0.20)
        for xx in [-5.32, -4.68]:
            b.cyl("metalD", xx, sz - 0.04, sg[2] + 0.07, CH, 0.024, 0.024, 8, true, false)
        b.box("metalD", _v(-5.42, CH - 0.07, sz - 0.07), _v(-4.58, CH, sz + 0.07), false)
    b.label3d("岚 桥 站", _v(-4.40, 3.62, -30.0), 0.44, Color(0.93, 0.96, 1.0), PI * 0.5)
    b.label3d("岚 桥 站", _v(-5.60, 3.62, -30.0), 0.44, Color(0.93, 0.96, 1.0), -PI * 0.5)
    b.label3d("出 口 EXIT", _v(-4.40, 3.62, 20.0), 0.34, Color(0.55, 1.0, 0.70), PI * 0.5)
    b.label3d("乘 车 须 知", _v(-3.0, 1.55, ZS1 - 0.06), 0.22, Color(0.85, 0.88, 0.92), PI)
    b.label3d("站台端头  禁止进入", _v(-4.0, 1.60, ZS0 + 0.06), 0.22, Color(0.95, 0.55, 0.45), 0.0)

# ------------------------------------------------------------------ 岔区 · 检修环线接轨
func branch_area() -> void:
    # 岔区厅：z = QZ0..QZ1，向东加宽到 QX1；主线在这里分出一条侧线
    b.slab("conc", 8.0, QZ0, QX1, SZ1, TY, 1.2, true)
    b.box("tunnel", _v(6.0, QY, QZ0), _v(QX1, QY + 0.6, QZ1), true, "b")
    b.box("tunnel", _v(12.4, QY, QZ1), _v(QX1, QY + 0.6, -55.9), true, "b")
    b.box("tunnel", _v(QX1, TY, QZ0), _v(QX1 + 0.6, QY + 0.6, SZ1), true, "n")
    b.box("tunnel", _v(6.0, TY, QZ0 - 0.5), _v(QX1, QY + 0.6, QZ0), true, "f")
    b.box("tunnel", _v(12.4, TY, -57.6), _v(13.0, CH, -55.9), true, "n")
    b.box("tunnel", _v(8.03, TY, -57.65), _v(8.73, CH, -55.9), true, "n")
    b.box("tunnel", _v(8.0, TY, -56.3), _v(SX0, QY + 0.6, -55.9), true, "k")
    # 岔区南墙：只留侧线隧道洞口
    b.box("tunnel", _v(12.8, TY, -65.9), _v(SX0, QY + 0.6, -65.5), true, "k")
    b.box("tunnel", _v(SX0, 3.5, -65.9), _v(SX1, QY + 0.6, -65.5), true, "kf")
    # —— 侧线隧道：向南藏在站体东侧，够长让整列车躲进去
    b.box("tunnel", _v(13.0, TY, QZ1), _v(SX0, 4.2, SZ1), true, "p")
    b.box("tunnel", _v(SX0, 3.6, QZ1), _v(SX1, 4.2, SZ1), true, "b")
    b.box("tunnel", _v(13.0, TY, SZ1), _v(18.0, 4.2, SZ1 + 0.6), true, "k")
    b.box("dark", _v(SX0 + 0.2, TY - 0.02, QZ1 + 0.4), _v(SX1 - 0.2, TY + 0.04, SZ1 - 6.0), false)
    for i in range(9):
        var zz := -60.0 + float(i) * 18.0
        b.box("conc", _v(13.8, TY - 0.01, zz), _v(17.2, TY + 0.03, zz + 0.26), false)
        b.box("lampC", _v(SX0 + 0.02, 3.30, zz), _v(SX0 + 0.22, 3.44, zz + 1.6), false, "p")
        if i % 3 == 1:
            b.light(_v(SX0 + 1.0, 3.1, zz + 0.8), Color(0.40, 0.60, 0.80), 1.4, 10.0, false)
    # —— 侧线钢轨
    for rx in [BR_X1 - 0.72, BR_X1 + 0.72]:
        b.box("metal", _v(rx - 0.045, TY, BR_Z1), _v(rx + 0.045, TY + 0.16, SZ1 - 6.0), false)
    # —— 道岔曲线（主线 x=BR_X0 → 侧线 x=BR_X1）
    var n := 26
    for i in range(n):
        var p0 := branch_pt(lerpf(BR_Z0, BR_Z1, float(i) / float(n)))
        var p1 := branch_pt(lerpf(BR_Z0, BR_Z1, float(i + 1) / float(n)))
        var seg := p0.distance_to(p1)
        if seg < 0.01:
            continue
        var mid := (p0 + p1) * 0.5
        var dir := (p1 - p0).normalized()
        var yaw := atan2(dir.x, dir.z)
        var perp := Vector3(dir.z, 0.0, -dir.x)
        for side in [-0.72, 0.72]:
            var c: Vector3 = mid + perp * side
            b.box_rot("metal", Vector3(c.x, TY + 0.082, c.z), Vector3(0.09, 0.15, seg + 0.10), yaw, false)
    # —— 尖轨 / 转辙机 / 连杆 / 拉杆
    b.box("metal", _v(3.20, TY, -116.2), _v(3.36, TY + 0.15, -113.0), false)
    b.box("metalD", _v(7.20, TY, -114.8), _v(8.20, TY + 0.52, -113.6), true)
    b.box("dark", _v(7.26, TY + 0.40, -114.74), _v(8.14, TY + 0.50, -113.66), false)
    b.box("hazard", _v(7.22, TY + 0.52, -114.50), _v(8.18, TY + 0.58, -113.90), false)
    b.box("metalD", _v(5.60, TY + 0.10, -116.4), _v(7.25, TY + 0.24, -114.9), false)
    b.box("dark", _v(4.60, TY + 0.02, -112.4), _v(7.40, TY + 0.10, -112.2), false)
    # 滑床板 + 表示杆 + 转辙机底板 + 道岔标志灯
    for i in range(5):
        var sz2 := -116.1 + float(i) * 0.86
        b.box("metalD", _v(3.05, TY + 0.16, sz2), _v(4.35, TY + 0.20, sz2 + 0.52), false, "t")
    b.box("metal", _v(4.40, TY + 0.19, -114.55), _v(7.35, TY + 0.235, -114.35), false)
    b.box("metalD", _v(7.10, TY + 0.01, -115.20), _v(8.30, TY + 0.09, -113.30), false, "t")
    for xx2 in [8.05, 8.22]:
        b.cyl("metalD", xx2, -114.20, TY + 0.09, TY + 0.86, 0.030, 0.026, 8, true, false)
    b.box("exit", _v(8.00, TY + 0.64, -114.20), _v(8.28, TY + 0.78, -113.84), false, "p")
    b.box("red", _v(8.00, TY + 0.64, -114.56), _v(8.28, TY + 0.78, -114.20), false, "p")
    # —— 标牌 / 照明
    b.plaque("检修环线 · 侧线", _v(QX1 - 0.04, TY + 2.20, -100.0), 2.2, 0.42, "x", -1, Color(1.0, 0.82, 0.42))
    b.plaque("道岔 1", _v(8.35, TY + 0.80, -113.2), 0.8, 0.24, "x", 1, Color(0.55, 0.78, 1.0))
    b.plaque("禁 止 通 行", _v(SX1 - 0.04, TY + 1.60, -70.0), 1.1, 0.26, "x", -1, Color(0.95, 0.55, 0.45))
    b.light(_v(11.2, QY - 0.5, -118.0), Color(0.55, 0.68, 0.86), 2.0, 16.0, false)
    b.light(_v(11.2, QY - 0.5, -96.0), Color(0.55, 0.68, 0.86), 2.0, 16.0, false)
    b.light(_v(11.2, QY - 0.5, -74.0), Color(0.55, 0.68, 0.86), 2.0, 16.0, false)

func branch_pt(z: float) -> Vector3:
    var t := clampf((z - BR_Z0) / (BR_Z1 - BR_Z0), 0.0, 1.0)
    var e := t * t * (3.0 - 2.0 * t)
    return Vector3(lerpf(BR_X0, BR_X1, e), TY, z)

func switch_spot_pos() -> Vector3:
    return Vector3(7.7, TY + 0.9, -112.4)