class_name ProRoomArt
extends RefCounted
## 出租屋 Hero 场景：PBR 材质 + 真实资产 + 电影感灯光。
## 坐标系与 game.gd 的序章房间一致：地板 y=0，房间 6 x 5 x 3 米，窗在南墙 (+Z)。

const CharBody := preload("res://scripts/charbody.gd")
const TEX := "res://assets/textures/"
const MOD := "res://assets/models/"

var host: Node3D
var root: Node3D
var mats: Dictionary = {}
var model_cache: Dictionary = {}

func _init(h: Node3D) -> void:
	host = h

# ---------------------------------------------------------------- 材质
func _pbr(id: String, tint: Color, uv_scale: float, world_tri := true, rough_mul := 1.0, normal_scale := 0.9) -> StandardMaterial3D:
	var key := "%s|%s|%.3f|%s|%.2f" % [id, str(tint), uv_scale, str(world_tri), rough_mul]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	var base := TEX + id + "/"
	m.albedo_texture = load(base + "albedo.jpg")
	if m.albedo_texture == null:
		m.albedo_texture = load(base + "albedo.png")
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.jpg")
	m.normal_scale = normal_scale
	m.roughness_texture = load(base + "rough.jpg")
	m.roughness = rough_mul
	var ao = load(base + "ao.jpg")
	if ao != null:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.35
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_tri
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[key] = m
	return m

func _plain(c: Color, rough := 0.82, metal := 0.0) -> StandardMaterial3D:
	var key := "plain|%s|%.2f|%.2f" % [str(c), rough, metal]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	mats[key] = m
	return m

func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emit|%s|%.2f" % [str(c), energy]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	mats[key] = m
	return m

