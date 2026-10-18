extends RefCounted
## 0017 次列车：6 节编组，每节独立，可沿「主线 → 岔区 → 检修环线侧线」的路径行走

const SB := preload("res://scripts/station.gd")
const CAR_LEN := 19.4
const CARS := 6
const TY := -1.15
const SPOT_ON := 15.0
const OMNI_ON := 6.0

const CX := 4.0            # 车体几何的横向中心
const Z_START := -320.0    # 路径起点（远在隧道里）
const Z_FIN := 70.0        # 路径终点（侧线隧道里）
const LZ0 := -118.0        # 道岔起点
const LZ1 := -70.0         # 道岔终点
const LX1 := 15.5          # 侧线中心

var root: Node3D
var cars: Array = []
var lamps: Array = []
var length := 0.0
var divert := false
var side_fill_scale := 1.0

var _pts := PackedVector3Array()
var _s := PackedFloat32Array()
const STEP := 0.25

func _init(parent: Node3D) -> void:
    root = Node3D.new()
    root.name = "Train0017"
    parent.add_child(root)
    for c in range(CARS):
        var car := Node3D.new()
        car.name = "Car%d" % c
        root.add_child(car)
        var b := SB.new(car)
        _build_car(b, car, c == 0, c == CARS - 1)
        b.commit()
        cars.append(car)
    length = CAR_LEN * float(CARS)
    _build_path()
    place(0.0)

func _x(v: float) -> float:
    return v - CX

# ------------------------------------------------------------------ 路径
func set_divert(v: bool) -> void:
    if divert != v:
        divert = v
        _build_path()

func path_x(z: float) -> float:
    if not divert or z <= LZ0:
        return CX
    if z >= LZ1:
        return LX1
    var t := (z - LZ0) / (LZ1 - LZ0)
    return lerpf(CX, LX1, t * t * (3.0 - 2.0 * t))

func _build_path() -> void:
    _pts = PackedVector3Array()
    _s = PackedFloat32Array()
    var acc := 0.0
    var z := Z_START
    while z <= Z_FIN + 0.001:
        var p := Vector3(path_x(z), 0.0, z)
        if _pts.size() > 0:
            acc += _pts[_pts.size() - 1].distance_to(p)
        _pts.append(p)
        _s.append(acc)
        z += STEP

func last_front_offset() -> float:
    return float(CARS - 1) * CAR_LEN

func total_len() -> float:
    return _s[_s.size() - 1] if _s.size() > 0 else 0.0

func s_at_z(z: float) -> float:
    var i := clampi(int(round((z - Z_START) / STEP)), 0, _s.size() - 1)
    return _s[i]

func point_at(s: float) -> Vector3:
    var f := clampf(s, 0.0, total_len()) / STEP
    var i := clampi(int(floor(f)), 0, _pts.size() - 2)
    return _pts[i].lerp(_pts[i + 1], clampf(f - float(i), 0.0, 1.0))

func dir_at(s: float) -> Vector3:
    var f := clampf(s, 0.0, total_len())
    var d := point_at(f + 0.6) - point_at(f - 0.6)
    if d.length_squared() < 1e-6:
        return Vector3(0, 0, 1)
    return d.normalized()

func place(s_head: float) -> void:
    # 每节车厢按「前后转向架之间的弦」摆：车体居中于曲线，拐弯时不切角
    for c in range(cars.size()):
        var sc := clampf(s_head - float(c) * CAR_LEN - CAR_LEN * 0.5, 0.0, total_len())
        var d := point_at(clampf(sc + 6.6, 0.0, total_len())) - point_at(clampf(sc - 6.6, 0.0, total_len()))
        if d.length_squared() < 1e-6:
            d = Vector3(0, 0, 1)
        d = d.normalized()
        var n: Node3D = cars[c]
        n.rotation.y = atan2(d.x, d.z)
        n.position = point_at(sc) + d * (CAR_LEN * 0.5 - 0.15)

func reset() -> void:
    set_divert(false)
    place(0.0)

