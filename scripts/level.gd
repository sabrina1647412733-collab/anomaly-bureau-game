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
    platform_edge()
    columns_and_lights()
    track()
    tunnel()
    niche()
    branch_area()
    props()
    rooms()
    signage()

# ------------------------------------------------------------------ 地坪 / 墙 / 顶
func ground() -> void:
    b.slab("floor", PX0 - 0.6, ZS0 - 0.6, PX1, ZS1 + 0.6, FY, 1.2, true)
    b.slab("rust", TX0, ZTUN, TX1, 200.0, TY, 1.2, true)

func walls() -> void:
    b.box("panel", _v(PX0 - 0.5, FY, ZS0 - 0.6), _v(PX0, CH, ZS1 + 0.6), true, "p")
    b.box("panel", _v(TX1, TY, ZS0), _v(TX1 + 0.7, CH, ZS1), true, "n")
    b.box("panel", _v(PX0 - 0.6, FY, ZS0 - 0.6), _v(TX0, CH, ZS0), true, "f")
    b.box("panel", _v(PX0 - 0.6, FY, ZS1), _v(TX0, CH, ZS1 + 0.6), true, "k")
    b.box("ceil", _v(PX0 - 0.6, CH, ZS0 - 0.6), _v(TX1 + 0.7, CH + 0.6, ZS1 + 0.6), true, "b")

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
        b.box("colTile", _v(-9.05, FY, z - 0.45), _v(-8.15, CH, z + 0.45), true)
        b.box("colAmber", _v(-9.06, 1.42, z - 0.47), _v(-8.14, 1.56, z + 0.47), false, "p")
        b.box("metalD", _v(-9.15, FY, z - 0.55), _v(-8.05, 0.10, z + 0.55), false)
        b.box("metalD", _v(-9.15, CH - 0.14, z - 0.55), _v(-8.05, CH, z + 0.55), false)
        b.box("sign", _v(-9.07, 1.42, z - 0.47), _v(-8.13, 1.52, z + 0.47), false, "p")
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
        var y2 := TY + 0.25 + float(i) * 0.34
        b.box("metalD", _v(11.3, y2, z0 + 0.35), _v(11.9, y2 + 0.05, z0 + 0.43), false)
    for xx in [11.32, 11.88]:
        b.box("metalD", _v(xx - 0.03, TY, z0 + 0.34), _v(xx + 0.03, TY + 2.3, z0 + 0.44), false)
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
        b.box("metalD", _v(PX0 + 2.2, FY, z1 - 1.0), _v(PX0 + 2.8, 1.0, z1 - 0.5), true)   # 饮水机
        b.box("lampC", _v(PX0 + 2.25, 0.55, z1 - 1.02), _v(PX0 + 2.75, 0.85, z1 - 0.95), false, "p")
    else:
        desk(x1 - 5.6, z0 + 0.30, x1 - 3.6, z0 + 2.00, 0.92)          # 调音台
        chair(x1 - 4.25, z0 + 1.30, FY, PI * 0.5)
        cabinet(PX0 + 1.05, z1 - 3.5, PX0 + 2.00, z1 - 0.5, 1.8)      # 磁带架
        for i in range(4):
            b.box("dark", _v(PX0 + 1.10, 0.25 + float(i) * 0.36, z1 - 3.45), _v(PX0 + 1.95, 0.33 + float(i) * 0.36, z1 - 0.55), false)
        b.box("glass", _v(x1 - 0.16, 1.15, dz1 + 0.7), _v(x1 - 0.07, 2.15, z1 - 0.4), false, "p")   # 观察窗
        b.box("lampC", _v(x1 - 0.20, 2.35, dz1 + 0.8), _v(x1 - 0.10, 2.44, z1 - 0.5), false, "p")