func _emit_unique(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.set_meta("base_emission", energy)
	var arr: Array = host.get_meta("room_warm_emit_mats", [])
	if arr == null:
		arr = []
	arr.append(m)
	host.set_meta("room_warm_emit_mats", arr)
	return m

func _register_warm_light(l: OmniLight3D) -> OmniLight3D:
	l.add_to_group("room_warm_light")
	l.set_meta("base_energy", l.light_energy)
	return l

func _fabric(id: String, tint: Color, double_sided := false) -> StandardMaterial3D:
	var key := "fabric|%s|%s|%s" % [id, str(tint), str(double_sided)]
	if mats.has(key):
		return mats[key]
	var m := _pbr(id, tint, 0.9, true, 0.95, 0.65)
	m.uv1_scale = Vector3(2.2, 2.2, 2.2)
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = m
	return m

func _glass_rain() -> ShaderMaterial:
	if mats.has("glass_rain"):
		return mats["glass_rain"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = SCREEN_UV;
	float t = TIME * 0.55;
	float col = 0.0;
	float rows = 18.0;
	for (int i = 0; i < 2; i++){
		float fi = float(i);
		vec2 q = uv * vec2(70.0, rows) + vec2(fi * 17.0, t * (7.0 + fi * 3.0));
		float cx = floor(q.x);
		float cy = floor(q.y);
		float h = hash(vec2(cx, cy));
		float streak = smoothstep(0.0, 0.16, abs(fract(q.x) - 0.5 - (h - 0.5) * 0.35));
		float drop = smoothstep(0.35, 0.0, abs(fract(q.y + h) - 0.5)) * step(0.72, h);
		col = max(col, (1.0 - streak) * drop * (0.35 + fi * 0.25));
	}
	float wide = smoothstep(0.35, 1.0, abs(uv.x - 0.5) * 2.0) * 0.05;
	vec2 duv = uv + vec2(col * 0.0018, col * 0.0006);
	vec3 scene = texture(screen_tex, duv).rgb;
	ALBEDO = scene * vec3(0.90, 0.96, 0.98) + vec3(0.30, 0.38, 0.36) * col;
	ALPHA = clamp(0.020 + col * 0.055 + wide * 0.5, 0.0, 0.18);
	ROUGHNESS = 0.05;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	mats["glass_rain"] = sm
	return sm

# ---------------------------------------------------------------- 基础几何
func _box(pos: Vector3, size: Vector3, mat: Material, collide := false, n := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	if n != "":
		mi.name = n
	root.add_child(mi)
	if collide:
		_col(pos, size)
	return mi

func _bev(pos: Vector3, size: Vector3, mat: Material, bev := 0.02, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CharBody.bev_box(size, bev)
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
	if collide:
		_col(pos, size)
	return mi

func _col(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	root.add_child(body)

func _cyl(pos: Vector3, radius: float, height: float, mat: Material, seg := 14, axis := "y") -> MeshInstance3D:
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
	root.add_child(mi)
	return mi

# ---------------------------------------------------------------- 模型
func _aabb_rec(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	if n is MeshInstance3D and n.mesh != null:
		out = xf * n.get_aabb()
		has = true
	for c in n.get_children():
		var cx: Transform3D = xf
		if c is Node3D:
			cx = xf * c.transform
		var cb := _aabb_rec(c, cx)
		if cb.size != Vector3.ZERO:
			if not has:
				out = cb
				has = true
			else:
				out = out.merge(cb)
	return out

func _tint_model(n: Node, tint: Color) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.get_active_material(i)
			if base is BaseMaterial3D:
				var mm: BaseMaterial3D = base.duplicate()
				mm.albedo_color = tint
				mi.set_surface_override_material(i, mm)

func _model(path: String, pos: Vector3, rot_y: float, target_h: float, tint := Color(1,1,1,1)) -> Node3D:
	var full := MOD + path
	var sc = model_cache.get(full)
	if sc == null:
		sc = load(full)
		model_cache[full] = sc
	if sc == null:
		push_warning("ProRoomArt missing model: " + full)
		return null
	var inst: Node3D = sc.instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	root.add_child(inst)
	if target_h > 0.0:
		var b := _aabb_rec(inst, inst.transform)
		if b.size.y > 0.001:
			var s := target_h / b.size.y
			inst.scale = Vector3(s, s, s)
	var b2 := _aabb_rec(inst, inst.transform)
	inst.position.y += pos.y - b2.position.y
	if tint != Color(1,1,1,1):
		_tint_model(inst, tint)
	return inst

# ---------------------------------------------------------------- 布面
func _cloth_top(center: Vector3, sx: float, sz: float, mat: Material, amp := 0.016, seed := 0.0) -> MeshInstance3D:
	var nx := 26
	var nz := 30
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for j in range(nz + 1):
		var v := float(j) / float(nz)
		var row: Array = []
		for i in range(nx + 1):
			var u := float(i) / float(nx)
			var x := (u - 0.5) * sx
			var z := (v - 0.5) * sz
			var edge := 0.0
			if u < 0.07:
				edge = (0.07 - u) / 0.07
			elif u > 0.93:
				edge = (u - 0.93) / 0.07
			if v < 0.05:
				edge = maxf(edge, (0.05 - v) / 0.05)
			elif v > 0.95:
				edge = maxf(edge, (v - 0.95) / 0.05)
			var y := sin(u * 26.0 + seed) * amp * 0.55 + sin(v * 34.0 + seed * 1.7) * amp * 0.45
			y += sin((u + v) * 17.0 + seed) * amp * 0.28
			y -= edge * edge * 0.16
			row.append(Vector3(x, y, z))
		rows.append(row)
	for j in range(nz):
		for i in range(nx):
			var a: Vector3 = rows[j][i]
			var b: Vector3 = rows[j][i + 1]
			var c: Vector3 = rows[j + 1][i + 1]
			var d: Vector3 = rows[j + 1][i]
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = center
	mi.material_override = mat
	root.add_child(mi)
	return mi

func _curtain(x_center: float, z0: float, top_y: float, width: float, height: float, mat: Material, phase: float) -> MeshInstance3D:
	var nx := 30
	var ny := 22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for j in range(ny + 1):
		var v := float(j) / float(ny)
		var row: Array = []
		for i in range(nx + 1):
			var u := float(i) / float(nx)
			var w := width * (0.80 + 0.20 * v)
			var x := x_center + (u - 0.5) * w
			var fold := sin(u * PI * 7.0 + phase) * (0.018 + 0.040 * v)
			fold += sin(u * PI * 13.0 + phase * 1.7) * 0.008 * v
			var y := top_y - v * height
			row.append(Vector3(x, y, z0 + fold))
		rows.append(row)
	for j in range(ny):
		for i in range(nx):
			var a: Vector3 = rows[j][i]
			var b: Vector3 = rows[j][i + 1]
			var c: Vector3 = rows[j + 1][i + 1]
			var d: Vector3 = rows[j + 1][i]
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	return mi

# ---------------------------------------------------------------- 构建
func build(r: Node3D) -> void:
	root = r
	_shell()
	_wainscot()
	_ceiling()
	_window()
	_radio()
	_door()
	_light_switch()
	_bed()
	_nightstand()
	_desk()
	_cabinet_and_tv()
	_kitchen()
	_shelf()
	_floor_props()
	_wall_decor()
	_kitchen_details()
	_lights()
	_atmosphere()
	_post_fx()

func _shell() -> void:
	var floor_mat := _pbr("old_wooden_floor_01", Color(0.58, 0.50, 0.42), 0.42, true, 0.95, 0.75)
	var wall_mat := _pbr("painted_plaster_wall", Color(0.64, 0.67, 0.60), 0.34, true, 1.0, 0.22)
	var wall_cool := _pbr("painted_plaster_wall", Color(0.60, 0.64, 0.58), 0.34, true, 1.0, 0.20)
	var paper_mat := _pbr("painted_plaster_wall", Color(0.57, 0.61, 0.55), 0.34, true, 1.0, 0.20)
	var ceil_mat := _pbr("painted_plaster_wall", Color(0.62, 0.62, 0.57), 0.32, true, 1.0, 0.18)

	# 8 x 6 m：x -4..4，z -3..3。门在北墙 (-Z)，窗在南墙 (+Z)。
	_box(Vector3(0, -0.07, 0), Vector3(8.0, 0.14, 6.0), floor_mat, true, "Floor")
	_box(Vector3(0, 3.10, 0), Vector3(8.0, 0.16, 6.0), ceil_mat, false, "Ceiling")
	# 北墙：中间留 1.12 m 门洞
	_box(Vector3(-2.28, 1.54, -2.96), Vector3(3.44, 3.08, 0.12), wall_mat, true)
	_box(Vector3(2.28, 1.54, -2.96), Vector3(3.44, 3.08, 0.12), wall_mat, true)
	_box(Vector3(0, 2.58, -2.96), Vector3(1.12, 1.00, 0.12), wall_mat, false)
	# 南墙：中间留窗洞
	_box(Vector3(-2.79, 1.54, 2.96), Vector3(2.42, 3.08, 0.12), wall_mat, true)
	_box(Vector3(2.79, 1.54, 2.96), Vector3(2.42, 3.08, 0.12), wall_mat, true)
	_box(Vector3(0, 0.47, 2.96), Vector3(3.16, 0.94, 0.12), wall_mat, true)
	_box(Vector3(0, 2.77, 2.96), Vector3(3.16, 0.54, 0.12), wall_mat, false)
	# 东西墙
	_box(Vector3(-3.96, 1.54, 0), Vector3(0.12, 3.08, 6.0), wall_cool, true)
	_box(Vector3(3.96, 1.54, 0), Vector3(0.12, 3.08, 6.0), wall_cool, true)
	# 左墙旧壁纸：保留一点住过人的痕迹
	_box(Vector3(-3.895, 1.50, -0.90), Vector3(0.02, 3.0, 3.70), paper_mat, false)
	var base_mat := _plain(Color(0.30, 0.28, 0.24), 0.75)
	_box(Vector3(-2.28, 0.075, -2.875), Vector3(3.40, 0.15, 0.05), base_mat)
	_box(Vector3(2.28, 0.075, -2.875), Vector3(3.40, 0.15, 0.05), base_mat)
	_box(Vector3(-2.79, 0.075, 2.875), Vector3(2.40, 0.15, 0.05), base_mat)
	_box(Vector3(2.79, 0.075, 2.875), Vector3(2.40, 0.15, 0.05), base_mat)
	_box(Vector3(0, 0.075, 2.875), Vector3(3.12, 0.15, 0.05), base_mat)
	_box(Vector3(-3.885, 0.075, 0), Vector3(0.05, 0.15, 5.80), base_mat)
	_box(Vector3(3.885, 0.075, 0), Vector3(0.05, 0.15, 5.80), base_mat)
	# 门与窗的封闭碰撞
	_col(Vector3(0, 1.08, -2.895), Vector3(1.02, 2.16, 0.07))
	_col(Vector3(0, 1.70, 2.96), Vector3(3.16, 1.56, 0.12))

func _wainscot() -> void:
	var wood := _pbr("oak_wood_planks", Color(0.36, 0.33, 0.26), 1.35, true, 0.9, 1.0)
	var rail := _plain(Color(0.26, 0.24, 0.20), 0.7)
	_box(Vector3(-2.28, 0.56, -2.885), Vector3(3.40, 0.86, 0.035), wood, false)
	_box(Vector3(2.28, 0.56, -2.885), Vector3(3.40, 0.86, 0.035), wood, false)
	_box(Vector3(-2.79, 0.56, 2.885), Vector3(2.40, 0.86, 0.035), wood, false)
	_box(Vector3(2.79, 0.56, 2.885), Vector3(2.40, 0.86, 0.035), wood, false)
	_box(Vector3(0, 0.56, 2.885), Vector3(3.08, 0.86, 0.035), wood, false)
	_box(Vector3(-3.885, 0.56, 0), Vector3(0.035, 0.86, 5.72), wood, false)
	_box(Vector3(3.885, 0.56, 0), Vector3(0.035, 0.86, 5.72), wood, false)
	for z in [-2.3, -1.3, -0.3, 0.7, 1.7, 2.5]:
		_box(Vector3(-3.86, 0.56, z), Vector3(0.05, 0.86, 0.045), rail)
		_box(Vector3(3.86, 0.56, z), Vector3(0.05, 0.86, 0.045), rail)
	for x in [-3.1, -2.2, 1.1, 2.1, 3.1]:
		_box(Vector3(x, 0.56, -2.86), Vector3(0.045, 0.86, 0.045), rail)
	for x in [-3.2, -2.3, 2.3, 3.2]:
		_box(Vector3(x, 0.56, 2.86), Vector3(0.045, 0.86, 0.045), rail)
	_box(Vector3(0, 1.02, -2.82), Vector3(7.76, 0.06, 0.08), rail)
	_box(Vector3(0, 1.02, 2.82), Vector3(7.76, 0.06, 0.08), rail)
	_box(Vector3(-3.84, 1.02, 0), Vector3(0.08, 0.06, 5.72), rail)
	_box(Vector3(3.84, 1.02, 0), Vector3(0.08, 0.06, 5.72), rail)

func _ceiling() -> void:
	var beam := _pbr("oak_wood_planks", Color(0.24, 0.20, 0.15), 1.6, true, 0.95, 1.0)
	for z in [-2.20, -0.75, 0.70, 2.15]:
		_box(Vector3(0, 2.96, z), Vector3(7.82, 0.16, 0.17), beam)
	_box(Vector3(0, 2.96, -2.86), Vector3(7.82, 0.12, 0.12), beam)
	_cyl(Vector3(0, 2.86, 0.25), 0.007, 0.32, _plain(Color(0.06,0.06,0.06), 0.6), 6)

func _window() -> void:
	var frame := _plain(Color(0.34, 0.36, 0.31), 0.62)
	_box(Vector3(-1.58, 1.70, 2.89), Vector3(0.10, 1.56, 0.12), frame)
	_box(Vector3(1.58, 1.70, 2.89), Vector3(0.10, 1.56, 0.12), frame)
	_box(Vector3(0, 2.45, 2.89), Vector3(3.26, 0.10, 0.12), frame)
	_box(Vector3(0, 0.95, 2.89), Vector3(3.26, 0.10, 0.12), frame)
	_box(Vector3(0, 0.90, 3.06), Vector3(3.42, 0.07, 0.34), _plain(Color(0.52, 0.50, 0.44), 0.7))
	var glass := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.10, 1.48)
	glass.mesh = qm
	glass.position = Vector3(0, 1.70, 2.93)
	glass.material_override = _glass_rain()
	glass.name = "WindowGlass"
	root.add_child(glass)
	_cyl(Vector3(0, 2.55, 2.77), 0.018, 3.46, _plain(Color(0.20,0.18,0.15), 0.55, 0.45), 10, "x")
	for sx in [-1.73, 1.73]:
		_cyl(Vector3(sx, 2.55, 2.77), 0.035, 0.07, _plain(Color(0.20,0.18,0.15), 0.55, 0.45), 10, "x")
	var curtain_mat := _fabric("rough_linen", Color(0.30, 0.34, 0.27), true)
	_curtain(-1.42, 2.76, 2.53, 0.86, 1.62, curtain_mat, 0.4)
	_curtain(1.42, 2.76, 2.53, 0.86, 1.62, curtain_mat, 2.1)

func _radio() -> void:
	# 父亲的旧收音机：只是普通生活背景，放在窗台上，能听深夜广播和电流声。
	var body := _bev(Vector3(1.18, 1.025, 2.93), Vector3(0.36, 0.18, 0.14), _plain(Color(0.26, 0.22, 0.18), 0.55), 0.025)
	body.name = "OldRadio"
	_bev(Vector3(1.18, 0.944, 2.93), Vector3(0.30, 0.018, 0.10), _plain(Color(0.10, 0.09, 0.08), 0.8), 0.006)
	_box(Vector3(1.11, 1.03, 2.858), Vector3(0.17, 0.12, 0.008), _plain(Color(0.06, 0.06, 0.055), 0.85), false)
	for gy in [-0.045, -0.015, 0.015, 0.045]:
		_box(Vector3(1.11, 1.03 + gy, 2.853), Vector3(0.15, 0.006, 0.006), _plain(Color(0.42, 0.35, 0.25), 0.5), false)
	_cyl(Vector3(1.27, 1.06, 2.855), 0.034, 0.012, _plain(Color(0.68, 0.56, 0.34), 0.35, 0.3), 16, "z")
	_box(Vector3(1.27, 1.06, 2.848), Vector3(0.004, 0.028, 0.004), _plain(Color(0.10, 0.08, 0.06), 0.6), false)
	for kx in [0.60, 0.68]:
		_cyl(Vector3(kx, 0.965, 2.855), 0.012, 0.016, _plain(Color(0.16, 0.13, 0.10), 0.45, 0.3), 10, "z")
	var ant := _cyl(Vector3(1.03, 1.16, 2.93), 0.004, 0.30, _plain(Color(0.35, 0.33, 0.28), 0.35, 0.7), 8)
	ant.rotation.z = 0.38
	var light := _box(Vector3(1.35, 1.085, 2.858), Vector3(0.012, 0.012, 0.006), _emit(Color(1.0, 0.42, 0.16), 2.2), false)
	light.name = "RadioLight"
	light.visible = false
	host.set_meta("room_radio_light", light)

func _door() -> void:
	var door_mat := _pbr("oak_wood_planks", Color(0.32, 0.24, 0.18), 1.5, true, 0.85, 1.0)
	var trim := _plain(Color(0.28, 0.26, 0.22), 0.7)
	_box(Vector3(0, 1.08, -2.895), Vector3(1.02, 2.16, 0.07), door_mat, false)
	for py in [1.55, 0.62]:
		_bev(Vector3(0, py, -2.852), Vector3(0.64, 0.62 if py > 1.0 else 0.55, 0.022), _plain(Color(0.18,0.20,0.17), 0.8), 0.012)
	_box(Vector3(-0.55, 1.12, -2.87), Vector3(0.09, 2.30, 0.15), trim)
	_box(Vector3(0.55, 1.12, -2.87), Vector3(0.09, 2.30, 0.15), trim)
	_box(Vector3(0, 2.24, -2.87), Vector3(1.22, 0.10, 0.15), trim)
	_cyl(Vector3(0.37, 1.02, -2.83), 0.038, 0.04, _plain(Color(0.76,0.58,0.26), 0.30, 0.85), 14, "z")
	_cyl(Vector3(0.37, 1.02, -2.78), 0.014, 0.11, _plain(Color(0.76,0.58,0.26), 0.30, 0.85), 10, "z")
	for hy in [0.5, 1.65]:
		_cyl(Vector3(-0.49, hy, -2.84), 0.014, 0.06, _plain(Color(0.42,0.36,0.24), 0.5, 0.7), 8, "z")
	var env := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.012, 0.23)
	env.mesh = bm
	env.position = Vector3(0, 0.012, -2.78)
	env.material_override = _plain(Color(0.86, 0.83, 0.72), 0.9)
	env.name = "Envelope"
	root.add_child(env)
	host.prologue_envelope = env
	env.visible = false

func _light_switch() -> void:
	# 门边真实墙面板：底板 + 小拨杆。game.gd 切灯时拨杆会翻转。
	var plate := _plain(Color(0.78, 0.76, 0.68), 0.58)
	var inner := _plain(Color(0.34, 0.33, 0.30), 0.55)
	_box(Vector3(0.78, 1.18, -2.875), Vector3(0.13, 0.18, 0.025), plate)
	_box(Vector3(0.78, 1.18, -2.858), Vector3(0.075, 0.105, 0.010), inner)
	var lever := _bev(Vector3(0.78, 1.18, -2.845), Vector3(0.038, 0.070, 0.020), _plain(Color(0.25, 0.24, 0.20), 0.42, 0.55), 0.004)
	lever.name = "RoomLightSwitchLever"
	lever.rotation.x = -0.38
	host.set_meta("room_switch_lever", lever)

func _bed() -> void:
	# 左后角：床头靠北墙 (-Z)，床侧靠西墙 (-X)，不挡门也不挡窗。
	_model("old_bed_frame/old_bed_frame_2k.gltf", Vector3(-3.45, 0, -1.95), 0.0, 0.0, Color(0.40, 0.35, 0.31))
	var sheet := _fabric("rough_linen", Color(0.72, 0.70, 0.62))
	var duvet := _fabric("rough_linen", Color(0.40, 0.46, 0.42))
	var throw_mat := _fabric("poly_wool_herringbone", Color(0.34, 0.26, 0.20))
	_bev(Vector3(-3.45, 0.50, -1.93), Vector3(0.88, 0.26, 1.88), _plain(Color(0.55,0.53,0.46), 0.9), 0.06)
	_bev(Vector3(-3.45, 0.645, -1.93), Vector3(0.90, 0.07, 1.90), sheet, 0.03)
	_bev(Vector3(-3.45, 0.75, -1.67), Vector3(0.94, 0.22, 1.36), duvet, 0.09)
	_cloth_top(Vector3(-3.45, 0.865, -1.71), 0.94, 1.38, duvet, 0.022, 1.2)
	_cloth_top(Vector3(-3.45, 0.80, -1.23), 0.94, 0.62, throw_mat, 0.014, 3.4)
	_bev(Vector3(-2.965, 0.60, -1.83), Vector3(0.035, 0.48, 1.10), throw_mat, 0.015)
	_bev(Vector3(-2.955, 0.56, -1.51), Vector3(0.02, 0.40, 0.08), throw_mat, 0.008)
	_bev(Vector3(-2.955, 0.56, -2.11), Vector3(0.02, 0.40, 0.08), throw_mat, 0.008)
	_cloth_top(Vector3(-3.45, 0.815, -2.33), 0.94, 0.34, _fabric("poly_wool_herringbone", Color(0.46, 0.37, 0.28)), 0.012, 5.1)
	_bev(Vector3(-3.45, 0.70, -2.68), Vector3(0.68, 0.17, 0.38), sheet, 0.07)
	_bev(Vector3(-3.45, 0.81, -2.65), Vector3(0.62, 0.14, 0.34), _fabric("rough_linen", Color(0.78,0.76,0.68)), 0.06)
	for z in [-2.50, -1.60]:
		_bev(Vector3(-3.45, 0.13, z), Vector3(0.78, 0.22, 0.62), _plain(Color(0.20,0.21,0.22), 0.9), 0.02)
	_box(Vector3(-3.45, 0.012, -0.63), Vector3(1.30, 0.02, 1.10), _fabric("poly_wool_herringbone", Color(0.34,0.32,0.28)), false)
	# 床右侧的拖鞋：生活气，不占通道
	for i in range(2):
		var sl := _bev(Vector3(-2.78 + float(i) * 0.22, 0.055, -1.42 - float(i) * 0.16), Vector3(0.16, 0.09, 0.31), _plain(Color(0.20,0.20,0.22), 0.85), 0.025)
		sl.rotation.y = -0.22 + float(i) * 0.45
	_col(Vector3(-3.45, 0.38, -1.93), Vector3(1.00, 0.76, 1.95))

func _nightstand() -> void:
	_model("ClassicNightstand_01/ClassicNightstand_01_1k.gltf", Vector3(-2.42, 0, -2.55), 0.0, 0.0, Color(0.95, 0.90, 0.83))
	_model("desk_lamp_arm_01/desk_lamp_arm_01_1k.gltf", Vector3(-2.54, 0.70, -2.63), -0.5, 0.55, Color(0.92,0.88,0.80))
	_model("alarm_clock_01/alarm_clock_01_1k.gltf", Vector3(-2.26, 0.70, -2.37), PI * 0.5, 0.16)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-2.36, 0.70, -2.57), PI * 0.5, 0.12)
	_cyl(Vector3(-2.57, 0.735, -2.42), 0.035, 0.09, _plain(Color(0.80,0.78,0.70), 0.4), 14)
	_col(Vector3(-2.42, 0.36, -2.55), Vector3(0.56, 0.72, 0.46))

func _desk() -> void:
	# 右前区域：书桌 + 椅子 + 台灯，和厨房分开。
	var desk := _model("wooden_table_02/wooden_table_02_1k.gltf", Vector3(2.55, 0, 1.75), 0.0, 0.0, Color(0.92, 0.90, 0.85))
	host.set_meta("room_desk",desk)
	_model("painted_wooden_chair_01/painted_wooden_chair_01_1k.gltf", Vector3(2.55, 0, 1.03), PI, 0.0, Color(0.72,0.66,0.56))
	_model("desk_lamp_arm_01/desk_lamp_arm_01_1k.gltf", Vector3(2.97, 0.80, 1.98), -2.4, 0.46, Color(0.86,0.82,0.74))
	var phone := _bev(Vector3(2.51, 0.815, 1.58), Vector3(0.078, 0.010, 0.155), _plain(Color(0.045,0.05,0.055), 0.32), 0.006)
	phone.rotation.y = 0.22
	host.set_meta("phone_world_body", phone)
	var screen := _box(Vector3(2.51, 0.821, 1.58), Vector3(0.066, 0.002, 0.138), _emit(Color(0.55, 0.75, 0.78), 0.55), false)
	screen.rotation.y = 0.22
	host.set_meta("phone_screen", screen)
	_model("binder_notebook/binder_notebook_1k.gltf", Vector3(2.27, 0.805, 1.82), 0.35, 0.0, Color(0.94,0.92,0.86))
	_bev(Vector3(2.77, 0.806, 1.64), Vector3(0.24, 0.006, 0.31), _plain(Color(0.86,0.84,0.75), 0.92), 0.004)
	_cyl(Vector3(2.87, 0.845, 1.52), 0.042, 0.09, _plain(Color(0.72,0.70,0.62), 0.35), 16)
	_cyl(Vector3(2.91, 0.845, 1.52), 0.012, 0.055, _plain(Color(0.72,0.70,0.62), 0.35), 8, "z")
	_cyl(Vector3(2.23, 0.812, 1.66), 0.005, 0.16, _plain(Color(0.12,0.12,0.13), 0.4), 6, "x")
	_bev(Vector3(2.20, 0.835, 2.00), Vector3(0.22, 0.07, 0.28), _plain(Color(0.80,0.78,0.70), 0.9), 0.008)
	_bev(Vector3(2.93, 0.20, 1.50), Vector3(0.44, 0.40, 0.42), _plain(Color(0.44,0.33,0.22), 0.95), 0.02)
	_col(Vector3(2.55, 0.40, 1.75), Vector3(1.10, 0.80, 0.72))

func _cabinet_and_tv() -> void:
	# 右墙中段：小电视柜，夹在厨房和书桌之间。
	_model("painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf", Vector3(3.62, 0, -0.35), PI * 0.5, 0.0, Color(0.80, 0.82, 0.78))
	_model("Television_01/Television_01_1k.gltf", Vector3(3.62, 1.19, -0.35), PI * 0.5, 0.0, Color(0.72,0.74,0.72))
	_box(Vector3(3.30, 1.16, -0.23), Vector3(0.006, 0.012, 0.012), _emit(Color(0.30, 1.0, 0.45), 3.0), false)
	_bev(Vector3(3.58, 1.24, -0.73), Vector3(0.26, 0.06, 0.34), _plain(Color(0.10,0.11,0.11), 0.55, 0.2), 0.012)
	_bev(Vector3(3.58, 1.29, -0.73), Vector3(0.18, 0.01, 0.10), _plain(Color(0.32,0.32,0.30), 0.5), 0.004)
	_col(Vector3(3.62, 0.60, -0.35), Vector3(0.64, 1.20, 0.96))

func _kitchen() -> void:
	# 右后区域：半开放小厨房。沿右墙一字台面 + 北墙转角灶台。
	var cabinet := _pbr("oak_wood_planks", Color(0.34, 0.30, 0.24), 1.2, true, 0.9, 1.0)
	var top := _plain(Color(0.44, 0.44, 0.42), 0.55)
	var steel := _plain(Color(0.56, 0.57, 0.56), 0.30, 0.75)
	var tile := _pbr("painted_plaster_wall", Color(0.62, 0.66, 0.62), 1.1, true, 0.55, 0.35)
	# 厨房地面材质，和睡眠区区分
	_box(Vector3(2.95, 0.011, -2.02), Vector3(1.82, 0.022, 1.92), _pbr("painted_plaster_wall", Color(0.46, 0.48, 0.46), 1.8, true, 0.65, 0.4), false)
	# 右墙一字台面
	_box(Vector3(3.56, 0.40, -1.95), Vector3(0.68, 0.76, 1.95), cabinet, true)
	_box(Vector3(3.56, 0.80, -1.95), Vector3(0.74, 0.06, 2.05), top)
	for z in [-2.55, -1.95, -1.35]:
		_box(Vector3(3.215, 0.42, z), Vector3(0.02, 0.66, 0.02), _plain(Color(0.22,0.20,0.16), 0.8))
		_box(Vector3(3.195, 0.62, z + 0.16), Vector3(0.10, 0.02, 0.02), _plain(Color(0.58,0.50,0.38), 0.5, 0.5))
	# 北墙转角灶台
	_box(Vector3(2.58, 0.40, -2.62), Vector3(1.08, 0.76, 0.58), cabinet, true)
	_box(Vector3(2.58, 0.80, -2.62), Vector3(1.16, 0.06, 0.64), top)
	# 水槽 + 龙头
	_box(Vector3(3.52, 0.825, -1.75), Vector3(0.42, 0.02, 0.34), steel)
	_box(Vector3(3.52, 0.812, -1.75), Vector3(0.31, 0.012, 0.24), _plain(Color(0.18,0.19,0.20), 0.45, 0.5))
	_cyl(Vector3(3.76, 0.94, -1.75), 0.016, 0.26, steel, 12)
	_cyl(Vector3(3.69, 1.06, -1.75), 0.014, 0.15, steel, 10, "x")
	_cyl(Vector3(3.62, 1.02, -1.75), 0.013, 0.08, steel, 10)
	# 灶台与锅
	_cyl(Vector3(2.45, 0.835, -2.62), 0.12, 0.025, _plain(Color(0.18,0.18,0.19), 0.55, 0.4), 18)
	_cyl(Vector3(2.80, 0.835, -2.62), 0.10, 0.022, _plain(Color(0.18,0.18,0.19), 0.55, 0.4), 18)
	_cyl(Vector3(2.45, 0.90, -2.62), 0.085, 0.11, _plain(Color(0.72,0.73,0.72), 0.28, 0.65), 16)
	# 防溅板 + 吊柜 + 开放层架
	_box(Vector3(3.885, 1.13, -1.95), Vector3(0.02, 0.62, 2.00), tile)
	_box(Vector3(3.76, 2.06, -2.28), Vector3(0.26, 0.62, 1.00), cabinet)
	_box(Vector3(3.62, 2.06, -2.28), Vector3(0.02, 0.56, 0.44), _plain(Color(0.30,0.27,0.22), 0.8))
	_box(Vector3(3.84, 1.48, -1.04), Vector3(0.24, 0.035, 0.72), _plain(Color(0.34,0.31,0.26), 0.75))
	for z in [-1.30, -1.06, -0.82]:
		_cyl(Vector3(3.82, 1.55, z), 0.035, 0.10, _plain(Color(0.70,0.66,0.52), 0.55), 12)
	# 半开放矮隔断：挡住灶台侧面，不挡镜头
	_box(Vector3(1.98, 0.55, -2.10), Vector3(0.09, 1.10, 1.50), _pbr("oak_wood_planks", Color(0.30, 0.27, 0.22), 1.1, true, 0.9, 1.0), true)
	_box(Vector3(1.98, 1.11, -2.10), Vector3(0.16, 0.05, 1.56), _plain(Color(0.48,0.42,0.32), 0.6))
	_col(Vector3(3.56, 0.42, -1.95), Vector3(0.70, 0.84, 2.00))
	_col(Vector3(2.58, 0.42, -2.62), Vector3(1.12, 0.84, 0.62))

func _shelf() -> void:
	# 左前 / 靠窗：书架单独放在西墙，不跟厨房挤在同一面墙。
	_model("wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf", Vector3(-3.62, 0, 1.65), PI * 0.5, 0.0, Color(0.86, 0.82, 0.76))
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 0.40, 1.34), PI * 0.5, 0.0)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 0.40, 1.58), PI * 0.5, 0.0)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 1.06, 1.42), PI * 0.5, 0.0)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 1.06, 1.66), PI * 0.5, 0.0)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 1.46, 1.38), PI * 0.5, 0.0)
	_model("book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf", Vector3(-3.60, 1.46, 1.62), PI * 0.5, 0.0)
	_bev(Vector3(-3.60, 1.80, 1.74), Vector3(0.24, 0.16, 0.34), _plain(Color(0.38,0.36,0.31), 0.95), 0.02)
	_cyl(Vector3(-3.60, 2.02, 1.82), 0.055, 0.10, _plain(Color(0.46,0.30,0.20), 0.9), 12)
	for k in range(5):
		_cone_leaf(Vector3(-3.60, 2.14, 1.82), 0.05, 0.22, k)
	_col(Vector3(-3.62, 0.95, 1.65), Vector3(0.36, 1.90, 0.96))

