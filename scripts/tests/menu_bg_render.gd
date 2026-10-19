extends SceneTree
## 主菜单背景：诡异事务局 · 夜班档案室（一次性渲染脚本）

const MOD := "res://assets/models/"
const TEX := "res://assets/textures/"
const OUT := "res://_预览/截图/"

var scene: Node3D
var mats: Dictionary = {}
var model_cache: Dictionary = {}

func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    scene = Node3D.new()
    scene.name = "ArchiveRoom"
    root.add_child(scene)
    _build_room()
    _build_shelves()
    _build_desk()
    _build_props()
    _build_lights()
    _build_dust()
    _build_post()
    _build_camera()
    _run()

func _run() -> void:
    for i in range(55):
        await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    img.save_png(OUT + "bureau_bg.png")
    print("[SHOT] bureau_bg ", img.get_width(), "x", img.get_height())
    quit()

# ---------------------------------------------------------------- 材质
func _pbr(id: String, tint: Color, uv_scale: float, rough_mul := 1.0, normal_scale := 0.8) -> StandardMaterial3D:
    var key := "%s|%s|%.3f|%.2f" % [id, str(tint), uv_scale, rough_mul]
    if mats.has(key):
        return mats[key]
    var m := StandardMaterial3D.new()
    var base := TEX + id + "/"
    m.albedo_texture = load(base + "albedo.jpg")
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
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mats[key] = m
    return m

