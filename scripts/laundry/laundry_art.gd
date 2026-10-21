class_name LaundryArt
extends RefCounted
## 得利洗衣店 · 建模基座
## 与 pro_room_art.gd 同一套标准：Poly Haven 四件套 + 世界三平面 UV + 倒角盒子 + 克制的灯。
## 坐标系：Y 向上，1F 地面 y = 0。

const CharBody := preload("res://scripts/charbody.gd")
const TEX := "res://assets/textures/"

var root: Node3D
var body: StaticBody3D
var mats: Dictionary = {}
var stats := {"meshes": 0, "tris": 0, "lights": 0}
var _stack: Array = []

## 进/出一组局部坐标：组内所有 box / cyl / col 都相对组原点与朝向。
## 用来做"面向 +X 的洗衣机"这类需要转 90° 的整件道具。
func push_group(pos: Vector3, yaw := 0.0, dynamic := false) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	if dynamic:
		holder.set_meta("dynamic", true)
	root.add_child(holder)
	var b := StaticBody3D.new()
	holder.add_child(b)
	_stack.push_back([root, body])
	root = holder
	body = b
	return holder

func pop_group() -> void:
	if _stack.is_empty():
		return
	var prev = _stack.pop_back()
	root = prev[0]
	body = prev[1]

func _init(h: Node3D) -> void:
	root = h
	body = StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)

# ---------------------------------------------------------------- 材质
## id 对应 assets/textures/<id>/{albedo,normal,rough,ao}.jpg
func pbr(id: String, uv_scale := 1.0, tint := Color.WHITE, rough_mul := 1.0,
		metal := 0.0, normal_scale := 1.0) -> StandardMaterial3D:
	var key := "pbr|%s|%.2f|%s|%.2f|%.2f|%.2f" % [id, uv_scale, str(tint), rough_mul, metal, normal_scale]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	var base := TEX + id + "/"
	var alb: Texture2D = load(base + "albedo.jpg")
	if alb == null:
		alb = load(base + "albedo.png")
	if alb == null:
		push_warning("LaundryArt: 缺贴图 " + base)
		m.albedo_color = Color(0.5, 0.5, 0.5)
		mats[key] = m
		return m
	m.albedo_texture = alb
	m.albedo_color = tint
	var nrm: Texture2D = load(base + "normal.jpg")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = normal_scale
	var rgh: Texture2D = load(base + "rough.jpg")
	if rgh != null:
		m.roughness_texture = rgh
	m.roughness = rough_mul
	m.metallic = metal
	var ao: Texture2D = load(base + "ao.jpg")
	if ao != null:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.4
	# 关键：世界空间三平面 —— 不需要 UV，任何尺寸的盒子都不会拉伸
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[key] = m
	return m