func _cone_leaf(pos: Vector3, r: float, h: float, k: int) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 5
	mi.mesh = cm
	mi.position = pos + Vector3(cos(k * 1.7) * 0.05, 0, sin(k * 1.7) * 0.05)
	mi.rotation.z = cos(k) * 0.4
	mi.rotation.x = sin(k * 1.3) * 0.4
	mi.material_override = _plain(Color(0.18, 0.32, 0.20), 0.9)
	root.add_child(mi)

func _floor_props() -> void:
	# 中央地毯
	_bev(Vector3(0.10, 0.014, 0.75), Vector3(3.40, 0.024, 2.20), _fabric("poly_wool_herringbone", Color(0.42, 0.38, 0.32)), 0.012)
	_box(Vector3(0.10, 0.027, 0.75), Vector3(3.10, 0.004, 1.95), _pbr("poly_wool_herringbone", Color(0.50, 0.45, 0.37), 1.4, true, 1.0, 0.8), false)
	# 父亲的纸箱：靠窗、在书桌左侧，不挡门
	_model("cardboard_box_01/cardboard_box_01_1k.gltf", Vector3(0.78, 0, 1.90), 0.45, 0.50, Color(0.78, 0.70, 0.58))
	var lid := _bev(Vector3(0.78, 0.49, 2.10), Vector3(0.48, 0.02, 0.32), _plain(Color(0.52,0.39,0.25), 0.95), 0.005)
	lid.rotation.x = -0.9
	_cyl(Vector3(0.68, 0.39, 1.86), 0.045, 0.22, _plain(Color(0.55,0.56,0.52), 0.35, 0.6), 14)
	_bev(Vector3(0.92, 0.41, 1.90), Vector3(0.16, 0.02, 0.10), _plain(Color(0.78,0.74,0.62), 0.8), 0.004)
	# 洗衣篮、植物、垃圾桶、书堆
	_cyl(Vector3(-3.25, 0.22, -0.75), 0.23, 0.42, _plain(Color(0.34,0.33,0.28), 0.95), 16)
	for i in range(3):
		_bev(Vector3(-3.25 + (i - 1) * 0.05, 0.45, -0.75), Vector3(0.20, 0.06, 0.26), _plain(Color(0.40,0.42,0.44), 0.95), 0.02)
	_model("potted_plant_01/potted_plant_01_1k.gltf", Vector3(-3.10, 0, 2.56), 0.6, 1.05, Color(0.92,0.94,0.86))
	_cyl(Vector3(0.55, 0.22, 2.55), 0.16, 0.44, _plain(Color(0.26,0.27,0.26), 0.95), 14)
	_bev(Vector3(-1.55, 0.055, -2.20), Vector3(0.30, 0.11, 0.22), _plain(Color(0.74,0.72,0.62), 0.95), 0.012)
	_bev(Vector3(-1.58, 0.135, -2.22), Vector3(0.28, 0.08, 0.20), _plain(Color(0.66,0.64,0.54), 0.95), 0.012)
	# 书桌下的线
	_cyl(Vector3(3.72, 0.30, 1.55), 0.008, 0.30, _plain(Color(0.08,0.08,0.08), 0.7), 6)
	_cyl(Vector3(3.64, 0.28, 1.42), 0.008, 0.26, _plain(Color(0.08,0.08,0.08), 0.7), 6, "x")

