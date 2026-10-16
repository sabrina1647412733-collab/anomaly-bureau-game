extends RefCounted
## 岚桥站：程序化生成几何 + 真实物理碰撞
## 用法：var b = StationBuilder.new(self)  ->  b.build()  ->  b.commit()

const PX0 := -18.0      # 站台靠墙侧
const PX1 := 0.0        # 站台沿
const TX0 := 0.0        # 轨行区近侧
const TX1 := 8.0        # 轨行区远侧墙
const ZS0 := -56.0      # 北端
const ZS1 := 56.0       # 南端
const FY := 0.0         # 站台面
const TY := -1.15       # 轨面
const CH := 5.0         # 吊顶
const BORE_R := 4.0     # 隧道拱半径
const BORE_SP := 1.0    # 起拱高
const ZTUN := -190.0    # 隧道远端

const MATS := {
    # —— 真实材料反射率（混凝土/瓷砖 0.35~0.6，不是 0.05）——
    "floor":  {"color":Color(0.46,0.46,0.48), "rough":0.36, "metal":0.02},                                   # 浅灰花岗岩地砖
    "conc":   {"color":Color(0.40,0.41,0.42), "rough":0.88, "metal":0},                                   # 混凝土
    "panel":  {"color":Color(0.53,0.54,0.56), "rough":0.55, "metal":0.06},                                   # 站台挂板（浅灰白）
    "ceil":   {"color":Color(0.36,0.37,0.39), "rough":0.72, "metal":0},                                   # 吊顶
    "tunnel": {"color":Color(0.19,0.19,0.20), "rough":0.92, "metal":0},                                   # 隧道（烟熏）
    "edge":   {"color":Color(0.74,0.58,0.16), "rough":0.62, "metal":0},                                   # 盲道黄
    "white":  {"color":Color(0.64,0.65,0.67), "rough":0.55, "metal":0},
    "metal":  {"color":Color(0.63,0.65,0.68), "rough":0.28, "metal":0.3},                                   # 不锈钢
    "metalD": {"color":Color(0.35,0.36,0.38), "rough":0.42, "metal":0.25},
    "hazard": {"color":Color(0.86,0.66,0.12), "rough":0.55, "metal":0.05},
    "rubber": {"color":Color(0.06,0.06,0.07), "rough":0.95, "metal":0},
    "wood":   {"color":Color(0.35,0.22,0.11), "rough":0.55, "metal":0},
    "colTile":{"color":Color(0.13,0.31,0.39), "rough":0.28, "metal":0.05},                                   # 柱子：主题青蓝瓷砖
    "colAmber":{"color":Color(0.55,0.40,0.14), "emission":Color(0.95,0.68,0.28), "energy":0.65, "rough":0.4, "metal":0},
    "woodD":  {"color":Color(0.24,0.15,0.08), "rough":0.6, "metal":0},
    "glass":  {"color":Color(0.14,0.20,0.24), "rough":0.08, "metal":0.1},
    "dark":   {"color":Color(0.12,0.13,0.15), "rough":0.75, "metal":0},
    "rust":   {"color":Color(0.31,0.29,0.27), "rough":0.9, "metal":0},
    "lamp":   {"color":Color(0.85,0.72,0.42), "emission":Color(0.95,0.72,0.34), "energy":1.35, "rough":0.45, "metal":0},
    "lampC":  {"color":Color(0.55,0.70,0.86), "emission":Color(0.45,0.70,0.95), "energy":0.905, "rough":0.35, "metal":0},
    "sign":   {"color":Color(0.16,0.34,0.52), "emission":Color(0.45,0.72,0.98), "energy":0.95, "rough":0.4, "metal":0},
    "glow":   {"color":Color(0.34,0.34,0.36), "emission":Color(1.0,1.0,1.0), "energy":1.05, "rough":0.5, "metal":0},
    "exit":   {"color":Color(0.10,0.42,0.24), "emission":Color(0.32,0.88,0.52), "energy":0.90, "rough":0.45, "metal":0},
    "clock":  {"color":Color(0.10,0.06,0.02), "emission":Color(0.88,0.64,0.29), "energy":1.20, "rough":0.4, "metal":0},
    "trainA": {"color":Color(0.67,0.69,0.72), "rough":0.26, "metal":0.35},                                   # 不锈钢车体
    "trainB": {"color":Color(0.07,0.09,0.12), "rough":0.6, "metal":0},
    "trainC": {"color":Color(0.15,0.35,0.61), "rough":0.35, "metal":0.1},                                   # 蓝色腰线
    "trainW": {"color":Color(0.10,0.15,0.20), "rough":0.7, "metal":0},
    "head":   {"color":Color(0.90,0.95,1.00), "emission":Color(0.72,0.82,0.95), "energy":2.40, "rough":0.3, "metal":0},
    "red":    {"color":Color(0.60,0.13,0.11), "emission":Color(0.85,0.16,0.12), "energy":0.5, "rough":0.5, "metal":0},
}