func plain(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "plain|%s|%.2f|%.2f" % [str(c), rough, metal]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	mats[key] = m
	return m

func emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emit|%s|%.2f" % [str(c), energy]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats[key] = m
	return m

func glass(c := Color(0.62, 0.70, 0.72, 0.22)) -> StandardMaterial3D:
	var key := "glass|%s" % str(c)
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.roughness = 0.06
	m.metallic = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = m
	return m

## 程序化方砖：一张 128² 的"单块砖"图，靠世界三平面按 tile_m 重复。
## 用来做剧本里写死的"白色方砖 0.30、缝发黑"——现成贴图没有这个规格。
func tile_mat(tile_m: float, base: Color, grout: Color, grout_px := 7) -> StandardMaterial3D:
	var key := "tile|%.3f|%s|%s" % [tile_m, str(base), str(grout)]
	if mats.has(key):
		return mats[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(grout)
	for y in range(grout_px, n - grout_px):
		for x in range(grout_px, n - grout_px):
			var h := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			h = h - floor(h)
			var k := 0.92 + 0.08 * h
			# 靠边的地方压暗一点，读得出砖缝的深度
			var edge := min(min(x - grout_px, n - grout_px - x), min(y - grout_px, n - grout_px - y))
			if edge < 5:
				k *= 0.90
			img.set_pixel(x, y, Color(base.r * k, base.g * k, base.b * k))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.55
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	m.uv1_triplanar_sharpness = 6.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[key] = m
	return m

# ---------------------------------------------------------------- 几何
func _add(mi: MeshInstance3D) -> MeshInstance3D:
	root.add_child(mi)
	stats["meshes"] = int(stats["meshes"]) + 1
	if mi.mesh != null:
		stats["tris"] = int(stats["tris"]) + int(mi.mesh.get_faces().size() / 3)
	return mi

func box(pos: Vector3, size: Vector3, mat: Material, collide := false, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	_add(mi)
	if collide:
		col(pos, size, rot_y)
	return mi

func bev(pos: Vector3, size: Vector3, mat: Material, b := 0.02, collide := false, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CharBody.bev_box(size, b)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	_add(mi)
	if collide:
		col(pos, size, rot_y)
	return mi

func cyl(pos: Vector3, radius: float, height: float, mat: Material, seg := 16, axis := "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = seg
	mi.mesh = cm
	mi.position = pos
	if axis == "x":
		mi.rotation.z = PI * 0.5
	elif axis == "z":
		mi.rotation.x = PI * 0.5
	mi.material_override = mat
	_add(mi)
	return mi

func col(pos: Vector3, size: Vector3, rot_y := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)

## 任意四边形（给环形前脸这种非轴对齐的面用）
func quad(a0: Vector3, b0: Vector3, c0: Vector3, d0: Vector3, mat: Material, nrm := Vector3.ZERO) -> void:
	var n := (b0 - a0).cross(c0 - a0)
	if n.length_squared() < 1e-9:
		return
	n = n.normalized()
	if nrm != Vector3.ZERO and n.dot(nrm) < 0.0:
		var t := b0
		b0 = d0
		d0 = t
		n = -n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(n); st.add_vertex(a0)
	st.set_normal(n); st.add_vertex(c0)
	st.set_normal(n); st.add_vertex(b0)
	st.set_normal(n); st.add_vertex(a0)
	st.set_normal(n); st.add_vertex(d0)
	st.set_normal(n); st.add_vertex(c0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	stats["meshes"] = int(stats["meshes"]) + 1
	stats["tris"] = int(stats["tris"]) + 2

func quad_xz(x0: float, z0: float, x1: float, z1: float, y: float, mat: Material, up := true) -> void:
	# 一块水平面（地板 / 天花板），单向独立网格，方便贴图方向不歪
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0, 1, 0) if up else Vector3(0, -1, 0)
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	if up:
		st.set_normal(n); st.add_vertex(a); st.set_normal(n); st.add_vertex(b); st.set_normal(n); st.add_vertex(c)
		st.set_normal(n); st.add_vertex(a); st.set_normal(n); st.add_vertex(c); st.set_normal(n); st.add_vertex(d)
	else:
		st.set_normal(n); st.add_vertex(a); st.set_normal(n); st.add_vertex(c); st.set_normal(n); st.add_vertex(b)
		st.set_normal(n); st.add_vertex(a); st.set_normal(n); st.add_vertex(d); st.set_normal(n); st.add_vertex(c)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_add(mi)

# ---------------------------------------------------------------- 灯
func omni(pos: Vector3, color: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	l.omni_attenuation = 1.4
	root.add_child(l)
	stats["lights"] = int(stats["lights"]) + 1
	return l

func spot(pos: Vector3, look_at: Vector3, color: Color, energy: float, rng: float,
		angle := 32.0, shadow := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	l.look_at_from_position(pos, look_at, Vector3.UP)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.shadow_enabled = shadow
	root.add_child(l)
	stats["lights"] = int(stats["lights"]) + 1
	return l

# ---------------------------------------------------------------- 文字
func label(text: String, pos: Vector3, height := 0.12, color := Color(0.9, 0.9, 0.88),
		rot_y := 0.0, font_size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	l.font_size = font_size
	l.pixel_size = height / float(font_size) * 2.2
	l.position = pos
	l.rotation.y = rot_y
	l.modulate = color
	l.shaded = false
	l.double_sided = true
	root.add_child(l)
	stats["meshes"] = int(stats["meshes"]) + 1
	return l

## 静态合批：把所有不带 dynamic 祖先的 MeshInstance 按材质并成一张张网格。
## 滚筒、门这类要动的组用 push_group(..., true) 标过，不参与。
func merge_static() -> Dictionary:
	var groups := {}
	_collect(root, false, groups)
	var merged := 0
	var before := 0
	for mat in groups.keys():
		var list: Array = groups[mat]
		before += list.size()
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		var vcount := 0
		for mi in list:
			var mm: MeshInstance3D = mi
			if mm.mesh == null:
				continue
			var xf: Transform3D = mm.global_transform
			for s_i in range(mm.mesh.get_surface_count()):
				var arr: Array = mm.mesh.surface_get_arrays(s_i)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if verts.size() == 0:
					continue
				var base: int = vcount
				for k in range(verts.size()):
					var pos2: Vector3 = xf * verts[k]
					var n2: Vector3 = (xf.basis * norms[k]).normalized() if norms.size() > k else Vector3.UP
					st.set_normal(n2)
					st.set_uv(uvs[k] if uvs.size() > k else Vector2.ZERO)
					st.add_vertex(pos2)
					vcount += 1
				if idx.size() > 0:
					for k in range(0, idx.size(), 3):
						st.add_index(base + idx[k])
						st.add_index(base + idx[k + 1])
						st.add_index(base + idx[k + 2])
				any = true
			mm.get_parent().remove_child(mm)
			mm.queue_free()
			merged += 1
		if any:
			var mi2 := MeshInstance3D.new()
			mi2.mesh = st.commit()
			mi2.material_override = mat
			mi2.name = "merged"
			root.add_child(mi2)
	stats["meshes"] = int(stats["meshes"]) - before + groups.size()
	return {"before": before, "merged": merged, "groups": groups.size()}

func _collect(n: Node, in_dyn: bool, groups: Dictionary) -> void:
	var dyn := in_dyn or n.has_meta("dynamic")
	if n is MeshInstance3D and not dyn:
		var mi: MeshInstance3D = n
		if mi.mesh != null:
			var key = mi.material_override
			if key == null:
				key = "null"
			if not groups.has(key):
				groups[key] = []
			groups[key].append(mi)
	for c in n.get_children():
		_collect(c, dyn, groups)

func done() -> Dictionary:
	return stats