func _wall_decor() -> void:
	# 床头上方：普通家庭照
	_wall_frame_back(-2.42, 1.85, -2.895, 0.46, 0.60, Color(0.46, 0.41, 0.31))
	# 西墙两幅小画
	_wall_frame(-3.885, 1.95, -1.90, 0.42, 0.56, Color(0.36, 0.41, 0.36))
	_wall_frame(-3.885, 1.86, -1.12, 0.34, 0.46, Color(0.44, 0.38, 0.30))
	# 门边旧电话（没接线，只是父亲留下的旧物）
	_model("vintage_telephone_wall_clock/vintage_telephone_wall_clock_1k.gltf", Vector3(-1.45, 1.62, -2.885), 0.0, 0.0, Color(0.92,0.88,0.80))
	# 书桌右墙上的便签 / 日历
	_box(Vector3(3.885, 1.80, 1.55), Vector3(0.018, 0.56, 0.40), _plain(Color(0.86,0.84,0.74), 0.9))
	_box(Vector3(3.873, 1.98, 1.55), Vector3(0.004, 0.05, 0.34), _plain(Color(0.55,0.48,0.36), 0.9))
	for i in range(4):
		_box(Vector3(3.873, 1.58 + i * 0.10, 1.55), Vector3(0.004, 0.004, 0.32), _plain(Color(0.58,0.55,0.48), 0.9))
	# 门边小日历
	_box(Vector3(-1.02, 1.86, -2.885), Vector3(0.30, 0.40, 0.018), _plain(Color(0.72,0.68,0.56), 0.9))
	_box(Vector3(-1.02, 2.01, -2.872), Vector3(0.26, 0.06, 0.004), _plain(Color(0.48,0.38,0.28), 0.9))
	_string_lights()

