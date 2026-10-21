class_name LaundryFigure
extends RefCounted
## 角色基座：放样躯干 + 分层衣服 + 独立头发壳。
## 四张三视图已到位（许砚 / 周秀兰老人 / 秀兰孩子 / 老周 / 阿七）。
## 按"主机能跑"来做：单角色 3000–6000 面，细节不省。

var a: LaundryArt

func _init(art: LaundryArt) -> void:
	a = art

# ================================================================ 放样基元
## profile: [[y, rx, rz], ...] 从下往上。seg 是圆周段数。
func loft(parent: Node3D, profile: Array, mat: Material, seg := 14, cap_top := true, cap_bottom := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := profile.size()
	var pts := []
	for r in range(rings):
		var pr: Array = profile[r]
		var y: float = pr[0]
		var rx: float = pr[1]
		var rz: float = pr[2]
		var row := []
		for i in range(seg):
			var ang := TAU * float(i) / float(seg)
			row.append(Vector3(cos(ang) * rx, y, sin(ang) * rz))
		pts.append(row)
	for r in range(rings - 1):
		for i in range(seg):
			var j := (i + 1) % seg
			var p00: Vector3 = pts[r][i]
			var p01: Vector3 = pts[r][j]
			var p10: Vector3 = pts[r + 1][i]
			var p11: Vector3 = pts[r + 1][j]
			var n := (p10 - p00).cross(p11 - p00).normalized()
			_tri(st, p00, p01, p11, n)
			_tri(st, p00, p11, p10, n)
	if cap_top:
		var top: Array = profile[rings - 1]
		var c := Vector3(0, top[0], 0)
		for i in range(seg):
			var j := (i + 1) % seg
			_tri(st, c, pts[rings - 1][i], pts[rings - 1][j], Vector3(0, 1, 0))
	if cap_bottom:
		var bot: Array = profile[0]
		var c2 := Vector3(0, bot[0], 0)
		for i in range(seg):
			var j := (i + 1) % seg
			_tri(st, c2, pts[0][j], pts[0][i], Vector3(0, -1, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _tri(st: SurfaceTool, x: Vector3, y: Vector3, z: Vector3, n: Vector3) -> void:
	st.set_normal(n); st.add_vertex(x)
	st.set_normal(n); st.add_vertex(y)
	st.set_normal(n); st.add_vertex(z)

## 沿 Y 轴的圆环带（罗纹、领口、下摆）
func band(parent: Node3D, y: float, rx: float, rz: float, h: float,
		mat: Material, seg := 16) -> MeshInstance3D:
	return loft(parent, [[y, rx, rz], [y + h, rx, rz]], mat, seg, false, false)

## 局部盒：挂在角色 root 上，坐标以角色脚下为原点
func lbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 局部柱：axis 为 x/y/z
func lcyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material,
		seg := 12, axis := "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.position = pos
	if axis == "x":
		mi.rotation.z = PI * 0.5
	elif axis == "z":
		mi.rotation.x = PI * 0.5
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 局部四边形
func lquad(parent: Node3D, a0: Vector3, b0: Vector3, c0: Vector3, d0: Vector3,
		mat: Material, nrm := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := (b0 - a0).cross(c0 - a0).normalized()
	if nrm != Vector3.ZERO and n.dot(nrm) < 0.0:
		var t := b0
		b0 = d0
		d0 = t
		n = -n
	_tri(st, a0, c0, b0, n)
	_tri(st, a0, d0, c0, n)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 椭球（头、肩、膝）
func blob(parent: Node3D, pos: Vector3, rx: float, ry: float, rz: float,
		mat: Material, seg := 12, rings := 6) -> MeshInstance3D:
	var prof := []
	for i in range(rings + 1):
		var t := float(i) / float(rings)
		var ang := PI * t
		var yy := -cos(ang) * ry
		var rr := sin(ang)
		prof.append([yy, maxf(rx * rr, 0.001), maxf(rz * rr, 0.001)])
	var mi := loft(parent, prof, mat, seg, false, false)
	mi.position = pos
	return mi

# ================================================================ 从 Blender 导入的模型
## 模型：assets/models/chars/old_lady.glb（Blender 4.5 建的，5.3 万面）
## 原点在脚底，身高 1.55，正面朝 +Z
func glb_figure(parent: Node3D, path: String, target_h: float,
		pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var packed = load(path)
	if packed == null:
		push_warning("LaundryFigure: 找不到模型 " + path)
		return null
	var inst: Node3D = packed.instantiate()
	inst.position = pos
	inst.rotation.y = yaw
	inst.set_meta("dynamic", true)      # 角色不参与静态合批
	parent.add_child(inst)
	# 按目标身高缩放（模型自带 1.55 m，若要精确对齐就缩放）
	var bb := _aabb(inst)
	if bb.size.y > 0.001:
		var sc := target_h / bb.size.y
		inst.scale = Vector3(sc, sc, sc)
	# 贴地
	var bb2 := _aabb(inst)
	inst.position.y += pos.y - bb2.position.y
	return inst

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out

# ================================================================ 周秀兰（老人）
## 三视图：深灰长开衫（过膝）、深色高领、黑长裤、黑软底鞋、灰白发髻、驼背。
## 剧本要"浑身是湿的"——用低粗糙 + 暗色湿痕做，不改模型。
func old_lady(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ZhouXiulan_Old"
	parent.add_child(root)

	var cardigan := a.plain(Color(0.115, 0.118, 0.125), 0.38, 0.0)
	var cardigan_dk := a.plain(Color(0.075, 0.078, 0.085), 0.30, 0.0)
	var turtleneck := a.plain(Color(0.085, 0.075, 0.075), 0.62)
	var trousers := a.plain(Color(0.055, 0.055, 0.060), 0.55)
	var skin := a.plain(Color(0.64, 0.585, 0.545), 0.66)
	var skin_dk := a.plain(Color(0.55, 0.48, 0.44), 0.70)
	var hair := a.plain(Color(0.62, 0.61, 0.585), 0.78)
	var shoe := a.plain(Color(0.045, 0.045, 0.048), 0.48, 0.15)
	var sole := a.plain(Color(0.16, 0.155, 0.15), 0.85)

	# —— 长裤
	for sx: float in [-1.0, 1.0]:
		loft(root, [
			[0.045, 0.052, 0.055],
			[0.10, 0.058, 0.060],
			[0.22, 0.055, 0.058],
			[0.42, 0.060, 0.064],
			[0.62, 0.070, 0.074],
			[0.86, 0.082, 0.086],
		], trousers, 12).position = Vector3(sx * 0.075, 0, 0)
	# —— 鞋
	for sx: float in [-1.0, 1.0]:
		var bx: float = sx * 0.075
		lbox(root, Vector3(bx, 0.032, 0.035), Vector3(0.088, 0.056, 0.215), shoe)
		lbox(root, Vector3(bx, 0.007, 0.035), Vector3(0.094, 0.014, 0.225), sole)

	# —— 开衫衣身（过膝、下摆开衩）
	loft(root, [
		[0.52, 0.132, 0.098],
		[0.62, 0.140, 0.102],
		[0.74, 0.148, 0.106],
		[0.88, 0.154, 0.110],
		[1.00, 0.158, 0.112],
		[1.10, 0.160, 0.112],
		[1.18, 0.158, 0.108],
		[1.25, 0.150, 0.100],
		[1.30, 0.132, 0.090],
	], cardigan, 16, true, false)
	band(root, 0.495, 0.132, 0.098, 0.038, cardigan_dk, 16)

	# —— 门襟 + 六颗纽扣
	var edge := a.plain(Color(0.145, 0.148, 0.155), 0.42)
	lbox(root, Vector3(-0.024, 1.02, 0.110), Vector3(0.032, 0.50, 0.014), edge)
	lbox(root, Vector3(0.024, 1.08, 0.110), Vector3(0.032, 0.38, 0.014), edge)
	for i in range(6):
		var by: float = 0.62 + float(i) * 0.104
		lcyl(root, Vector3(0.0, by, 0.114), 0.0115, 0.008,
			a.plain(Color(0.10, 0.10, 0.105), 0.35), 10, "z")

	# —— 两个贴袋
	for sx: float in [-1.0, 1.0]:
		lbox(root, Vector3(sx * 0.080, 0.78, 0.112), Vector3(0.066, 0.082, 0.012), cardigan_dk)
		lbox(root, Vector3(sx * 0.080, 0.820, 0.116), Vector3(0.070, 0.010, 0.008), edge)

	# —— 高领 + 脖子
	loft(root, [
		[1.25, 0.072, 0.068],
		[1.33, 0.064, 0.060],
		[1.38, 0.062, 0.058],
	], turtleneck, 14, false, false)
	loft(root, [
		[1.33, 0.048, 0.046],
		[1.42, 0.044, 0.042],
	], skin, 12, false, false)

	# —— 肩：驼背，往前塌
	for sx: float in [-1.0, 1.0]:
		blob(root, Vector3(sx * 0.140, 1.232, 0.010), 0.062, 0.048, 0.062, cardigan, 12, 5)

	# —— 手臂
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.140, 1.226, 0.008)
		arm.rotation.z = sx * 0.055
		arm.rotation.x = -0.10
		root.add_child(arm)
		loft(arm, [
			[0.02, 0.062, 0.060],
			[-0.16, 0.056, 0.054],
			[-0.34, 0.050, 0.048],
			[-0.46, 0.047, 0.045],
		], cardigan, 12, true, false)
		band(arm, -0.50, 0.044, 0.042, 0.040, cardigan_dk, 12)
		loft(arm, [
			[-0.545, 0.036, 0.032],
			[-0.60, 0.040, 0.034],
			[-0.655, 0.034, 0.028],
			[-0.69, 0.020, 0.018],
		], skin, 10, true, true)

	# —— 头
	var head := Node3D.new()
	head.position = Vector3(0, 1.475, 0.028)
	head.rotation.x = 0.06
	root.add_child(head)
	loft(head, [
		[-0.105, 0.052, 0.056],
		[-0.075, 0.066, 0.072],
		[-0.030, 0.078, 0.084],
		[0.020, 0.086, 0.092],
		[0.070, 0.082, 0.088],
		[0.110, 0.058, 0.062],
	], skin, 16, true, true)
	lbox(head, Vector3(-0.062, 0.008, 0.062), Vector3(0.020, 0.030, 0.010), skin_dk)
	lbox(head, Vector3(0.062, 0.008, 0.062), Vector3(0.020, 0.030, 0.010), skin_dk)
	lbox(head, Vector3(0, -0.020, 0.088), Vector3(0.020, 0.034, 0.026), skin)
	lbox(head, Vector3(-0.036, 0.014, 0.078), Vector3(0.030, 0.016, 0.012),
		a.plain(Color(0.16, 0.15, 0.145), 0.6))
	lbox(head, Vector3(0.036, 0.014, 0.078), Vector3(0.030, 0.016, 0.012),
		a.plain(Color(0.16, 0.15, 0.145), 0.6))
	lbox(head, Vector3(-0.036, 0.038, 0.080), Vector3(0.030, 0.006, 0.008), hair)
	lbox(head, Vector3(0.036, 0.038, 0.080), Vector3(0.030, 0.006, 0.008), hair)
	lbox(head, Vector3(0, -0.058, 0.080), Vector3(0.034, 0.006, 0.010),
		a.plain(Color(0.38, 0.32, 0.30), 0.7))
	lbox(head, Vector3(-0.030, -0.040, 0.082), Vector3(0.006, 0.026, 0.008), skin_dk)
	lbox(head, Vector3(0.030, -0.040, 0.082), Vector3(0.006, 0.026, 0.008), skin_dk)

	# —— 头发：整圈包（脸那块留空）+ 头顶 + 低发髻
	var hs := 20
	for i in range(hs):
		var a0 := TAU * float(i) / float(hs)
		var a1 := TAU * float(i + 1) / float(hs)
		var am := (a0 + a1) * 0.5
		var d := absf(wrapf(am - PI * 0.5, -PI, PI))
		if d < 0.92:
			continue
		var c0 := Vector3(cos(a0) * 0.092, 0, sin(a0) * 0.098)
		var c1 := Vector3(cos(a1) * 0.092, 0, sin(a1) * 0.098)
		lquad(head,
			Vector3(c0.x, -0.062, c0.z),
			Vector3(c1.x, -0.062, c1.z),
			Vector3(c1.x, 0.112, c1.z),
			Vector3(c0.x, 0.112, c0.z),
			hair, Vector3(c0.x, 0, c0.z))
	loft(head, [
		[0.068, 0.086, 0.092],
		[0.106, 0.062, 0.066],
		[0.122, 0.030, 0.032],
	], hair, 16, true, false)
	blob(head, Vector3(0, -0.010, -0.098), 0.042, 0.038, 0.034, hair, 12, 5)
	lbox(head, Vector3(-0.086, -0.020, 0.028), Vector3(0.012, 0.095, 0.010), hair)
	lbox(head, Vector3(0.084, -0.016, 0.032), Vector3(0.010, 0.082, 0.010), hair)

	# —— 湿：脚下水痕 + 衣摆滴水
	lbox(root, Vector3(0, 0.003, 0.04), Vector3(0.48, 0.002, 0.48),
		a.plain(Color(0.26, 0.29, 0.30), 0.08))
	for i in range(3):
		lbox(root, Vector3(-0.10 + float(i) * 0.09, 0.47, 0.106), Vector3(0.008, 0.030, 0.006),
			a.plain(Color(0.72, 0.80, 0.82), 0.05))

	return root