var mesh_inst: MeshInstance3D
var body: StaticBody3D
var _mesh := ArrayMesh.new()
var _st := {}
var _keys: Array = []
var _mats := {}
var tri_count := 0
var col_count := 0
var seats: Array = []
var lights: Array = []
var font: Font = null

static var ALL: Array = []

func _init(parent: Node3D) -> void:
    ALL.append(self)
    mesh_inst = MeshInstance3D.new()
    mesh_inst.name = "StationMesh"
    parent.add_child(mesh_inst)
    body = StaticBody3D.new()
    body.name = "StationBody"
    parent.add_child(body)

# ---------------------------------------------------------------- 基础工具
func _tool(key: String) -> SurfaceTool:
    if not _st.has(key):
        var s := SurfaceTool.new()
        s.begin(Mesh.PRIMITIVE_TRIANGLES)
        _st[key] = s
        _keys.append(key)
    return _st[key]

func _mat(key: String) -> Material:
    if _mats.has(key):
        return _mats[key]
    var parts := key.split("|")
    var name: String = parts[0]
    var tint := Color.WHITE
    if parts.size() > 1:
        tint = Color(parts[1])
    var m := ShaderMaterial.new()
    m.shader = load("res://shaders/surface.gdshader")
    var d: Dictionary = MATS[name]
    var base: Color = d.get("color", Color(0.5, 0.5, 0.5))
    m.set_shader_parameter("albedo", Vector3(base.r, base.g, base.b))
    m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
    m.set_shader_parameter("reflectance", d.get("reflectance", 1.0))
    m.set_shader_parameter("roughness", float(d.get("rough", 0.75)))
    m.set_shader_parameter("metallic", float(d.get("metal", 0.0)))
    m.set_shader_parameter("specular", float(d.get("spec", 0.5)))
    if d.has("emission"):
        var e: Color = d["emission"]
        m.set_shader_parameter("emission_color", Vector3(e.r, e.g, e.b))
        m.set_shader_parameter("emission_energy", float(d["energy"]))
    _mats[key] = m
    return m

func _vk(key: String, p: Vector3, n: Vector3, uv: Vector2) -> void:
    var s := _tool(key)
    s.set_normal(n)
    s.set_uv(uv)
    s.add_vertex(p)

func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, want_n := Vector3.ZERO) -> void:
    var n := (b - a).cross(c - a)
    if n.length_squared() < 1e-9:
        return
    n = n.normalized()
    if want_n != Vector3.ZERO and n.dot(want_n) < 0.0:
        var t := b; b = d; d = t
        n = -n
    # Godot 的前向面是「顺时针」，所以按 a-c-b / a-d-c 输出
    _vk(key, a, n, Vector2(a.x + a.z, a.y));  _vk(key, c, n, Vector2(c.x + c.z, c.y))
    _vk(key, b, n, Vector2(b.x + b.z, b.y))
    _vk(key, a, n, Vector2(a.x + a.z, a.y));  _vk(key, d, n, Vector2(d.x + d.z, d.y))
    _vk(key, c, n, Vector2(c.x + c.z, c.y))
    tri_count += 2