func dispatch_console(x0: float, z0: float, x1: float, z1: float) -> void:
    var h := 0.74
    var zb := z0 + 0.06
    var zf := z1 - 0.06
    # 柜体 + 踢脚
    b.box("metalD", _v(x0, FY + 0.14, z0), _v(x1, h, z1), true, "all", 0.030)
    b.box("dark", _v(x0 + 0.08, FY, z0 + 0.08), _v(x1 - 0.08, FY + 0.14, z1 - 0.08), true)
    # 斜面操作台（靠墙侧高）
    var yb := h + 0.34
    b.quad("metalD", _v(x0 + 0.05, yb, zb), _v(x0 + 0.05, yb, zf), _v(x1 - 0.06, h, zf), _v(x1 - 0.06, h, zb), Vector3(0, 1, 0))
    b.quad("dark", _v(x0 + 0.05, yb - 0.05, zb), _v(x0 + 0.05, yb, zb), _v(x1 - 0.06, h, zb), _v(x1 - 0.06, h - 0.05, zb), Vector3(0, 0, -1))
    b.quad("dark", _v(x1 - 0.06, h, zf), _v(x0 + 0.05, yb, zf), _v(x0 + 0.05, yb - 0.05, zf), _v(x1 - 0.06, h - 0.05, zf), Vector3(0, 0, 1))
    b.quad("dark", _v(x1 - 0.06, h - 0.05, zb), _v(x1 - 0.06, h, zb), _v(x1 - 0.06, h, zf), _v(x1 - 0.06, h - 0.05, zf), Vector3(1, 0, 0))
    b.add_collider(_v(x0, FY, z0), _v(x1, yb + 0.02, z1))
    # 背面立板 + 三块屏
    b.box("metalD", _v(x0 + 0.05, yb, z0 + 0.06), _v(x0 + 0.20, yb + 0.62, z1 - 0.06), true)
    var n := 3
    for i in range(n):
        var zc := zb + (zf - zb) * (float(i) + 0.5) / float(n)
        var w := (zf - zb) / float(n) * 0.72
        b.box("dark", _v(x0 + 0.19, yb + 0.16, zc - w * 0.5), _v(x0 + 0.26, yb + 0.56, zc + w * 0.5), false)
        b.box("lampC", _v(x0 + 0.26, yb + 0.20, zc - w * 0.45), _v(x0 + 0.285, yb + 0.52, zc + w * 0.45), false, "p")
    # 斜面上一排按钮 + 指示灯
    for i in range(8):
        var zc2 := zb + (zf - zb) * (float(i) + 0.5) / 8.0
        var mat := "lampC" if i % 3 == 1 else "dark"
        if i == 5:
            mat = "red"
        b.box(mat, _v(x0 + 1.30, h + 0.10, zc2 - 0.07), _v(x0 + 1.38, h + 0.14, zc2 + 0.07), false, "p")
    for i in range(6):
        var zc3 := zb + (zf - zb) * (float(i) + 0.5) / 6.0
        var col := Color(1.0, 0.5, 0.2) if i % 2 == 0 else Color(0.35, 0.62, 0.83)
        b.box("lamp", _v(x0 + 0.28, yb + 0.60, zc3 - 0.05), _v(x0 + 0.34, yb + 0.66, zc3 + 0.05), false, "p")
    # 键盘 + 鼠标 + 电话
    b.box("dark", _v(x0 + 1.05, h + 0.16, zb + 0.35), _v(x0 + 1.95, h + 0.21, zb + 1.35), false)
    b.box("dark", _v(x0 + 1.75, h + 0.14, zb + 1.55), _v(x0 + 1.92, h + 0.20, zb + 1.72), false)
    b.box("dark", _v(x0 + 0.55, h + 0.02, zf - 0.75), _v(x0 + 1.15, h + 0.10, zf - 0.15), false)
    b.box("dark", _v(x0 + 0.50, h + 0.10, zf - 0.78), _v(x0 + 1.20, h + 0.20, zf - 0.66), false)
    # 抽屉 + 拉手
    b.box("metalD", _v(x1 - 0.05, 0.30, zb + 0.25), _v(x1 - 0.02, h - 0.06, zf - 0.25), false)
    b.box("lampC", _v(x1 - 0.02, 0.48, zb + 0.55), _v(x1 + 0.02, 0.54, zf - 0.55), false, "p")
    # 桌下走线槽
    b.box("dark", _v(x0 + 0.30, 0.24, zb), _v(x0 + 0.60, 0.38, zf), false)
    # 顶灯 + 铭牌
    b.box("lamp", _v(x0 + 0.30, 3.30, zb + 0.5), _v(x0 + 0.95, 3.40, zf - 0.5), false, "b")
    b.light(_v(x0 + 0.8, 3.1, (zb + zf) * 0.5), Color(0.85, 0.90, 1.0), 3.4, 9.0, false)
    b.plaque("夜班调度席", _v(x1 + 0.01, yb + 0.26, (zb + zf) * 0.5), 0.72, 0.19, "x", 1, Color(0.45, 0.72, 0.95))