func _plain(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
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

# ---------------------------------------------------------------- 几何
func _box(pos: Vector3, size: Vector3, mat: Material, n := "") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = mat
    if n != "":
        mi.name = n
    scene.add_child(mi)
    return mi

func _cyl(pos: Vector3, radius: float, height: float, mat: Material, seg := 20) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = radius
    cm.bottom_radius = radius
    cm.height = height
    cm.radial_segments = seg
    mi.mesh = cm
    mi.position = pos
    mi.material_override = mat
    scene.add_child(mi)
    return mi

func _cyl_between(a: Vector3, b: Vector3, radius: float, mat: Material, seg := 12) -> MeshInstance3D:
    var mid := (a + b) * 0.5
    var mi := _cyl(mid, radius, a.distance_to(b), mat, seg)
    var dir := (b - a).normalized()
    mi.quaternion = Quaternion(Vector3.UP, dir)
    return mi

func _plane(pos: Vector3, size: Vector2, mat: Material, n := "") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = size
    mi.mesh = pm
    mi.position = pos
    mi.material_override = mat
    if n != "":
        mi.name = n
    scene.add_child(mi)
    return mi

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

func _model(path: String, pos: Vector3, rot_y: float, target_h: float, on_floor := true, tint := Color(1,1,1,1)) -> Node3D:
    var full: String = MOD + path
    var sc = model_cache.get(full)
    if sc == null:
        sc = load(full)
        model_cache[full] = sc
    if sc == null:
        push_warning("missing model: " + full)
        return null
    var inst: Node3D = sc.instantiate()
    inst.position = pos
    inst.rotation.y = rot_y
    scene.add_child(inst)
    if target_h > 0.0:
        var b: AABB = _aabb_rec(inst, inst.transform)
        if b.size.y > 0.001:
            var s: float = target_h / b.size.y
            inst.scale = Vector3(s, s, s)
    if on_floor:
        var b2: AABB = _aabb_rec(inst, inst.transform)
        inst.position.y += pos.y - b2.position.y
    if tint != Color(1,1,1,1):
        _tint_model(inst, tint)
    return inst

func _model_scaled(path: String, pos: Vector3, rot_y: float, s: float, tint := Color(1,1,1,1)) -> Node3D:
    var full: String = MOD + path
    var sc = model_cache.get(full)
    if sc == null:
        sc = load(full)
        model_cache[full] = sc
    if sc == null:
        return null
    var inst: Node3D = sc.instantiate()
    inst.position = pos
    inst.rotation.y = rot_y
    inst.scale = Vector3.ONE * s
    scene.add_child(inst)
    if tint != Color(1,1,1,1):
        _tint_model(inst, tint)
    return inst

func _tex(path: String) -> ImageTexture:
    var img := Image.load_from_file(ProjectSettings.globalize_path(path))
    return ImageTexture.create_from_image(img)
# ---------------------------------------------------------------- 房间
func _build_room() -> void:
    var floor_mat := _pbr("old_wooden_floor_01", Color(0.62, 0.55, 0.47), 1.1, 1.0)
    var wall_mat := _pbr("painted_plaster_wall", Color(0.32, 0.37, 0.35), 0.55, 1.0)
    var ceil_mat := _plain(Color(0.09, 0.11, 0.11), 0.95)
    _plane(Vector3(0, 0, -0.3), Vector2(8.2, 10.0), floor_mat, "Floor")
    _plane(Vector3(0, 3.15, -0.3), Vector2(8.2, 10.0), ceil_mat, "Ceiling")
    _box(Vector3(0, 1.58, -5.0), Vector3(8.2, 3.16, 0.10), wall_mat, "BackWall")
    _box(Vector3(-4.05, 1.58, -0.3), Vector3(0.10, 3.16, 10.0), wall_mat, "LeftWall")
    _box(Vector3(4.05, 1.58, -0.3), Vector3(0.10, 3.16, 10.0), wall_mat, "RightWall")
    var trim := _plain(Color(0.10, 0.12, 0.11), 0.8)
    _box(Vector3(0, 0.10, -4.93), Vector3(8.0, 0.20, 0.04), trim)
    _box(Vector3(-3.98, 0.10, -0.3), Vector3(0.04, 0.20, 9.6), trim)
    _box(Vector3(3.98, 0.10, -0.3), Vector3(0.04, 0.20, 9.6), trim)
    # 左侧门缝冷光
    var door_light := _emit(Color(0.52, 0.72, 0.82), 0.9)
    _box(Vector3(-4.03, 1.32, -2.05), Vector3(0.02, 2.55, 1.28), door_light, "DoorGlow")
    var frame := _plain(Color(0.07, 0.09, 0.09), 0.7)
    _box(Vector3(-3.99, 1.32, -2.72), Vector3(0.10, 2.70, 0.08), frame)
    _box(Vector3(-3.99, 1.32, -1.38), Vector3(0.10, 2.70, 0.08), frame)
    _box(Vector3(-3.99, 2.67, -2.05), Vector3(0.10, 0.08, 1.42), frame)
    # 右侧高窗
    _box(Vector3(3.99, 1.95, -1.15), Vector3(0.02, 1.85, 1.55), _emit(Color(0.26, 0.40, 0.50), 0.22), "WindowGlow")
    _box(Vector3(3.96, 1.95, -1.15), Vector3(0.05, 1.95, 0.05), frame)
    # 雨幕
    var rain := MeshInstance3D.new()
    var rq := QuadMesh.new()
    rq.size = Vector2(1.55, 1.85)
    rain.mesh = rq
    rain.position = Vector3(3.972, 1.95, -1.15)
    rain.rotation.y = -PI * 0.5
    var rsh := Shader.new()
    rsh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.78, 0.86, 0.22);
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
    vec2 uv = UV;
    float streak = 0.0;
    for (int i = 0; i < 3; i++){
        float fi = float(i);
        vec2 q = uv * vec2(26.0, 7.0) + vec2(fi * 9.0, 0.0);
        float cx = floor(q.x);
        float h = hash(vec2(cx, fi));
        float x = abs(fract(q.x) - h);
        float y = fract(q.y - h * 0.7);
        streak += smoothstep(0.020, 0.0, x) * smoothstep(0.75, 0.0, y);
    }
    ALBEDO = tint.rgb;
    ALPHA = tint.a * (0.20 + streak * 0.80);
}
"""
    var rsm := ShaderMaterial.new()
    rsm.shader = rsh
    rain.material_override = rsm
    scene.add_child(rain)
    _box(Vector3(3.96, 1.95, -0.38), Vector3(0.05, 1.95, 0.05), frame)
    _box(Vector3(3.96, 1.95, -1.92), Vector3(0.05, 1.95, 0.05), frame)
    _box(Vector3(3.96, 2.92, -1.15), Vector3(0.05, 0.05, 1.60), frame)
    _box(Vector3(3.96, 0.98, -1.15), Vector3(0.05, 0.05, 1.60), frame)
    _box(Vector3(3.96, 1.95, -1.15), Vector3(0.05, 1.95, 0.05), frame)
    

    # 档案室标牌（贴图，避免 Label3D 字体图集卡顿）
    var sign_mi := MeshInstance3D.new()
    var sign_q := QuadMesh.new()
    sign_q.size = Vector2(1.22, 0.36)
    sign_mi.mesh = sign_q
    sign_mi.position = Vector3(0.20, 2.62, -4.86)
    var sign_mat := StandardMaterial3D.new()
    sign_mat.albedo_texture = _tex("res://_预览/菜单参考/tex/sign_archive.png")
    sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sign_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sign_mat.albedo_color = Color(0.82, 0.82, 0.82, 1.0)
    sign_mi.material_override = sign_mat
    scene.add_child(sign_mi)
# ---------------------------------------------------------------- 档案架
func _build_shelves() -> void:
    var xs: Array[float] = [-3.30, -1.98, -0.66, 0.66, 1.98, 3.30]
    for si in range(xs.size()):
        var sx: float = xs[si]
        _model("wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf", Vector3(sx, 0, -4.30), 0.0, 2.10, true, Color(0.62, 0.54, 0.42))
        for row in range(4):
            var y: float = 0.37 + row * 0.48
            for bi in range(3):
                if (si * 3 + row + bi) % 5 == 0:
                    continue
                var bx: float = sx - 0.42 + bi * 0.42
                var pal: Array[Color] = [
                    Color(0.58, 0.49, 0.35), Color(0.66, 0.59, 0.45),
                    Color(0.40, 0.44, 0.38), Color(0.34, 0.15, 0.12),
                    Color(0.50, 0.43, 0.31), Color(0.28, 0.31, 0.29)
                ]
                var c: Color = pal[(si + row * 2 + bi) % pal.size()]
                _box(Vector3(bx, y, -3.98), Vector3(0.29, 0.34, 0.40), _plain(c, 0.92))
                _box(Vector3(bx, y + 0.04, -3.775), Vector3(0.16, 0.035, 0.006), _plain(Color(0.74, 0.70, 0.58), 0.9))
    # 两端立柜（压暗，避免抢焦点）
    _model("painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf", Vector3(-3.74, 0, -3.45), PI * 0.5, 1.90, true, Color(0.40, 0.36, 0.30))
    _model("painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf", Vector3(3.72, 0, -2.90), -PI * 0.5, 1.90, true, Color(0.40, 0.36, 0.30))
    _model("cardboard_box_01/cardboard_box_01_1k.gltf", Vector3(-2.55, 0, -3.25), 0.25, 0.36)
    _model("cardboard_box_01/cardboard_box_01_1k.gltf", Vector3(-2.20, 0, -3.55), -0.15, 0.28)
    _model("potted_plant_01/potted_plant_01_1k.gltf", Vector3(3.50, 0, -3.55), 0.0, 1.30, true, Color(0.45, 0.50, 0.42))

# ---------------------------------------------------------------- 书桌
func _build_desk() -> void:
    var oak := _pbr("oak_wood_planks", Color(0.61, 0.50, 0.37), 0.85, 1.0)
    var dark := _plain(Color(0.09, 0.08, 0.07), 0.75)
    # 桌面
    _box(Vector3(1.02, 0.735, 0.42), Vector3(2.30, 0.065, 0.98), oak, "DeskTop")
    # 围板
    _box(Vector3(1.02, 0.655, 0.42), Vector3(2.18, 0.105, 0.88), oak, "DeskApron")
    # 桌腿
    for lx in [-1.06, 1.06]:
        for lz in [-0.39, 0.39]:
            _box(Vector3(1.02 + lx, 0.33, 0.42 + lz), Vector3(0.075, 0.66, 0.075), dark)
    # 右侧抽屉柜
    _box(Vector3(1.90, 0.26, 0.56), Vector3(0.52, 0.52, 0.72), oak)
    for i in range(3):
        _box(Vector3(1.90, 0.10 + i * 0.15, 0.925), Vector3(0.44, 0.010, 0.012), dark)
        _box(Vector3(1.90, 0.10 + i * 0.15, 0.932), Vector3(0.075, 0.016, 0.018), _plain(Color(0.58, 0.47, 0.31), 0.5, 0.5))
    # 桌垫
    _box(Vector3(0.88, 0.770, 0.55), Vector3(0.92, 0.006, 0.54), _plain(Color(0.10, 0.17, 0.14), 0.72), "DeskMat")

# ---------------------------------------------------------------- 桌面物件
func _build_props() -> void:
    var manila: Array[Color] = [Color(0.64, 0.54, 0.37), Color(0.70, 0.62, 0.46), Color(0.57, 0.48, 0.33)]
    # 卷宗堆
    for i in range(6):
        var c: Color = manila[i % manila.size()]
        _box(Vector3(1.24 + i * 0.007, 0.783 + i * 0.020, 0.58 + i * 0.004), Vector3(0.38, 0.018, 0.27), _plain(c, 0.92))
        _box(Vector3(1.24 + i * 0.007, 0.792 + i * 0.020, 0.458), Vector3(0.28, 0.004, 0.008), _plain(Color(0.30, 0.26, 0.19), 0.9))

    # 摊开的纸 + 红章印
    _box(Vector3(0.70, 0.773, 0.70), Vector3(0.32, 0.004, 0.24), _plain(Color(0.76, 0.72, 0.61), 0.95))
    var stamp_mi := MeshInstance3D.new()
    var stamp_q := QuadMesh.new()
    stamp_q.size = Vector2(0.17, 0.17)
    stamp_mi.mesh = stamp_q
    stamp_mi.position = Vector3(0.70, 0.777, 0.70)
    stamp_mi.rotation.x = -PI * 0.5
    var stamp_mat := StandardMaterial3D.new()
    stamp_mat.albedo_texture = _tex("res://_预览/菜单参考/tex/stamp_no_supplement.png")
    stamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    stamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    stamp_mat.albedo_color = Color(0.85, 0.85, 0.85, 0.95)
    stamp_mi.material_override = stamp_mat
    scene.add_child(stamp_mi)
    # 钢笔
    _cyl_between(Vector3(0.42, 0.780, 0.80), Vector3(0.56, 0.780, 0.76), 0.006, _plain(Color(0.10, 0.10, 0.11), 0.35, 0.6), 10)
    # 印章
    _box(Vector3(1.46, 0.90, 0.47), Vector3(0.080, 0.042, 0.080), _plain(Color(0.30, 0.09, 0.075), 0.55))
    _box(Vector3(1.46, 0.945, 0.47), Vector3(0.032, 0.055, 0.032), _plain(Color(0.42, 0.31, 0.19), 0.5))
    # 活页夹（按固定比例，不再按高度缩放）
    _model_scaled("binder_notebook/binder_notebook_1k.gltf", Vector3(1.78, 0.780, 0.76), 0.42, 0.55, Color(0.55, 0.50, 0.40))
    # 闹钟
    _model("alarm_clock_01/alarm_clock_01_1k.gltf", Vector3(0.36, 0.780, 0.60), -0.35, 0.18)
    # 保温杯
    _cyl(Vector3(2.04, 0.790, 0.52), 0.047, 0.25, _plain(Color(0.16, 0.24, 0.20), 0.45, 0.35), 18)
    _cyl(Vector3(2.04, 0.922, 0.52), 0.050, 0.024, _plain(Color(0.54, 0.56, 0.54), 0.35, 0.6), 18)
    _cyl(Vector3(2.04, 0.941, 0.52), 0.043, 0.016, _plain(Color(0.09, 0.11, 0.10), 0.6), 18)
    # 台灯：底座 + 灯杆 + 灯臂 + 灯罩
    var metal := _plain(Color(0.09, 0.10, 0.10), 0.42, 0.55)
    _cyl(Vector3(1.80, 0.792, 0.10), 0.075, 0.035, metal, 24)
    _cyl_between(Vector3(1.80, 0.81, 0.10), Vector3(1.80, 1.16, 0.10), 0.011, metal, 12)
    _cyl_between(Vector3(1.80, 1.16, 0.10), Vector3(1.72, 1.25, 0.22), 0.009, metal, 12)
    var shade := MeshInstance3D.new()
    var sm := CylinderMesh.new()
    sm.top_radius = 0.030
    sm.bottom_radius = 0.108
    sm.height = 0.14
    sm.radial_segments = 26
    shade.mesh = sm
    shade.position = Vector3(1.72, 1.26, 0.23)
    shade.rotation = Vector3(0.34, 0.0, -0.22)
    var shade_mat := _plain(Color(0.12, 0.13, 0.12), 0.48, 0.35)
    shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    shade.material_override = shade_mat
    scene.add_child(shade)
    var bulb := MeshInstance3D.new()
    var bs := SphereMesh.new()
    bs.radius = 0.030
    bs.height = 0.060
    bulb.mesh = bs
    bulb.position = Vector3(1.72, 1.19, 0.235)
    bulb.material_override = _emit(Color(1.0, 0.78, 0.50), 2.2)
    scene.add_child(bulb)
    # 墙上的老电话 / 时钟
    _model("vintage_telephone_wall_clock/vintage_telephone_wall_clock_1k.gltf", Vector3(2.55, 2.05, -4.80), 0.0, 0.42, false, Color(0.70, 0.64, 0.52))

# ---------------------------------------------------------------- 灯光
func _build_lights() -> void:
    # 顶灯
    _box(Vector3(0.55, 3.02, -1.10), Vector3(1.55, 0.045, 0.14), _emit(Color(0.62, 0.80, 0.90), 0.7))
    _box(Vector3(0.55, 3.09, -1.10), Vector3(1.70, 0.03, 0.20), _plain(Color(0.09, 0.11, 0.12), 0.7))
    var top := OmniLight3D.new()
    top.position = Vector3(0.55, 2.86, -1.10)
    top.light_color = Color(0.58, 0.76, 0.88)
    top.light_energy = 1.05
    top.omni_range = 7.5
    top.omni_attenuation = 1.15
    top.shadow_enabled = true
    top.shadow_opacity = 0.55
    top.shadow_blur = 2.2
    top.light_volumetric_fog_energy = 1.0
    scene.add_child(top)
    # 台灯暖光
    var desk := OmniLight3D.new()
    desk.position = Vector3(1.72, 1.17, 0.24)
    desk.light_color = Color(1.0, 0.64, 0.32)
    desk.light_energy = 1.25
    desk.omni_range = 3.1
    desk.omni_attenuation = 1.35
    desk.shadow_enabled = true
    desk.shadow_opacity = 0.40
    desk.shadow_blur = 1.6
    desk.light_volumetric_fog_energy = 0.55
    scene.add_child(desk)
    # 门缝冷光
    var door := SpotLight3D.new()
    door.look_at_from_position(Vector3(-3.72, 2.05, -2.05), Vector3(0.6, 0.35, -0.8), Vector3.UP)
    door.light_color = Color(0.62, 0.82, 0.92)
    door.light_energy = 2.8
    door.spot_range = 12.0
    door.spot_angle = 42.0
    door.spot_angle_attenuation = 1.35
    door.shadow_enabled = true
    door.shadow_opacity = 0.50
    door.light_volumetric_fog_energy = 1.9
    scene.add_child(door)
    # 右侧窗冷光
    var win := SpotLight3D.new()
    win.look_at_from_position(Vector3(3.85, 2.10, -1.15), Vector3(1.2, 0.55, -0.2), Vector3.UP)
    win.light_color = Color(0.38, 0.56, 0.70)
    win.light_energy = 1.25
    win.spot_range = 8.0
    win.spot_angle = 40.0
    win.spot_angle_attenuation = 1.5
    win.shadow_enabled = false
    win.light_volumetric_fog_energy = 0.9
    scene.add_child(win)
    # 桌面暖色反弹，提亮卷宗与纸面
    var bounce := OmniLight3D.new()
    bounce.position = Vector3(1.05, 1.02, 0.95)
    bounce.light_color = Color(1.0, 0.70, 0.44)
    bounce.light_energy = 0.38
    bounce.omni_range = 2.6
    bounce.shadow_enabled = false
    scene.add_child(bounce)
    # 正面极暗冷补光
    var fill := OmniLight3D.new()
    fill.position = Vector3(-0.4, 1.65, 2.4)
    fill.light_color = Color(0.32, 0.46, 0.58)
    fill.light_energy = 0.22
    fill.omni_range = 6.0
    fill.shadow_enabled = false
    scene.add_child(fill)

# ---------------------------------------------------------------- 尘埃
func _build_dust() -> void:
    var dust := GPUParticles3D.new()
    dust.amount = 26
    dust.lifetime = 14.0
    dust.preprocess = 12.0
    dust.visibility_aabb = AABB(Vector3(-4, 0, -5), Vector3(8, 3.2, 9))
    dust.position = Vector3(0.3, 1.5, -0.6)
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(3.6, 1.2, 3.2)
    pm.direction = Vector3(0, 1, 0)
    pm.spread = 180.0
    pm.initial_velocity_min = 0.004
    pm.initial_velocity_max = 0.025
    pm.gravity = Vector3(0, -0.0015, 0)
    pm.scale_min = 0.0012
    pm.scale_max = 0.0034
    pm.turbulence_enabled = true
    pm.turbulence_noise_strength = 0.07
    pm.turbulence_noise_scale = 1.3
    dust.process_material = pm
    var dq := QuadMesh.new()
    dq.size = Vector2(0.014, 0.014)
    var dm := StandardMaterial3D.new()
    dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
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
    dm.albedo_color = Color(1.0, 0.84, 0.62, 0.15)
    dm.vertex_color_use_as_albedo = true
    dq.material = dm
    dust.draw_pass_1 = dq
    scene.add_child(dust)

# ---------------------------------------------------------------- 环境与相机
func _build_camera() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.008, 0.012, 0.018)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.30, 0.40, 0.46)
    env.ambient_light_energy = 0.55
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.16
    env.glow_enabled = true
    env.glow_intensity = 0.45
    env.glow_bloom = 0.08
    env.glow_hdr_threshold = 1.05
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    env.ssao_enabled = true
    env.ssao_radius = 0.9
    env.ssao_intensity = 1.5
    env.ssao_power = 1.5
    env.ssao_detail = 0.6
    env.ssao_light_affect = 0.25
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.014
    env.volumetric_fog_albedo = Color(0.55, 0.67, 0.74)
    env.volumetric_fog_anisotropy = 0.38
    env.volumetric_fog_length = 42.0
    env.volumetric_fog_detail_spread = 1.1
    env.volumetric_fog_ambient_inject = 0.2
    env.volumetric_fog_gi_inject = 0.2
    env.fog_enabled = true
    env.fog_light_color = Color(0.05, 0.08, 0.10)
    env.fog_light_energy = 0.45
    env.fog_density = 0.010
    env.fog_sky_affect = 0.0
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.07
    env.adjustment_saturation = 0.93
    env.adjustment_brightness = 1.0
    var we := WorldEnvironment.new()
    we.environment = env
    scene.add_child(we)

    var cam := Camera3D.new()
    cam.name = "MenuCam"
    cam.fov = 44.0
    cam.near = 0.05
    cam.far = 60.0
    cam.look_at_from_position(Vector3(-1.35, 1.64, 4.75), Vector3(0.82, 0.88, -0.05), Vector3.UP)
    var attrs := CameraAttributesPractical.new()
    attrs.dof_blur_far_enabled = true
    attrs.dof_blur_far_distance = 5.8
    attrs.dof_blur_far_transition = 3.2
    attrs.dof_blur_amount = 0.06
    cam.attributes = attrs
    cam.current = true
    scene.add_child(cam)

# ---------------------------------------------------------------- 后期
func _build_post() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    root.add_child(layer)
    var rect := ColorRect.new()
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(rect)
    var sh := Shader.new()
    sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.50;
uniform float grain_amount = 0.022;
void fragment(){
    vec2 uv = SCREEN_UV;
    vec2 c = uv - 0.5;
    float ca = 0.0010;
    vec3 col;
    col.r = texture(screen_tex, uv + c * ca * 2.0).r;
    col.g = texture(screen_tex, uv).g;
    col.b = texture(screen_tex, uv - c * ca * 2.0).b;
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col *= mix(vec3(0.88, 0.96, 1.02), vec3(1.04, 1.00, 0.94), smoothstep(0.10, 0.75, l));
    float d = length(c) * 1.34;
    col *= 1.0 - vignette_strength * smoothstep(0.24, 0.96, d);
    float n = fract(sin(dot(uv * vec2(1600.0, 900.0), vec2(12.9898, 78.233))) * 43758.5453);
    col += (n - 0.5) * grain_amount;
    COLOR = vec4(col, 1.0);
}
"""
    var sm := ShaderMaterial.new()
    sm.shader = sh
    rect.material = sm