func _wall_frame_back(x: float, y: float, z: float, w: float, h: float, photo: Color) -> void:
	var wood := _plain(Color(0.20, 0.16, 0.12), 0.82)
	_box(Vector3(x, y, z), Vector3(w, h, 0.035), wood)
	_box(Vector3(x, y, z + 0.021), Vector3(w - 0.10, h - 0.10, 0.006), _plain(photo, 0.9))
	_box(Vector3(x, y + h * 0.12, z + 0.025), Vector3(w - 0.14, h * 0.22, 0.004), _plain(photo.lightened(0.16), 0.9))
	var t := 0.045
	_box(Vector3(x, y + h * 0.5 - t * 0.5, z + 0.030), Vector3(w, t, 0.028), wood)
	_box(Vector3(x, y - h * 0.5 + t * 0.5, z + 0.030), Vector3(w, t, 0.028), wood)
	_box(Vector3(x + w * 0.5 - t * 0.5, y, z + 0.030), Vector3(t, h, 0.028), wood)
	_box(Vector3(x - w * 0.5 + t * 0.5, y, z + 0.030), Vector3(t, h, 0.028), wood)

func _wall_frame(x: float, y: float, z: float, w: float, h: float, photo: Color) -> void:
	var wood := _plain(Color(0.20, 0.16, 0.12), 0.82)
	_box(Vector3(x, y, z), Vector3(0.035, h, w), wood)
	_box(Vector3(x + 0.021, y, z), Vector3(0.006, h - 0.10, w - 0.10), _plain(photo, 0.9))
	_box(Vector3(x + 0.025, y + h * 0.12, z), Vector3(0.004, h * 0.22, w - 0.14), _plain(photo.lightened(0.16), 0.9))
	var t := 0.045
	_box(Vector3(x + 0.030, y + h * 0.5 - t * 0.5, z), Vector3(0.028, t, w), wood)
	_box(Vector3(x + 0.030, y - h * 0.5 + t * 0.5, z), Vector3(0.028, t, w), wood)
	_box(Vector3(x + 0.030, y, z + w * 0.5 - t * 0.5), Vector3(0.028, h, t), wood)
	_box(Vector3(x + 0.030, y, z - w * 0.5 + t * 0.5), Vector3(0.028, h, t), wood)