func slope_collider(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    var len := Vector2(z1 - z0, y1 - y0).length()
    bs.size = Vector3(x1 - x0, 0.35, len)
    cs.shape = bs
    cs.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
    cs.rotation.x = atan2(y1 - y0, z1 - z0)
    body.add_child(cs)
    col_count += 1

func add_collider(mn: Vector3, mx: Vector3) -> void:
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = (mx - mn).abs()
    cs.shape = bs
    cs.position = (mn + mx) * 0.5
    body.add_child(cs)
    col_count += 1

func tri(key: String, a: Vector3, b: Vector3, c: Vector3, want_n := Vector3.ZERO) -> void:
    var n := (b - a).cross(c - a)
    if n.length_squared() < 1e-9:
        return
    n = n.normalized()
    if want_n != Vector3.ZERO and n.dot(want_n) < 0.0:
        var t := b
        b = c
        c = t
        n = -n
    _vk(key, a, n, Vector2(a.x + a.z, a.y))
    _vk(key, c, n, Vector2(c.x + c.z, c.y))
    _vk(key, b, n, Vector2(b.x + b.z, b.y))
    tri_count += 1

func _vec3_axis(a: int, va: float, b: int, vb: float, c: int, vc: float) -> Vector3:
    var o := [0.0, 0.0, 0.0]
    o[a] = va
    o[b] = vb
    o[c] = vc
    return Vector3(o[0], o[1], o[2])

## 倒角盒（圆角边）：6 个内缩面 + 12 条棱斜面 + 8 个角三角面
func box_bev(key: String, mn: Vector3, mx: Vector3, r: float, solid := false) -> void:
    var x0 := minf(mn.x, mx.x)
    var x1 := maxf(mn.x, mx.x)
    var y0 := minf(mn.y, mx.y)
    var y1 := maxf(mn.y, mx.y)
    var z0 := minf(mn.z, mx.z)
    var z1 := maxf(mn.z, mx.z)
    var rr := minf(r, minf(minf(x1 - x0, y1 - y0), z1 - z0) * 0.42)
    if rr <= 0.004:
        box(key, mn, mx, solid)
        return
    var LO := [x0, y0, z0]
    var HI := [x1, y1, z1]
    var LOD := [x0 + rr, y0 + rr, z0 + rr]
    var HID := [x1 - rr, y1 - rr, z1 - rr]
    # 6 个内缩面
    quad(key, Vector3(x0, LOD[1], LOD[2]), Vector3(x0, LOD[1], HID[2]), Vector3(x0, HID[1], HID[2]), Vector3(x0, HID[1], LOD[2]), Vector3(-1, 0, 0))
    quad(key, Vector3(x1, LOD[1], HID[2]), Vector3(x1, LOD[1], LOD[2]), Vector3(x1, HID[1], LOD[2]), Vector3(x1, HID[1], HID[2]), Vector3(1, 0, 0))
    quad(key, Vector3(LOD[0], y0, LOD[2]), Vector3(HID[0], y0, LOD[2]), Vector3(HID[0], y0, HID[2]), Vector3(LOD[0], y0, HID[2]), Vector3(0, -1, 0))
    quad(key, Vector3(LOD[0], y1, HID[2]), Vector3(HID[0], y1, HID[2]), Vector3(HID[0], y1, LOD[2]), Vector3(LOD[0], y1, LOD[2]), Vector3(0, 1, 0))
    quad(key, Vector3(LOD[0], LOD[1], z1), Vector3(HID[0], LOD[1], z1), Vector3(HID[0], HID[1], z1), Vector3(LOD[0], HID[1], z1), Vector3(0, 0, 1))
    quad(key, Vector3(HID[0], LOD[1], z0), Vector3(LOD[0], LOD[1], z0), Vector3(LOD[0], HID[1], z0), Vector3(HID[0], HID[1], z0), Vector3(0, 0, -1))
    # 12 条棱的斜面
    var ax := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
    for ai in range(3):
        var bi := (ai + 1) % 3
        var ci := (ai + 2) % 3
        for sb in [1, -1]:
            for sc in [1, -1]:
                var pb: float = HI[bi] if sb > 0 else LO[bi]
                var pc: float = HI[ci] if sc > 0 else LO[ci]
                var pbi: float = HID[bi] if sb > 0 else LOD[bi]
                var pci: float = HID[ci] if sc > 0 else LOD[ci]
                var v1 := _vec3_axis(ai, LOD[ai], bi, pb, ci, pci)
                var v2 := _vec3_axis(ai, HID[ai], bi, pb, ci, pci)
                var v3 := _vec3_axis(ai, HID[ai], bi, pbi, ci, pc)
                var v4 := _vec3_axis(ai, LOD[ai], bi, pbi, ci, pc)
                quad(key, v1, v2, v3, v4, (ax[bi] * float(sb) + ax[ci] * float(sc)).normalized())
    # 8 个角
    for sx in [1, -1]:
        for sy in [1, -1]:
            for sz in [1, -1]:
                var hx: float = HI[0] if sx > 0 else LO[0]
                var hy: float = HI[1] if sy > 0 else LO[1]
                var hz: float = HI[2] if sz > 0 else LO[2]
                var ix: float = HID[0] if sx > 0 else LOD[0]
                var iy: float = HID[1] if sy > 0 else LOD[1]
                var iz: float = HID[2] if sz > 0 else LOD[2]
                tri(key, Vector3(ix, hy, hz), Vector3(hx, iy, hz), Vector3(hx, hy, iz), Vector3(sx, sy, sz))
    if solid:
        add_collider(Vector3(x0, y0, z0), Vector3(x1, y1, z1))

func box(key: String, mn: Vector3, mx: Vector3, solid := false, faces := "all", bev := 0.0) -> void:
    if bev > 0.004 and faces == "all":
        box_bev(key, mn, mx, bev, solid)
        return
    var x0 := minf(mn.x, mx.x); var x1 := maxf(mn.x, mx.x)
    var y0 := minf(mn.y, mx.y); var y1 := maxf(mn.y, mx.y)
    var z0 := minf(mn.z, mx.z); var z1 := maxf(mn.z, mx.z)
    if faces == "all" or faces.find("n") >= 0:
        quad(key, Vector3(x0,y0,z0), Vector3(x0,y0,z1), Vector3(x0,y1,z1), Vector3(x0,y1,z0), Vector3(-1,0,0))
    if faces == "all" or faces.find("p") >= 0:
        quad(key, Vector3(x1,y0,z1), Vector3(x1,y0,z0), Vector3(x1,y1,z0), Vector3(x1,y1,z1), Vector3(1,0,0))
    if faces == "all" or faces.find("b") >= 0:
        quad(key, Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x1,y0,z1), Vector3(x0,y0,z1), Vector3(0,-1,0))
    if faces == "all" or faces.find("t") >= 0:
        quad(key, Vector3(x0,y1,z1), Vector3(x1,y1,z1), Vector3(x1,y1,z0), Vector3(x0,y1,z0), Vector3(0,1,0))
    if faces == "all" or faces.find("f") >= 0:
        quad(key, Vector3(x0,y0,z1), Vector3(x1,y0,z1), Vector3(x1,y1,z1), Vector3(x0,y1,z1), Vector3(0,0,1))
    if faces == "all" or faces.find("k") >= 0:
        quad(key, Vector3(x1,y0,z0), Vector3(x0,y0,z0), Vector3(x0,y1,z0), Vector3(x1,y1,z0), Vector3(0,0,-1))
    if solid:
        add_collider(Vector3(x0,y0,z0), Vector3(x1,y1,z1))