func set_side_fill_scale(scale: float) -> void:
    side_fill_scale = clampf(scale, 0.0, 1.0)
    for l in lamps:
        if l is OmniLight3D and l.has_meta("side_light") and l.visible:
            l.light_energy = 3.0 * side_fill_scale

func lights_on(v: bool) -> void:
    for l in lamps:
        if l is SpotLight3D:
            l.visible = v
            l.light_energy = SPOT_ON if v else 0.02
        elif l is OmniLight3D:
            l.visible = v
            var base: float = 3.0 if l.has_meta("side_light") else OMNI_ON
            l.light_energy = (base * (side_fill_scale if l.has_meta("side_light") else 1.0)) if v else 0.04

# ------------------------------------------------------------------ 几何
func _build_car(b, car: Node3D, is_head: bool, is_tail: bool) -> void:
    var yB := TY + 0.45
    var yT := TY + 3.30
    var z0 := 0.0
    var z1 := -CAR_LEN + 0.30
    b.box("trainA", Vector3(_x(2.56), yB, z1), Vector3(_x(5.44), yT, z0), false)
    b.box("rubber", Vector3(_x(2.50), yT - 0.02, z1), Vector3(_x(5.50), yT + 0.24, z0), false)
    b.box("dark", Vector3(_x(2.62), TY + 0.02, z1), Vector3(_x(5.38), yB + 0.04, z0), false)
    # 车顶空调 / 通风器 / 车顶筋
    for az in [z0 - 3.2, z0 - 9.2, z0 - 15.2]:
        b.box("trainA", Vector3(_x(3.15), yT + 0.24, az - 1.05), Vector3(_x(4.85), yT + 0.50, az + 1.05), false)
        b.box("dark", Vector3(_x(3.05), yT + 0.50, az - 1.15), Vector3(_x(4.95), yT + 0.54, az + 1.15), false)
    for ri in range(1, 18):
        var rz := z0 - float(ri) * 1.15
        b.box("trainA", Vector3(_x(2.70), yT + 0.24, rz - 0.025), Vector3(_x(5.30), yT + 0.27, rz + 0.025), false)
    # 开车灯时照亮车侧与站台边缘，避免整列车在黑暗里只剩一块黑板
    var side_l := OmniLight3D.new()
    side_l.position = Vector3(_x(1.20), TY + 2.2, -CAR_LEN * 0.5)
    side_l.light_color = Color(0.80, 0.87, 1.0)
    side_l.light_energy = 6.0
    side_l.omni_range = 12.0
    side_l.shadow_enabled = false
    side_l.visible = false
    side_l.set_meta("side_light", true)
    car.add_child(side_l)
    lamps.append(side_l)
    b.box("trainC", Vector3(_x(2.53), TY + 1.55, z1), Vector3(_x(5.47), TY + 1.80, z0), false)
    b.box("red", Vector3(_x(2.52), TY + 1.44, z1), Vector3(_x(5.48), TY + 1.53, z0), false)
    b.box("trainB", Vector3(_x(2.545), TY + 0.62, z1), Vector3(_x(5.455), TY + 1.48, z0), false)
    for w in range(4):
        var wz := z0 - 2.6 - float(w) * 4.3
        b.box("trainWin", Vector3(_x(2.43), TY + 0.78, wz - 1.35), Vector3(_x(5.57), TY + 1.42, wz - 0.05), false)
    for d in range(3):
        var dz := z0 - 1.2 - float(d) * 6.0
        b.box("trainB", Vector3(_x(2.50), yB + 0.02, dz - 1.35), Vector3(_x(5.50), yT + 0.02, dz - 0.05), false)
        b.box("trainWin", Vector3(_x(2.49), TY + 1.05, dz - 1.28), Vector3(_x(5.51), TY + 2.06, dz - 0.12), false)
        for lx2 in [2.49, 5.51]:
            b.box("red", Vector3(_x(lx2 - 0.015), TY + 2.12, dz - 0.10), Vector3(_x(lx2 + 0.015), TY + 2.20, dz + 0.10), false, "n")
    for bz in [z0 - 3.1, z1 + 3.1]:
        b.box("dark", Vector3(_x(2.85), TY + 0.06, bz - 1.05), Vector3(_x(5.15), TY + 0.50, bz + 1.05), false)
        for wx in [3.05, 4.95]:
            b.box("metalD", Vector3(_x(wx - 0.09), TY + 0.02, bz - 0.62), Vector3(_x(wx + 0.09), TY + 0.40, bz - 0.42), false)
            b.box("metalD", Vector3(_x(wx - 0.09), TY + 0.02, bz + 0.42), Vector3(_x(wx + 0.09), TY + 0.40, bz + 0.62), false)
        # 转向架构架 / 轴箱 / 弹簧 / 第三轨集电靴
        b.box("metalD", Vector3(_x(2.78), TY + 0.34, bz - 0.90), Vector3(_x(5.22), TY + 0.46, bz + 0.90), false)
        b.box("metalD", Vector3(_x(2.98), TY + 0.20, bz - 0.06), Vector3(_x(5.02), TY + 0.30, bz + 0.06), false)
        for sx in [2.86, 5.14]:
            b.box("rubber", Vector3(_x(sx - 0.05), TY + 0.20, bz - 0.18), Vector3(_x(sx + 0.05), TY + 0.48, bz + 0.18), false)
        b.box("metalD", Vector3(_x(5.35), TY + 0.12, bz - 0.20), Vector3(_x(5.70), TY + 0.18, bz + 0.20), false)
        b.box("rubber", Vector3(_x(5.68), TY + 0.06, bz - 0.12), Vector3(_x(5.82), TY + 0.12, bz + 0.12), false)
    if is_head:
        b.box("trainA", Vector3(_x(2.62), TY + 0.55, -0.02), Vector3(_x(5.38), yT - 0.25, 0.30), false)
        b.box("trainWin", Vector3(_x(2.60), TY + 1.35, 0.28), Vector3(_x(5.40), TY + 2.42, 0.34), false)
        b.box("head", Vector3(_x(2.70), TY + 0.66, 0.33), Vector3(_x(3.60), TY + 1.00, 0.38), false, "f")
        b.box("head", Vector3(_x(4.40), TY + 0.66, 0.33), Vector3(_x(5.30), TY + 1.00, 0.38), false, "f")
        b.box("trainC", Vector3(_x(2.56), TY + 0.30, -0.02), Vector3(_x(5.44), TY + 0.55, 0.33), false)
        var ln := Label3D.new()
        ln.text = "0017"
        ln.font_size = 96
        ln.pixel_size = 0.26 / 96.0 * 2.2
        ln.modulate = Color(0.72, 0.82, 0.95)
        ln.outline_size = 10
        ln.outline_modulate = Color(0, 0, 0, 0.7)
        ln.position = Vector3(_x(4.00), TY + 2.05, 0.30)
        car.add_child(ln)
        for hx in [3.15, 4.85]:
            var sl := SpotLight3D.new()
            sl.position = Vector3(_x(hx), TY + 0.85, 0.6)
            sl.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
            sl.light_color = Color(0.85, 0.90, 1.0)
            sl.light_energy = 14.0
            sl.spot_range = 70.0
            sl.spot_angle = 26.0
            sl.spot_angle_attenuation = 0.6
            sl.shadow_enabled = false
            sl.visible = false
            car.add_child(sl)
            lamps.append(sl)
            if hx < 4.0:
                var om := OmniLight3D.new()
                om.position = Vector3(_x(hx), TY + 0.85, 0.4)
                om.light_color = Color(0.85, 0.90, 1.0)
                om.light_energy = 6.0
                om.omni_range = 22.0
                om.shadow_enabled = false
                om.visible = false
                car.add_child(om)
                lamps.append(om)
    if is_tail:
        b.box("red", Vector3(_x(2.80), TY + 0.80, z1 - 0.06), Vector3(_x(3.20), TY + 1.10, z1), false, "k")
        b.box("red", Vector3(_x(4.80), TY + 0.80, z1 - 0.06), Vector3(_x(5.20), TY + 1.10, z1), false, "k")