func _string_lights() -> void:
	# 窗上方的暖色串灯：关灯后留一点低亮度的生活气息。
	var wire := _plain(Color(0.12, 0.11, 0.09), 0.8)
	for i in range(10):
		var x0 := -2.20 + float(i) * 0.44
		var x1 := x0 + 0.44
		var y0 := 2.40 - sin(float(i) / 9.0 * PI) * 0.13
		var y1 := 2.40 - sin(float(i + 1) / 9.0 * PI) * 0.13
		var seg := _box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 2.86), Vector3(0.45, 0.006, 0.006), wire)
		seg.rotation.z = atan2(y1 - y0, x1 - x0)
	for i in range(9):
		var u := float(i) / 8.0
		var x := -2.10 + u * 4.20
		var y := 2.39 - sin(u * PI) * 0.13
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.020
		sm.height = 0.040
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.position = Vector3(x, y, 2.86)
		mi.material_override = _emit_unique(Color(1.0, 0.74, 0.42), 1.0)
		root.add_child(mi)
		if i % 3 == 1:
			var l := OmniLight3D.new()
			l.position = Vector3(x, y - 0.02, 2.80)
			l.light_color = Color(1.0, 0.66, 0.34)
			l.light_energy = 0.16
			l.omni_range = 1.5
			l.shadow_enabled = false
			root.add_child(l)
			_register_warm_light(l)

