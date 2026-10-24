extends Node3D
## 槐安住宅：同一份manifest驱动可见结构、真实碰撞和剧情锚点。
## 未建户内的普通楼层仅有封闭候梯厅/楼梯；不宣称完成十七层全户室内。
const BASE := "res://assets/models/case2/"
const ORIGIN := Vector3(1200, 0, 0)
const STORY_FLOORS := [1, 8, 16, 17]
var game
var manifest: Dictionary = {}
var refs: Dictionary = {"doors":{}, "lights":{}, "valves":{}}
var models: Dictionary = {}
var anomaly_open := false
var resolved := false
var preview_whitebox := false
var _spots: Array[Dictionary] = []
var _materials: Dictionary = {}
var _gate_shape: CollisionShape3D
var _gate: Node3D
var _minute := 0.0
var actors: Dictionary = {}
var _campaign_progress: Dictionary = {}
var _actor_floor := 1

class Case2Actor extends Node3D:
	var performance = null
	var model: Node3D
	var ap: AnimationPlayer
	func face_point(at: Vector3) -> void:
		var d := at - global_position
		d.y = 0
		if d.length_squared() > .01:
			rotation.y = atan2(d.x, d.z)

func setup(owner_game) -> void:
	game = owner_game
	name = "Case2_HuaianResidence"
	position = ORIGIN
	manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE + "huaian_manifest.json"))
	if manifest.is_empty():
		push_error("槐安住宅manifest缺失，拒绝创建无碰撞场景。")
		return
	_build_collision()
	_build_models()
	_build_anchors()
	_build_gate()
	_build_lights()
	_build_signage()
	if not preview_whitebox:
		_build_actors()

func _v(data: Array) -> Vector3:
	return Vector3(float(data[0]), float(data[1]), float(data[2]))

func _build_collision() -> void:
	for row in manifest.boxes:
		var body := StaticBody3D.new()
		body.name = "Collision_" + String(row.name)
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _v(row.s)
		shape.shape = box
		body.position = _v(row.p)
		body.add_child(shape)
		add_child(body)
	for row in manifest.ramps:
		var vertices := PackedVector3Array()
		for offset in [0.0, -0.22]:
			for p in [[row.x0, row.y0 + offset, row.z0], [row.x1, row.y0 + offset, row.z0], [row.x0, row.y1 + offset, row.z1], [row.x1, row.y1 + offset, row.z1]]:
				vertices.append(_v(p))
		var body := StaticBody3D.new()
		body.name = "Collision_" + String(row.name)
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = vertices
		shape.shape = convex
		body.add_child(shape)
		add_child(body)

func _build_models() -> void:
	for module in manifest.modules:
		var finish_path := BASE + String(module) + "_finish.glb"
		var white_path := BASE + String(module) + "_whitebox.glb"
		var asset: String = finish_path if ResourceLoader.exists(finish_path) and not preview_whitebox else white_path
		if not ResourceLoader.exists(asset):
			push_warning("槐安白模尚未导入：" + asset)
			continue
		var model: Node3D = load(asset).instantiate()
		model.name = "Building_" + String(module)
		add_child(model)
		models[module] = model
		if asset == finish_path:
			_dress(model)

