extends RefCounted
## 角色零件几何：带倒角的盒子。
##
## 低多边形角色最难看的地方不是面数少，而是"直角"——纯 BoxMesh 的 12 条棱都是 90°，
## 正面剪影就是一块砖。这里的 bev_box() 生成"把 12 条棱各切一刀"的盒子：
## 6 个面 + 12 条棱面 + 8 个角三角 = 44 三角面（方块是 12），硬角全磨掉。
##
## 用法：
##     const CharBody := preload("res://scripts/charbody.gd")
##     mi.mesh = CharBody.bev_box(Vector3(0.42, 0.46, 0.26), 0.045)

## 带倒角盒子：size 是原方块尺寸，bev 是每条棱切掉的深度（角色上用 0.02~0.05）。
static func bev_box(size: Vector3, bev: float) -> ArrayMesh:
    var b := Vector3(maxf(bev, 0.0008), maxf(bev, 0.0008), maxf(bev, 0.0008))
    var h := size * 0.5 - b
    h = Vector3(maxf(h.x, 0.002), maxf(h.y, 0.002), maxf(h.z, 0.002))
    var V := []
    var N := []
    var I := []
    # ① 6 个面：4 个点按"绕中心一圈"的顺序给，不能给成交叉的 Z 形
    for ax in range(3):
        for s in [-1.0, 1.0]:
            var quad := []
            for rest in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
                var v := _slots(h, b, ax, s, rest)
                quad.append(Vector3(v[0], v[1], v[2]))
            _push(V, N, I, quad)
    # ② 12 条棱：由相邻两个面的点围成，沿第三个轴的那条棱
    for pr in [[0, 1], [0, 2], [1, 2]]:
        var a: int = pr[0]
        var c: int = pr[1]
        var d := 3 - a - c
        for sa in [-1.0, 1.0]:
            for sc in [-1.0, 1.0]:
                var ring := []
                for sd in [1.0, -1.0]:
                    var q1 := [0.0, 0.0, 0.0]
                    q1[a] = sa * (h[a] + b[a]); q1[c] = sc * h[c]; q1[d] = sd * h[d]
                    ring.append(Vector3(q1[0], q1[1], q1[2]))
                for sd2 in [-1.0, 1.0]:
                    var q2 := [0.0, 0.0, 0.0]
                    q2[a] = sa * h[a]; q2[c] = sc * (h[c] + b[c]); q2[d] = sd2 * h[d]
                    ring.append(Vector3(q2[0], q2[1], q2[2]))
                _push(V, N, I, ring)
    # ③ 8 个角三角
    for sx in [-1.0, 1.0]:
        for sy in [-1.0, 1.0]:
            for sz in [-1.0, 1.0]:
                var A := Vector3(sx * (h.x + b.x), sy * h.y, sz * h.z)
                var B := Vector3(sx * h.x, sy * (h.y + b.y), sz * h.z)
                var C := Vector3(sx * h.x, sy * h.y, sz * (h.z + b.z))
                _push(V, N, I, [A, B, C])
    var mesh := ArrayMesh.new()
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(V)
    arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(N)
    arr[Mesh.ARRAY_INDEX] = PackedInt32Array(I)
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return mesh

## 取"某个面"上的点：ax 是面法线所在的轴，s 是这一侧，rest 是另外两个轴的系数（按 a→(a+1)%3→(a+2)%3）
static func _slots(h: Vector3, b: Vector3, ax: int, s: float, rest: Array) -> Array:
    var o1 := (ax + 1) % 3
    var o2 := (ax + 2) % 3
    var v := [0.0, 0.0, 0.0]
    v[ax] = s * (h[ax] + b[ax])
    v[o1] = rest[0] * h[o1]
    v[o2] = rest[1] * h[o2]
    return v

## 把一圈点做成一个平面凸多边形：法线取"中心向外"（这是绕原点对称的凸体，所以中心方向就是外侧），
## 绕序不对就翻过来，保证背面剔除算的是外面。
static func _push(V: Array, N: Array, I: Array, poly: Array) -> void:
    if poly.size() < 3:
        return
    var c := Vector3.ZERO
    for p in poly:
        c += p
    c /= float(poly.size())
    var geom: Vector3 = (poly[1] - poly[0]).cross(poly[2] - poly[0])
    geom = c.normalized() if geom.length() < 0.000001 else geom.normalized()
    # 绕序是不是"从外面看逆时针"（凸体：中心方向就是外侧）
    var ccw_out := geom.dot(c) > 0.0
    var n: Vector3 = geom if ccw_out else -geom
    # Godot 的正面是**顺时针**绕序（跟 OpenGL 惯例相反）：从外面看是逆时针的要翻过来，
    # 否则这一面会被背面剔除掉，从外面看进去是一层黑。
    var ring := poly.duplicate()
    if ccw_out:
        ring.reverse()
    var base := V.size()
    for p in ring:
        V.append(p)
        N.append(n)
    for k in range(1, ring.size() - 1):
        I.append(base)
        I.append(base + k)
        I.append(base + k + 1)
## 椭圆截面放样：profile 是 [Vector3(y, rx, rz), ...]，从下往上；生成平滑着色的封闭体。
## 躯干这种"腰细、胸宽、肩部收口"的形体，用放样比叠几个倒角盒自然得多。
static func loft(profile: Array, segments := 16) -> ArrayMesh:
    if profile.size() < 2:
        return ArrayMesh.new()
    var seg := maxi(segments, 6)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings := []
    for p in profile:
        var y: float = p.x
        var rx: float = p.y
        var rz: float = p.z
        var ring := []
        for i in range(seg):
            var a := TAU * float(i) / float(seg)
            ring.append(Vector3(cos(a) * rx, y, sin(a) * rz))
        rings.append(ring)
    for r in range(rings.size() - 1):
        for i in range(seg):
            var j := (i + 1) % seg
            _quad_out(st, rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i])
    var b0 := Vector3(0.0, profile[0].x, 0.0)
    var t0 := Vector3(0.0, profile[profile.size() - 1].x, 0.0)
    for i in range(seg):
        var j := (i + 1) % seg
        _tri_out(st, b0, rings[0][i], rings[0][j], Vector3(0, -1, 0))
        _tri_out(st, t0, rings[rings.size() - 1][i], rings[rings.size() - 1][j], Vector3(0, 1, 0))
    st.index()
    st.generate_normals()
    return st.commit()

## 一圈四边面：按"质心朝外"定向，再翻成 Godot 的顺时针正面。
static func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    var cen := (a + b + c + d) * 0.25
    var out := Vector3(cen.x, 0.0, cen.z)
    var n := (b - a).cross(c - a)
    if out.length_squared() < 0.000001:
        out = n
    if n.dot(out) > 0.0:
        st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
        st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)
    else:
        st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
        st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
    var n := (b - a).cross(c - a)
    if n.dot(outward) > 0.0:
        st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
    else:
        st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)