func _kitchen_details() -> void:
	# 厨房小物件：抹布、调味罐、沥水架、墙上挂钩。
	_box(Vector3(3.86, 1.36, -0.82), Vector3(0.015, 0.26, 0.18), _plain(Color(0.62,0.68,0.61), 0.95))
	for z in [-1.28, -1.10, -0.92]:
		_cyl(Vector3(3.82, 1.55, z), 0.030, 0.09, _plain(Color(0.74,0.70,0.56), 0.55), 10)
	_box(Vector3(3.82, 1.30, -0.62), Vector3(0.10, 0.04, 0.34), _plain(Color(0.54,0.56,0.55), 0.4, 0.5))
	for z in [-0.76, -0.62, -0.48]:
		_box(Vector3(3.80, 1.34, z), Vector3(0.06, 0.10, 0.02), _plain(Color(0.80,0.78,0.70), 0.6))
	_box(Vector3(3.86, 1.72, -2.60), Vector3(0.012, 0.10, 0.10), _plain(Color(0.62,0.62,0.58), 0.5, 0.4))

func _lights() -> void:
	_cyl(Vector3(0, 2.88, 0.25), 0.006, 0.24, _plain(Color(0.08,0.08,0.07), 0.6), 6)
	var shade := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.038
	cm.bottom_radius = 0.235
	cm.height = 0.20
	cm.radial_segments = 24
	shade.mesh = cm
	shade.position = Vector3(0, 2.66, 0.25)
	var shm := _plain(Color(0.24, 0.26, 0.21), 0.5, 0.3)
	shm.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.material_override = shm
	root.add_child(shade)
	_cyl(Vector3(0, 2.565, 0.25), 0.155, 0.012, _emit_unique(Color(1.0, 0.78, 0.48), 0.7), 24)
	var bulb := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 0.052
	bsm.height = 0.104
	bulb.mesh = bsm
	bulb.position = Vector3(0, 2.56, 0.25)
	bulb.material_override = _emit_unique(Color(1.0, 0.84, 0.58), 1.8)
	root.add_child(bulb)
	var main := OmniLight3D.new()
	main.position = Vector3(0, 2.55, 0.25)
	main.light_color = Color(1.0, 0.74, 0.46)
	main.light_energy = 1.75
	main.omni_range = 9.0
	main.omni_attenuation = 1.2
	main.shadow_enabled = true
	main.shadow_opacity = 0.38
	main.shadow_blur = 2.0
	main.light_volumetric_fog_energy = 0.55
	root.add_child(main)
	_register_warm_light(main)
	host.set_meta("room_main_light", main)
	var bounce := OmniLight3D.new()
	bounce.position = Vector3(0, 1.35, 0.30)
	bounce.light_color = Color(0.86, 0.80, 0.70)
	bounce.light_energy = 0.26
	bounce.omni_range = 6.5
	bounce.shadow_enabled = false
	root.add_child(bounce)
	_register_warm_light(bounce)
	var desk_l := OmniLight3D.new()
	desk_l.position = Vector3(2.85, 1.02, 1.90)
	desk_l.light_color = Color(1.0, 0.64, 0.34)
	desk_l.light_energy = 1.45
	desk_l.omni_range = 4.2
	desk_l.shadow_enabled = false
	root.add_child(desk_l)
	_register_warm_light(desk_l)
	host.set_meta("room_desk_light", desk_l)
	var bed_l := OmniLight3D.new()
	bed_l.position = Vector3(-2.45, 1.05, -2.45)
	bed_l.light_color = Color(1.0, 0.70, 0.42)
	bed_l.light_energy = 0.90
	bed_l.omni_range = 3.5
	bed_l.shadow_enabled = false
	root.add_child(bed_l)
	_register_warm_light(bed_l)
	host.set_meta("room_bed_light", bed_l)
	var kitchen_l := OmniLight3D.new()
	kitchen_l.position = Vector3(3.25, 1.55, -1.95)
	kitchen_l.light_color = Color(1.0, 0.72, 0.42)
	kitchen_l.light_energy = 0.55
	kitchen_l.omni_range = 3.6
	kitchen_l.shadow_enabled = false
	root.add_child(kitchen_l)
	_register_warm_light(kitchen_l)
	host.set_meta("room_kitchen_light", kitchen_l)
	# 窗外冷光：关灯后保留
	var win := SpotLight3D.new()
	win.position = Vector3(0.0, 14.15, 326.75)
	win.rotation.x = -0.30
	win.light_color = Color(0.58, 0.76, 0.84)
	win.light_energy = 3.8
	win.spot_range = 20.0
	win.spot_angle = 40.0
	win.spot_angle_attenuation = 1.4
	win.shadow_enabled = true
	win.light_volumetric_fog_energy = 2.2
	root.add_child(win)
	host.set_meta("room_window_light", win)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 1.55, 2.30)
	fill.light_color = Color(0.42, 0.58, 0.70)
	fill.light_energy = 0.55
	fill.omni_range = 5.5
	fill.shadow_enabled = false
	root.add_child(fill)