func _material(id: String) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var material := StandardMaterial3D.new()
	var surface := ""
	match id:
		"wall": surface = "painted_plaster_wall"
		"ceiling": surface = "painted_plaster_wall"
		"tile": surface = "terrazzo_tiles"
		"stair": surface = "concrete_floor"
		"wood": surface = "oak_wood_planks"
		"cloth": surface = "rough_linen"
		"rust": surface = "rusty_metal"
		"patch": surface = "damaged_plaster"
		"paint": surface = "painted_plaster_wall"
	if surface != "":
		material.albedo_texture = load("res://assets/textures/" + surface + "/albedo.jpg")
		material.roughness_texture = load("res://assets/textures/" + surface + "/rough.jpg")
		material.normal_enabled = true
		material.normal_texture = load("res://assets/textures/" + surface + "/normal.jpg")
		material.normal_scale = 0.32 if id in ["wall", "ceiling"] else 0.55
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.uv1_scale = Vector3(0.70, 0.70, 1) if id in ["wall", "ceiling"] else Vector3(.5,.5,1) if id=="tile" else Vector3.ONE
	material.roughness = 0.87
	match id:
		"wall": material.albedo_color = Color("c0c2b1")
		"ceiling": material.albedo_color = Color("d3d0be")
		"tile": material.albedo_color = Color("a8b4a7")
		"metal": material.albedo_color = Color("718378"); material.metallic = .22; material.roughness = .62
		"paint": material.albedo_color = Color("718474"); material.roughness = .78
		"wood": material.albedo_color = Color("b1a087")
		"cloth": material.albedo_color = Color("a9afa0")
		"steel": material.albedo_color = Color("879b94"); material.metallic = 0.78; material.roughness = 0.37
		"paper": material.albedo_color = Color("c9bfa3")
		"glass": material.albedo_color = Color(.58,.68,.65,.12); material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.roughness = 0.18
		"rubber": material.albedo_color = Color("202d27")
		"light": material.albedo_color = Color("c1d3c9"); material.emission_enabled = true; material.emission = Color("a0b6a9"); material.emission_energy_multiplier = 1.5
		"rust": material.albedo_color = Color("a79879")
		"patch": material.albedo_color = Color("b6b9aa")
		"red": material.albedo_color = Color("713b2b")
	_materials[id] = material
	return material

func _dress(node: Node) -> void:
	if node is MeshInstance3D:
		var key := String(node.name).get_slice("C2_", 1)
		if key != "":
			node.material_override = _material(key)
	for child in node.get_children():
		_dress(child)

func _build_anchors() -> void:
	for id in manifest.anchors:
		var row: Dictionary = manifest.anchors[id]
		var anchor := Marker3D.new()
		anchor.name = String(id)
		anchor.position = _v(row.pos)
		add_child(anchor)
		_spots.append({"id":String(id), "name":String(row.text), "text":String(row.text), "pos":to_global(_v(row.pos)), "r":float(row.r), "floor":int(row.floor), "approach":to_global(_v(row.approach))})

func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.name = "AnomalyLandingDoor"
	_gate.position = Vector3(1.79, 48, 3.67)
	add_child(_gate)
	var mesh := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(.075, 2.2, 1.60)
	mesh.mesh = door_mesh
	mesh.position = Vector3(0, 1.1, .8)
	mesh.material_override = _material("metal")
	_gate.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_gate_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = door_mesh.size
	_gate_shape.shape = shape
	_gate_shape.position = mesh.position
	body.add_child(_gate_shape)
	_gate.add_child(body)
	refs.doors.anomaly = _gate
	var valve := Node3D.new()
	valve.name = "BranchValveWheel"
	valve.position = Vector3(1.35, 49.4, -3.65)
	valve.rotation.z = PI / 2
	add_child(valve)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .102
	torus.outer_radius = .128
	torus.rings = 24
	torus.ring_segments = 8
	rim.mesh = torus
	rim.material_override = _material("red")
	valve.add_child(rim)
	for angle in [0.0, PI / 2]:
		var spoke := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(.20, .018, .018)
		spoke.mesh = bar
		spoke.rotation.y = angle
		spoke.material_override = _material("red")
		valve.add_child(spoke)
	refs.valves.branch = valve

func _build_lights() -> void:
	for floor in range(1, 18):
		var y := float(floor - 1) * 3
		for p in [Vector3(0, y + 2.4, -3.8), Vector3(0, y + 2.4, 3.5), Vector3(4, y + 2.25, 1.2)]:
			var lamp := OmniLight3D.new()
			lamp.position = p
			lamp.light_color = Color("c6d8cc") if floor != 17 else Color("94ada6")
			lamp.light_energy = .75 if floor in STORY_FLOORS else .42
			lamp.omni_range = 4.8
			lamp.omni_attenuation = 1.55
			lamp.shadow_enabled = false
			add_child(lamp)
			refs.lights["%d_%s" % [floor, str(p.z)]] = lamp
		if floor in STORY_FLOORS:
			for z in [-3.7, .5]:
				var lamp := OmniLight3D.new()
				lamp.position = Vector3(-4, y + 2.3, z)
				lamp.light_color = Color("e4d3ab") if floor in [1, 8] else Color("bbcdbf")
				lamp.light_energy = .90
				lamp.omni_range = 5.0
				lamp.shadow_enabled = true
				lamp.shadow_bias = .04
				lamp.shadow_normal_bias = .5
				add_child(lamp)
				refs.lights["room_%d_%s" % [floor, str(z)]] = lamp
	var rest_lamp := OmniLight3D.new()
	rest_lamp.position = Vector3(-5.3, 49.15, -3.8)
	rest_lamp.light_color = Color("efc184")
	rest_lamp.light_energy = .18
	rest_lamp.omni_range = 2.1
	add_child(rest_lamp)
	refs.lights.rest = rest_lamp