func box_rot(key: String, c: Vector3, size: Vector3, yaw: float, solid := false) -> void:
    var ca := cos(yaw)
    var sa := sin(yaw)
    var v := {}
    for sx in [0.0, 1.0]:
        for sy in [0.0, 1.0]:
            for sz in [0.0, 1.0]:
                var lx: float = (float(sx) - 0.5) * size.x
                var ly: float = (float(sy) - 0.5) * size.y
                var lz: float = (float(sz) - 0.5) * size.z
                v["%d%d%d" % [int(sx), int(sy), int(sz)]] = Vector3(c.x + lx * ca + lz * sa, c.y + ly, c.z - lx * sa + lz * ca)
    var P := func(a: int, b: int, cc: int) -> Vector3: return v["%d%d%d" % [a, b, cc]]
    quad(key, P.call(1,0,1), P.call(1,0,0), P.call(1,1,0), P.call(1,1,1), Vector3(ca, 0, -sa))
    quad(key, P.call(0,0,0), P.call(0,0,1), P.call(0,1,1), P.call(0,1,0), Vector3(-ca, 0, sa))
    quad(key, P.call(0,1,1), P.call(1,1,1), P.call(1,1,0), P.call(0,1,0), Vector3(0, 1, 0))
    quad(key, P.call(0,0,0), P.call(1,0,0), P.call(1,0,1), P.call(0,0,1), Vector3(0, -1, 0))
    quad(key, P.call(0,0,1), P.call(1,0,1), P.call(1,1,1), P.call(0,1,1), Vector3(sa, 0, ca))
    quad(key, P.call(1,0,0), P.call(0,0,0), P.call(0,1,0), P.call(1,1,0), Vector3(-sa, 0, -ca))
    if solid:
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        cs.position = c
        cs.rotation.y = yaw
        body.add_child(cs)
        col_count += 1