func _atmosphere() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 18
	dust.lifetime = 16.0
	dust.preprocess = 12.0
	dust.visibility_aabb = AABB(Vector3(-4, 0, -3), Vector3(8, 3, 6))
	dust.position = Vector3(0, 1.4, 0.4)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.4, 1.2, 2.5)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.03
	pm.gravity = Vector3(0, -0.002, 0)
	pm.scale_min = 0.0012
	pm.scale_max = 0.0035
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.08
	pm.turbulence_noise_scale = 1.4
	dust.process_material = pm
	var dq := QuadMesh.new()
	dq.size = Vector2(0.012, 0.012)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# 径向渐变让尘埃是柔光点，而不是白色小方块
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 32
	gtex.height = 32
	dm.albedo_texture = gtex
	dm.albedo_color = Color(1.0, 0.86, 0.62, 0.16)
	dm.vertex_color_use_as_albedo = true
	dq.material = dm
	dust.draw_pass_1 = dq
	root.add_child(dust)
	host.set_meta("room_dust", dust)

func _post_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.name = "PrologueFX"
	host.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.42;
uniform float grain_amount = 0.020;
uniform float chromatic_amount = 0.0012;
uniform float glitch = 0.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float ca = chromatic_amount + glitch * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca * 2.0).b;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(vec3(0.90, 0.97, 0.98), vec3(1.04, 1.01, 0.95), smoothstep(0.12, 0.80, l));
	col = (col - 0.5) * 1.055 + 0.5;
	float d = length(c) * 1.38;
	col *= 1.0 - vignette_strength * smoothstep(0.30, 0.95, d);
	float n = hash(uv * vec2(1600.0, 900.0) + fract(TIME) * 37.0);
	col += (n - 0.5) * grain_amount;
	col += glitch * (hash(uv * 600.0 + TIME) - 0.5) * 0.35;
	COLOR = vec4(col, 1.0);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	rect.material = sm
	host.set_meta("prologue_fx_layer", layer)
	host.set_meta("prologue_fx_mat", sm)
	layer.visible = false

func apply_room_environment(env: Environment) -> void:
	if env == null:
		return
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.13, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.58, 0.52)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.07
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.95
	env.adjustment_brightness = 1.0
	if RenderingServer.get_rendering_device() != null:
		env.ssao_enabled = true
		env.ssao_radius = 0.55
		env.ssao_intensity = 1.5
		env.ssao_power = 1.6
		env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.68, 0.62)
	env.fog_light_energy = 0.65
	env.fog_density = 0.012
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.set("volumetric_fog_enabled", RenderingServer.get_current_rendering_method()=="forward_plus")
	env.set("volumetric_fog_density", 0.012)
	env.set("volumetric_fog_albedo", Color(0.62, 0.72, 0.68))
	env.set("volumetric_fog_emission", Color(0.06, 0.09, 0.08))
	env.set("volumetric_fog_emission_energy", 0.18)
	env.set("volumetric_fog_length", 26.0)
	env.set("volumetric_fog_detail_spread", 1.2)
	env.set("volumetric_fog_gi_inject", 0.4)