func relay_cabinet(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    b.box("metalD", _v(x0, FY + 0.10, z0), _v(x1, h, z1), true, "all", 0.035)
    b.box("dark", _v(x0 + 0.04, FY, z0 + 0.04), _v(x1 - 0.04, FY + 0.10, z1 - 0.04), true)
    # 柜门
    b.box("metalD", _v(x1, FY + 0.06, z0 + 0.06), _v(x1 + 0.035, h - 0.06, z1 - 0.06), false, "all", 0.014)
    # 玻璃观察窗
    b.box("glass", _v(x1 + 0.01, h * 0.42, z0 + 0.30), _v(x1 + 0.06, h * 0.84, z1 - 0.30), false, "p")
    b.box("dark", _v(x1 + 0.01, h * 0.42, z0 + 0.30), _v(x1 + 0.07, h * 0.46, z1 - 0.30), false)
    b.box("dark", _v(x1 + 0.01, h * 0.80, z0 + 0.30), _v(x1 + 0.07, h * 0.84, z1 - 0.30), false)
    # 五排继电器 + 指示灯（第五排是红的）
    var n := 5
    for i in range(n):
        var zz := z0 + 0.62 + (z1 - z0 - 1.24) * float(i) / float(n - 1)
        b.box("dark", _v(x1 - 0.34, h * 0.50, zz - 0.16), _v(x1 - 0.02, h * 0.76, zz + 0.16), false)
        for k in range(3):
            b.box("metalD", _v(x1 - 0.30 + float(k) * 0.09, h * 0.54, zz - 0.12), _v(x1 - 0.27 + float(k) * 0.09, h * 0.72, zz + 0.12), false)
        b.box("red" if i == 4 else "lampC", _v(x1 - 0.06, h * 0.62, zz - 0.13), _v(x1 - 0.02, h * 0.68, zz + 0.13), false, "p")
        b.box("dark", _v(x1 - 0.35, h * 0.47, zz), _v(x1 - 0.02, h * 0.50, zz + 0.02), false)
    # 把手 / 铰链 / 铭牌 / 顶部指示灯
    b.box("lampC", _v(x1 + 0.035, h * 0.52, z1 - 0.34), _v(x1 + 0.08, h * 0.60, z1 - 0.28), false, "p")
    for hz in [z0 + 0.10, z1 - 0.10]:
        b.box("metalD", _v(x1 - 0.01, h * 0.25, hz - 0.05), _v(x1 + 0.05, h * 0.30, hz + 0.05), false)
        b.box("metalD", _v(x1 - 0.01, h * 0.70, hz - 0.05), _v(x1 + 0.05, h * 0.75, hz + 0.05), false)
    b.box("lamp", _v(x1 + 0.02, h * 0.90, z0 + 0.55), _v(x1 + 0.07, h * 0.96, z0 + 0.85), false, "p")
    b.box("red", _v(x1 + 0.02, h * 0.90, z1 - 0.85), _v(x1 + 0.07, h * 0.96, z1 - 0.55), false, "p")
    b.plaque("五号继电器", _v(x1 + 0.035, h - 0.16, (z0 + z1) * 0.5), 0.70, 0.18, "x", 1, Color(0.90, 0.45, 0.40))
    # 底部电缆槽
    b.box("dark", _v(x1 + 0.02, FY + 0.02, z0 + 0.10), _v(x1 + 0.10, FY + 0.16, z1 - 0.10), false)

func bench(x0: float, z0: float, x1: float, z1: float, base := FY) -> void:
    for i in range(3):
        var xx := x0 + 0.05 + float(i) * 0.30
        b.box("wood", _v(xx, base + 0.44, z0), _v(xx + 0.24, base + 0.49, z1), false)
    for i in range(2):
        var y := base + 0.62 + float(i) * 0.20
        var xx2 := x0 + 0.02 - float(i) * 0.045
        b.box("woodD", _v(xx2, y, z0), _v(xx2 + 0.15, y + 0.14, z1), false)
    for zz in [z0 + 0.05, z1 - 0.15]:
        b.box("dark", _v(x0 + 0.02, base, zz), _v(x1 - 0.02, base + 0.44, zz + 0.10), false)
        b.box("dark", _v(x0 + 0.02, base + 0.44, zz), _v(x0 + 0.09, base + 0.95, zz + 0.10), false)
    var zc := (z0 + z1) * 0.5
    b.box("dark", _v(x0 + 0.02, base, zc - 0.05), _v(x1 - 0.02, base + 0.44, zc + 0.05), false)
    b.add_collider(_v(x0, base, z0), _v(x1, base + 0.50, z1))
    var zc2 := (z0 + z1) * 0.5
    b.seats.append({"pos": Vector3(x0 + 0.62, base, z0 + (z1 - z0) * 0.30), "yaw": -PI * 0.5})
    b.seats.append({"pos": Vector3(x0 + 0.62, base, z0 + (z1 - z0) * 0.70), "yaw": -PI * 0.5})

func vending(x0: float, z0: float, x1: float, z1: float, base := FY) -> void:
    var h := base + 1.95
    b.box("metalD", _v(x0, base, z0), _v(x1, h, z1), true, "all", 0.050)
    b.box("dark", _v(x0 + 0.03, base + 0.12, z0 + 0.03), _v(x1 - 0.03, h - 0.12, z1 - 0.03), false)
    # 展示橱窗 + 里面的饮料
    b.box("glass", _v(x1 - 0.02, base + 0.55, z0 + 0.14), _v(x1 + 0.02, h - 0.32, z1 - 0.14), false, "p")
    for i in range(3):
        b.box(["red", "lamp", "lampC"][i], _v(x1 - 0.10, base + 0.72 + float(i) * 0.34, z0 + 0.20), _v(x1 - 0.06, base + 1.02 + float(i) * 0.34, z1 - 0.20), false, "p")
    # 顶部灯带 / 取货口 / 按键面板
    b.box("lamp", _v(x1 - 0.09, h - 0.28, z0 + 0.16), _v(x1 - 0.05, h - 0.16, z1 - 0.16), false, "p")
    b.box("dark", _v(x1 - 0.10, base + 0.20, z0 + 0.30), _v(x1 - 0.02, base + 0.38, z1 - 0.30), true)
    b.box("lampC", _v(x1 - 0.08, base + 1.10, z0 + 0.24), _v(x1 - 0.04, base + 1.42, z1 - 0.76), false, "p")
    for i in range(6):
        b.box("dark", _v(x1 - 0.07, base + 1.16 + float(i % 3) * 0.12, z1 - 0.72 + float(i / 3) * 0.16), _v(x1 - 0.03, base + 1.24 + float(i % 3) * 0.12, z1 - 0.66 + float(i / 3) * 0.16), false)
    b.box("metalD", _v(x1 - 0.10, base + 0.02, z0 + 0.10), _v(x1 - 0.02, base + 0.16, z1 - 0.10), false)
    b.light(_v(x1 + 0.55, base + 1.35, (z0 + z1) * 0.5), Color(0.45, 0.70, 0.95), 2.2, 8.0, false)
    b.plaque("自动售货", _v(x1 - 0.005, base + 1.70, (z0 + z1) * 0.5), 0.62, 0.18, "x", 1, Color(0.55, 0.78, 1.0))

func bin(cx: float, cz: float, base := FY) -> void:
    b.box("metalD", _v(cx - 0.22, base, cz - 0.22), _v(cx + 0.22, base + 0.76, cz + 0.22), true, "all", 0.050)
    b.box("dark", _v(cx - 0.25, base + 0.76, cz - 0.25), _v(cx + 0.25, base + 0.86, cz + 0.25), false)
    b.box("dark", _v(cx - 0.11, base + 0.86, cz - 0.17), _v(cx + 0.11, base + 0.90, cz + 0.17), false)
    b.box("metalD", _v(cx - 0.205, base + 0.18, cz - 0.205), _v(cx + 0.205, base + 0.23, cz + 0.205), false)
    b.box("metalD", _v(cx - 0.205, base + 0.52, cz - 0.205), _v(cx + 0.205, base + 0.57, cz + 0.205), false)

func turnstile(cx: float, cz: float, base := FY) -> void:
    var h := base + 1.02
    b.box("metalD", _v(cx - 0.20, base, cz - 0.78), _v(cx + 0.20, h, cz + 0.78), true, "all", 0.035)
    b.box("dark", _v(cx - 0.17, base + 0.14, cz - 0.75), _v(cx + 0.17, h - 0.10, cz + 0.75), false)
    b.box("metalD", _v(cx - 0.23, h, cz - 0.62), _v(cx + 0.23, h + 0.06, cz + 0.62), true, "all", 0.025)
    b.box("dark", _v(cx - 0.17, h + 0.06, cz - 0.34), _v(cx + 0.17, h + 0.09, cz + 0.06), false)
    b.box("lampC", _v(cx - 0.05, h + 0.09, cz - 0.02), _v(cx + 0.05, h + 0.12, cz + 0.08), false, "p")
    b.box("red", _v(cx - 0.05, h + 0.09, cz + 0.20), _v(cx + 0.05, h + 0.12, cz + 0.30), false, "p")
    b.box("metalD", _v(cx - 0.07, base + 0.82, cz - 0.07), _v(cx + 0.07, base + 1.00, cz + 0.07), false)
    for i in range(3):
        var a := TAU * float(i) / 3.0 + 0.35
        b.box_rot("metalD", Vector3(cx + cos(a) * 0.32, base + 0.90, cz + sin(a) * 0.32),
                  Vector3(0.06, 0.06, 0.64), PI * 0.5 - a, false)

func cabinet(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    b.box("metalD", _v(x0, FY, z0), _v(x1, h, z1), true, "all", 0.030)
    b.box("dark", _v(x0, h * 0.42, z0 - 0.01), _v(x1, h * 0.46, z1 + 0.01), false)
    var n := int(maxf(1.0, (z1 - z0) / 0.55))
    for i in range(n):
        var zz := z0 + (z1 - z0) * (float(i) + 0.5) / float(n)
        b.box("dark", _v(x1 - 0.02, 0.08, zz - 0.02), _v(x1 + 0.01, h - 0.08, zz + 0.02), false)
        b.box("lampC", _v(x1 + 0.01, h * 0.55, zz - 0.05), _v(x1 + 0.04, h * 0.55 + 0.04, zz + 0.05), false, "p")

func locker(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
    b.box("metalD", _v(x0, FY, z0), _v(x1, h, z1), true, "all", 0.030)
    for i in range(3):
        var zz := z0 + (z1 - z0) * (float(i) + 0.5) / 3.0
        b.box("dark", _v(x1 - 0.02, 0.06, zz - 0.02), _v(x1 + 0.01, h - 0.06, zz + 0.02), false)
        b.box("lampC", _v(x1 + 0.01, h * 0.5, zz - 0.06), _v(x1 + 0.04, h * 0.5 + 0.05, zz + 0.06), false, "p")
    b.box("dark", _v(x0, h - 0.06, z0), _v(x1, h, z1), false)

func desk(x0: float, z0: float, x1: float, z1: float, h := 0.76, base := FY) -> void:
    b.box("metalD", _v(x0, h - 0.05, z0), _v(x1, h, z1), false)                   # 台面
    b.add_collider(_v(x0, base, z0), _v(x1, h, z1))                               # 整张桌子算实体
    b.box("dark", _v(x0 + 0.04, base + 0.08, z0 + 0.04), _v(x1 - 0.04, h - 0.05, z0 + 0.10), false)   # 侧板
    b.box("dark", _v(x0 + 0.04, base + 0.08, z1 - 0.10), _v(x1 - 0.04, h - 0.05, z1 - 0.04), false)
    b.box("metalD", _v(x1 - 0.55, 0.42, z0 + 0.06), _v(x1 - 0.06, h - 0.05, z1 - 0.06), true)       # 抽屉箱
    b.box("dark", _v(x1 - 0.53, 0.52, z0 + 0.05), _v(x1 - 0.08, 0.58, z1 - 0.05), false)
    b.box("lampC", _v(x1 - 0.30, 0.585, z0 + 0.10), _v(x1 - 0.26, 0.615, z1 - 0.10), false, "p")    # 拉手
    b.box("dark", _v(x0 + 0.10, 0.20, z0 + 0.12), _v(x1 - 0.60, 0.24, z1 - 0.12), false)            # 横撑

func chair(cx: float, cz: float, base := FY, yaw := 0.0) -> void:
    var c := Vector3(cx, base, cz)
    var ca := cos(yaw)
    var sa := sin(yaw)
    var R := func(l: Vector3) -> Vector3: return Vector3(c.x + l.x * ca + l.z * sa, c.y + l.y, c.z - l.x * sa + l.z * ca)
    b.box_rot("dark", R.call(Vector3(0, 0.43, 0)), Vector3(0.48, 0.06, 0.48), yaw, false)          # 座面
    b.box_rot("dark", R.call(Vector3(0, 0.67, 0.20)), Vector3(0.48, 0.42, 0.08), yaw, false)        # 靠背
    for dx in [-0.20, 0.20]:
        for dz in [-0.20, 0.20]:
            b.box_rot("dark", R.call(Vector3(dx, 0.20, dz)), Vector3(0.05, 0.40, 0.05), yaw, false)
    b.add_collider(_v(cx - 0.30, base, cz - 0.30), _v(cx + 0.30, base + 0.50, cz + 0.30))
    b.seats.append({"pos": Vector3(cx - sin(yaw) * 0.02, base, cz - cos(yaw) * 0.02), "yaw": yaw})
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
    b.box("metalD", _v(-5.55, 3.10, -30.10), _v(-4.45, 4.16, -29.90), false)
    b.box("metalD", _v(-5.55, 3.10, 19.90), _v(-4.45, 4.16, 20.10), false)
    b.box("metalD", _v(-5.55, 3.30, -2.10), _v(-4.45, 3.96, -1.90), false)
    b.box("metalD", _v(-5.35, CH - 0.9, -30.04), _v(-5.15, CH, -29.96), false)
    b.box("metalD", _v(-4.85, CH - 0.9, -30.04), _v(-4.65, CH, -29.96), false)
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