func _label(text: String, p: Vector3, size: float, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = p
	label.pixel_size = size / 32.0
	label.font_size = 32
	label.modulate = Color("e2d9bf")
	label.outline_size = 2
	label.rotation.y = yaw
	label.no_depth_test = false
	label.double_sided = false
	add_child(label)
	return label

func _build_signage() -> void:
	for floor in range(1, 18):
		var y := float(floor - 1) * 3
		_label("%dF\n公共楼梯 / 电梯 ←" % floor, Vector3(1.67, y + 1.65, 5.53), .13, -PI / 2)
		_label("1   8   16" if floor != 17 else "17", Vector3(-2.00, y + 1.58, 4.1), .055, PI / 2)
	_label("槐安住宅\n值守处", Vector3(-4.85, .67, .301), .12, PI)
	_label("建筑登记\n十六层", Vector3(-4.45, 1.47, -6.228), .055)
	_label("总表 — 住户分表\n额外支路待核对", Vector3(-3.15, 1.47, -6.228), .047)
	refs["meter_faces"] = []
	for z in [-3.92, -3.5, -3.08]:
		var face := _label("00053\n10-24", Vector3(-5.592, 1.37, z), .021, PI / 2)
		face.modulate = Color("273a32")
		refs.meter_faces.append(face)
	_label("派遣资料", Vector3(-2.6, 1.32, -4.389), .035)
	_label("照护日历\n○ ○ ○ ○ ○", Vector3(-4.7, 22.5, -6.228), .055)
	_label("我去给九楼送药\n粥在锅里", Vector3(-3.4, 22.4, -6.228), .035)
	_label("公共储物间\n附属用房不作住所登记", Vector3(-2.01, 46.70, -1.76), .045, PI / 2)
	var wage := _label("早期工资单\n署名折在背面", Vector3(-3.1, 45.803, -4.43), .025)
	wage.rotation.x = -PI / 2
	_label("照护与清洁排班\n9F药 → 8F饭 → 6F床单", Vector3(-3.5, 46.45, 2.188), .045, PI)
	_label("退回 · 住院单", Vector3(-4.4, 46.4, -6.228), .043)
	for z in [-4.7, -2.5, -.3, 1.9]:
		_label("共用", Vector3(-1.72, 49.7, z), .06, PI / 2)
	_label("旧门牌", Vector3(-5.85, 49.35, -4.8), .045, PI / 2)

func get_spots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spot in _spots:
		var row := _anchor_row(String(spot.id))
		var copy: Dictionary = spot.duplicate(true)
		copy.pos = to_global(_v(row.pos))
		copy.approach = to_global(_v(row.approach))
		copy.floor = int(row.floor)
		result.append(copy)
	return result

func spots() -> Array[Dictionary]:
	return get_spots()

func get_anchor(id: String) -> Vector3:
	if manifest.anchors.has(id):
		return to_global(_v(_anchor_row(id).pos))
	return get_floor_spawn(1)

func _anchor_row(id: String) -> Dictionary:
	var row: Dictionary = manifest.anchors.get(id, {}).duplicate(true)
	if id == "c2_aqi" and actors.has("aqi"):
		var p: Vector3 = to_local(actors.aqi.global_position)
		row.pos = [p.x, p.y+1.20, p.z]
		row.approach = [0, p.y+.05, p.z]
		row.floor = _actor_floor
	elif id == "c2_hebo" and _actor_floor == 8:
		row.pos = [-4.8,22.2,1.15]
		row.approach = [-3.95,21.05,1.45]
		row.floor = 8
	return row

func get_floor_spawn(floor: int) -> Vector3:
	return to_global(Vector3(-.25, float(clampi(floor, 1, 17) - 1) * 3 + .05, 4.4))

func get_actor_anchor(id: String, floor := 1) -> Vector3:
	var y := float(clampi(floor, 1, 17) - 1) * 3
	match id:
		"aqi": return to_global(Vector3(.90, y, -2.2 if floor == 1 else 1.2))
		"hebo": return to_global(Vector3(-4.25, 0, .1))
		"sun": return to_global(Vector3(-.65, 48, -5.4))
	return get_floor_spawn(floor)

func get_route(id: String, player_position: Vector3) -> Array[Vector3]:
	if not manifest.anchors.has(id):
		return []
	var row: Dictionary = _anchor_row(id)
	var p := to_local(player_position)
	var floor := clampi(int(round(p.y / 3)) + 1, 1, 17)
	var target_floor := int(row.floor)
	var route: Array[Vector3] = []
	var room_lane := -3.60 if target_floor == 1 else -4.12 if target_floor == 16 else -3.50 if target_floor == 17 else -3.85
	# Always leave a room through the real opening at z=-1 before changing floor.
	var at := _v(row.approach)
	var same_room := floor == target_floor and p.x < -2.0 and p.z < 3.1 and at.x < -2.0 and at.z < 3.1
	if p.x < -2.0 and p.z < 3.1 and not same_room:
		var exit_lane := -3.60 if floor == 1 else -4.12 if floor == 16 else -3.50 if floor == 17 else -3.85
		route.append(Vector3(exit_lane, p.y, p.z))
		route.append(Vector3(exit_lane, p.y, -1))
		route.append(Vector3(-.20, p.y, -1))
	elif p.x < -2.0 and not same_room:
		route.append(Vector3(-.20, p.y, 4.45))
	if floor != target_floor:
		route.append(Vector3(.15, (floor - 1) * 3 + .05, 4.55))
		while floor < target_floor:
			var y := float(floor - 1) * 3
			route.append(Vector3(2.85, y + .05, 4.55))
			route.append(Vector3(2.85, y + .05, 3.58))
			route.append(Vector3(2.85, y + 1.55, .12))
			route.append(Vector3(4.85, y + 1.55, .12))
			route.append(Vector3(4.85, y + 3.05, 3.65))
			route.append(Vector3(4.85, y + 3.05, 4.55))
			floor += 1
		while floor > target_floor:
			var y := float(floor - 2) * 3
			route.append(Vector3(4.85, y + 3.05, 4.55))
			route.append(Vector3(4.85, y + 3.05, 3.58))
			route.append(Vector3(4.85, y + 1.55, .12))
			route.append(Vector3(2.85, y + 1.55, .12))
			route.append(Vector3(2.85, y + .05, 3.65))
			route.append(Vector3(2.85, y + .05, 4.55))
			floor -= 1
		route.append(Vector3(.10, (target_floor - 1) * 3 + .05, 4.55))
	if at.x < -2.0 and at.z < 3.1:
		if not same_room:
			route.append(Vector3(-.20, at.y, -1))
			route.append(Vector3(room_lane, at.y, -1))
		else:
			route.append(Vector3(room_lane, at.y, p.z))
		# Centre lane keeps the stored bed/cabinet out of mandatory circulation.
		route.append(Vector3(room_lane, at.y, at.z))
	route.append(at)
	var result: Array[Vector3] = []
	for local in route:
		result.append(to_global(local))
	return result

func set_anomaly_open(value: bool) -> void:
	anomaly_open = value
	if _gate != null:
		_gate.rotation.y = -PI / 2 if value else 0.0
	if _gate_shape != null:
		_gate_shape.set_deferred("disabled", value)

func set_resolved(value: bool) -> void:
	resolved = value
	if refs.lights.has("rest"):
		refs.lights.rest.light_energy = .85 if value else .18
	for key in refs.lights:
		if String(key).begins_with("17_"):
			refs.lights[key].light_energy = .15 if value else .75
	if refs.valves.has("branch"):
		refs.valves.branch.rotation.y = PI / 2 if value else 0

func set_active(value: bool) -> void:
	visible = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	_active_collision(self, value)

func _active_collision(node: Node, value: bool) -> void:
	if node is StaticBody3D:
		node.collision_layer = 1 if value else 0
	for child in node.get_children():
		_active_collision(child, value)

func _build_actors() -> void:
	for entry in [["hebo","hebo.glb"],["sun","sun_suqin.glb"]]:
		var path := BASE+"characters/"+String(entry[1])
		if not ResourceLoader.exists(path):
			continue
		var actor := Case2Actor.new()
		actor.name = "Actor_"+String(entry[0])
		add_child(actor)
		actor.position = to_local(get_actor_anchor(String(entry[0])))
		actor.model = load(path).instantiate()
		actor.add_child(actor.model)
		actor.ap = actor.model.find_child("AnimationPlayer", true, false)
		if actor.ap != null:
			for clip in actor.ap.get_animation_list():
				if String(clip).to_lower().ends_with("idle"):
					actor.ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					actor.ap.play(clip)
					actor.ap.seek(0, true)
					break
		_add_actor_collision(actor, String(entry[0]), .24)
		actors[entry[0]] = actor
	if ResourceLoader.exists("res://assets/models/chars/Aqi_Anim.glb"):
		var aqi = preload("res://scripts/laundry/char_actor.gd").make(self, "aqi", Vector3(.90,0,-2.2), 0.0)
		if aqi != null:
			_add_actor_collision(aqi, "aqi", .22)
			actors.aqi = aqi
	refs.actors = actors
	_update_actor_floor(true)

func _add_actor_collision(actor: Node3D, id: String, radius: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ActorBody_"+id
	body.set_meta("case2_actor", id)
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = .775
	body.add_child(collision)
	actor.add_child(body)

func sync_campaign(progress: Dictionary) -> void:
	_campaign_progress = progress.duplicate(true)
	_update_actor_floor(true)
	var flags: Dictionary = progress.get("flags", {})
	if actors.has("sun"):
		actors.sun.visible = anomaly_open and not bool(flags.get("joint_signed", false))
		_actor_collision(actors.sun, actors.sun.visible)
	if refs.has("meter_faces"):
		var moved := bool(flags.get("meter_recorded", false))
		for face in refs.meter_faces:
			face.text = "00054\n11-11" if moved else "00053\n11-12"

func _actor_collision(actor: Node, value: bool) -> void:
	for child in actor.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1 if value else 0

func _update_actor_floor(force := false) -> void:
	var next_floor := _actor_floor
	if is_instance_valid(game) and is_instance_valid(game.player):
		var player_at: Vector3 = to_local(game.player.global_position)
		next_floor = clampi(int(round(player_at.y/3))+1, 1, 17)
	if next_floor == _actor_floor and not force:
		return
	_actor_floor = next_floor
	if actors.has("aqi"):
		var y := float(next_floor-1)*3
		actors.aqi.position = Vector3(.90,y,-2.2 if next_floor==1 else 1.2)
	if actors.has("hebo"):
		actors.hebo.position = Vector3(-4.8,21,1.15) if next_floor==8 else Vector3(-4.25,0,.1)
		actors.hebo.visible = next_floor in [1,8]
		_actor_collision(actors.hebo, actors.hebo.visible)
	for id in ["hebo","aqi","sun"]:
		if actors.has(id) and actors[id].visible and is_instance_valid(game):
			actors[id].face_point(game.player.global_position)

func get_speaker(who: String) -> Dictionary:
	var id := "aqi" if who=="阿七" else "hebo" if who=="何伯" else "sun" if who=="孙素琴" else ""
	if actors.has(id) and actors[id].visible:
		return {"at":actors[id].global_position+Vector3(0,1.28,0), "actor":actors[id]}
	# Remote intercom or phone speakers have no visible local mouth actor.
	return {"at":Vector3.INF, "actor":null}

func show_speaker(who: String) -> Dictionary:
	var data := get_speaker(who)
	if data.actor != null and is_instance_valid(game):
		data.actor.face_point(game.player.global_position)
	return data

func _process(_delta: float) -> void:
	_update_actor_floor()