func slab(key: String, x0: float, z0: float, x1: float, z1: float, y_top: float, thick := 0.6, solid := true) -> void:
    box(key, Vector3(x0, y_top - thick, z0), Vector3(x1, y_top, z1), solid, "t")

func light(pos: Vector3, color: Color, energy: float, rng: float, shadows := false) -> OmniLight3D:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = color
    l.light_energy = energy
    l.omni_range = rng
    l.shadow_enabled = shadows
    l.light_specular = 0.6
    body.add_child(l)
    lights.append(l)
    return l

func tube(key: String, x0: float, y: float, z0: float, x1: float, z1: float, h := 0.10) -> void:
    box(key, Vector3(x0, y - h, z0), Vector3(x1, y, z1), false, "bt")

func extrude(key: String, profile: PackedVector2Array, z0: float, z1: float) -> void:
    var cx := 0.0; var cy := 0.0
    for p in profile:
        cx += p.x; cy += p.y
    cx /= float(profile.size()); cy /= float(profile.size())
    for i in range(profile.size() - 1):
        var a := profile[i]; var b := profile[i + 1]
        var mid := (a + b) * 0.5
        var nn := Vector2(mid.x - cx, mid.y - cy).normalized()
        quad(key, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1),
             Vector3(nn.x, nn.y, 0.0))

func label3d(text: String, pos: Vector3, size := 0.5, color := Color(0.92,0.95,1.0), rot_y := 0.0) -> Label3D:
    var l := Label3D.new()
    if font != null:
        l.font = font
    l.text = text
    l.font_size = 96
    l.pixel_size = size / 96.0 * 2.2
    l.modulate = color
    l.outline_size = 12
    l.outline_modulate = Color(0, 0, 0, 0.8)
    l.position = pos
    l.rotation.y = rot_y
    l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    l.no_depth_test = false
    l.double_sided = true
    body.add_child(l)
    return l

func plaque(text: String, c: Vector3, w: float, h: float, axis: String, sgn: int,
            color := Color(0.80, 0.88, 0.98), mat := "metalD") -> void:
    var t := 0.03
    var ln := 0.018
    if axis == "x":
        if sgn > 0:
            box(mat, Vector3(c.x, c.y - h * 0.5, c.z - w * 0.5), Vector3(c.x + t, c.y + h * 0.5, c.z + w * 0.5), false)
            label3d(text, Vector3(c.x + t + ln, c.y, c.z), h * 0.58, color, PI * 0.5)
        else:
            box(mat, Vector3(c.x - t, c.y - h * 0.5, c.z - w * 0.5), Vector3(c.x, c.y + h * 0.5, c.z + w * 0.5), false)
            label3d(text, Vector3(c.x - t - ln, c.y, c.z), h * 0.58, color, -PI * 0.5)
    else:
        if sgn > 0:
            box(mat, Vector3(c.x - w * 0.5, c.y - h * 0.5, c.z), Vector3(c.x + w * 0.5, c.y + h * 0.5, c.z + t), false)
            label3d(text, Vector3(c.x, c.y, c.z + t + ln), h * 0.58, color, 0.0)
        else:
            box(mat, Vector3(c.x - w * 0.5, c.y - h * 0.5, c.z - t), Vector3(c.x + w * 0.5, c.y + h * 0.5, c.z), false)
            label3d(text, Vector3(c.x, c.y, c.z - t - ln), h * 0.58, color, PI)

func commit() -> void:
    for k in _keys:
        var s: SurfaceTool = _st[k]
        s.commit(_mesh)
        var idx := _mesh.get_surface_count() - 1
        _mesh.surface_set_material(idx, _mat(k))
    mesh_inst.mesh = _mesh
