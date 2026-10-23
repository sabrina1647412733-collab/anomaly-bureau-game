extends Node3D
## 导入 Three.js 街道模块，沿用原地点 ID 与坐标；门口接回第一案。

const ORIGIN := Vector3(650.0, 0.0, 760.0)
const MODULES := [
	"res://assets/town/回潮镇_01_地面道路河道.glb",
	"res://assets/town/回潮镇_02_普通民居.glb",
	"res://assets/town/回潮镇_03_重点地标.glb",
	"res://assets/town/回潮镇_04_街具植被电力.glb",
]

var game: Node3D
var layout: Dictionary = {}
var floor_body: StaticBody3D
var map_layer: CanvasLayer
var town_map: Control
var active := false
var imported := false
var renewal
var hero
var weather
var residents
var indoor_camera_attributes:CameraAttributes
var outdoor_camera_attributes:CameraAttributesPractical
var indoor_fx:Dictionary={}

func setup(owner_game: Node3D, font: Font) -> void:
	game = owner_game
	name = "HuichaoTown"
	owner_game.add_child(self)
	position = ORIGIN
	visible = false
	var file := FileAccess.open("res://assets/town/town-layout.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			layout = parsed
	var additions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town/renewal/layout_additions.json"))
	if additions is Dictionary:
		layout["buildings"].append_array(additions.get("infill",[]))
	# The shop is on F2, with the existing investigation floors above it.
	for landmark in layout.get("landmarks",[]):
		if String(landmark.get("id",""))=="01":landmark["height"]=15.8;landmark["floors"]=5
	weather=preload("res://scripts/town/street_weather.gd").new()
	weather.setup(self)
	map_layer = CanvasLayer.new()
	map_layer.layer = 4
	owner_game.add_child(map_layer)
	town_map = preload("res://scripts/town/town_map.gd").new()
	map_layer.add_child(town_map)
	town_map.setup(layout, font)

func _build_once() -> void:
	if imported:
		return
	imported = true
	var finish=preload("res://scripts/town/town_finish.gd").new()
	for resource_path in [MODULES[2]]:
		var packed: PackedScene = load(resource_path)
		if packed == null:
			push_error("回潮镇模块缺失：" + resource_path)
			continue
		var part: Node3D = packed.instantiate()
		add_child(part)
		_hide_replaced_landmarks(part)
		finish.apply(part)
	floor_body = StaticBody3D.new()
	floor_body.name = "TownCollision"
	add_child(floor_body)
	renewal=preload("res://scripts/town/street_world.gd").new()
	renewal.setup(self)
	hero = preload("res://scripts/town/street_hero.gd").new()
	hero.setup(self)
	for entry in layout.get("buildings", []):
		var h := float(entry.get("height", 7.0))
		var recess: Dictionary = {}
		for frontage in renewal.manifest.get("shop_recesses", []):
			if int(entry.get("seed", -1)) == int(frontage.seed):
				recess = frontage
				break
		if not recess.is_empty():
			# Use the same opening dimensions as the exported Blender geometry.
			var yaw := float(entry.get("rot", 0.0))
			var front_axis := Vector3(sin(yaw), 0, cos(yaw))
			var side_axis := Vector3(cos(yaw), 0, -sin(yaw))
			var center := Vector3(float(entry.x), h*0.5, float(entry.z))
			var depth := float(recess.depth)
			var opening := float(recess.opening)
			var width := float(entry.w)
			var length := float(entry.d)
			_box(center-front_axis*depth*0.5, Vector3(width, h, length-depth), yaw)
			for sign_value in [-1.,1.]:
				var pier: Vector3 = center+front_axis*(length-depth)*0.5+side_axis*float(sign_value)*(width+opening)*0.25
				_box(pier, Vector3((width-opening)*0.5, h, depth), yaw)
			var lintel := Vector3(float(entry.x), (h+2.3)*0.5, float(entry.z))+front_axis*(length*0.5-0.10)
			_box(lintel, Vector3(opening, h-2.3, 0.20), yaw)
			continue
		_box(Vector3(float(entry["x"]), h * 0.5, float(entry["z"])), Vector3(float(entry["w"]), h, float(entry["d"])), float(entry.get("rot", 0.0)))
	for entry in layout.get("landmarks", []):
		if String(entry.get("id", "")) in ["04","08","10"]:
			continue # 公交站、雨巷和铁路道口不是封闭房屋
		var h := float(entry.get("height", 7.0))
		_box(Vector3(float(entry["x"]), h * 0.5, float(entry["z"])), Vector3(float(entry.get("w", 5.0)), h, float(entry.get("d", 5.0))), float(entry.get("rot", 0.0)))
	# GLB10's footprint includes the open deck. Only its actual guard hut is solid.
	_box(Vector3(80.005,1.4,8.795),Vector3(2.803,2.8,3.203),.0008)
	for post in [[84.0015,1.2,20.598,.109,2.4,.114],[89.896,1.7,19.603,.1,3.4,.1],
		[89.904,1.7,10.403,.1,3.4,.1],[88.996,1.8,19.602,.24,3.6,.208],[89.004,1.8,10.402,.24,3.6,.208]]:
		_box(Vector3(post[0],post[1],post[2]),Vector3(post[3],post[4],post[5]),0.)
	for z in [10.405,19.605]:_box(Vector3(91.75,3.3,z),Vector3(5.3,.16,.17),0.)
	for wall in layout.get("walls", []):
		var a: Array = wall.get("a", [])
		var b: Array = wall.get("b", [])
		if a.size() < 2 or b.size() < 2:
			continue
		var pa := Vector2(float(a[0]), float(a[a.size()-1]))
		var pb := Vector2(float(b[0]), float(b[b.size()-1]))
		var v := pb - pa
		var h := float(wall.get("h", 2.0))
		_box(Vector3((pa.x + pb.x) * 0.5, h * 0.5, (pa.y + pb.y) * 0.5), Vector3(0.18, h, v.length()), atan2(v.x, v.y))
	residents = preload("res://scripts/town/street_residents.gd").new()
	residents.setup(self)
	print("[TOWN] 模块导入完成；地点 ", layout.get("landmarks", []).size(), "，建筑 ", layout.get("buildings", []).size())

func _hide_replaced_landmarks(node:Node)->void:
	if String(node.name).begins_with("01") or String(node.name).begins_with("02"):
		if node is Node3D:node.visible=false
		return
	for child in node.get_children():_hide_replaced_landmarks(child)

func _box(at: Vector3, extent: Vector3, yaw: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = extent
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.position = at
	holder.rotation.y = yaw
	floor_body.add_child(holder)

func enter(from_laundry := false) -> void:
	_build_once()
	active = true
	visible = true
	floor_body.collision_layer = 1
	town_map.visible = true
	town_map.first_hint = not from_laundry
	for stage in game.prologue_roots.keys():
		game.prologue_roots[stage].visible = false
	game.prologue_stage = "town"
	game.state = "prologue"
	var apartment := _landmark("02")
	var front: Array = apartment.get("front", [169.88, 99.96])
	if from_laundry:
		var shop := _landmark("01")
		var shop_front: Array = shop.get("front", [145.88, 120.8])
		var away := Vector2(float(shop_front[0]) - float(shop.get("x", 145.52)), float(shop_front[1]) - float(shop.get("z", 111.31))).normalized()
		game.player.global_position = ORIGIN + Vector3(float(shop_front[0]) + away.x * 2.2, 0.12, float(shop_front[1]) + away.y * 2.2)
	else:
		game.player.global_position = ORIGIN + Vector3(float(front[0]) - 2.0, 0.12, float(front[1]))
	game.player.velocity = Vector3.ZERO
	var laundry := _landmark("01")
	var dest: Array = laundry.get("front", [145.88, 120.8])
	game.player.look_at(ORIGIN + Vector3(float(dest[0]), 0.12, float(dest[1])), Vector3.UP)
	game.player.can_move = true
	weather.activate()
	_outdoor_view(true)
	game.player.allow_capture = true
	game.player.body.visible = game.player.cam_mode!=0
	if from_laundry:
		game._prologue_set_objective("夜班还没结束。可返回洗衣店继续调查，或沿街回出租公寓。M 地图。")
		game._say_seq("旁白", "你推开门回到老街。店里的钟仍在走。")
	else:
		game._prologue_set_objective("沿街前往得利洗衣店。M 地图 · V 切视角 · E 开门；23:40 报到。")
		game._say_seq("旁白", "雨还在下。出租公寓的灯亮在身后，洗衣店在老街那头。")
	update_map()
	residents.activate()

func leave() -> void:
	if residents != null:residents.deactivate()
	weather.deactivate()
	_outdoor_view(false)
	active = false
	visible = false
	if floor_body != null:
		floor_body.collision_layer = 0
	if town_map != null:
		town_map.visible = false
		town_map.big_open = false

func _outdoor_view(on:bool)->void:
	# Indoor 8-metre DOF made the street unreadably blurred. Preserve that profile
	# and use the player's natural outdoor depth of field until leaving the town.
	var fx=game.get_meta("prologue_fx_mat",null)
	if on and outdoor_camera_attributes==null:
		indoor_camera_attributes=game.player.cam.attributes
		outdoor_camera_attributes=CameraAttributesPractical.new()
		game.player.cam.attributes=outdoor_camera_attributes
		if fx!=null:
			for key in ["vignette_strength","grain_amount","chromatic_amount"]:indoor_fx[key]=fx.get_shader_parameter(key)
			fx.set_shader_parameter("vignette_strength",.18);fx.set_shader_parameter("grain_amount",.006)
			fx.set_shader_parameter("chromatic_amount",.00015)
	elif not on and outdoor_camera_attributes!=null:
		if is_instance_valid(game.player) and game.player.cam.attributes==outdoor_camera_attributes:
			game.player.cam.attributes=indoor_camera_attributes
		if fx!=null:
			for key in indoor_fx:fx.set_shader_parameter(key,indoor_fx[key])
		outdoor_camera_attributes=null;indoor_camera_attributes=null;indoor_fx.clear()

func update_map() -> void:
	if active and town_map != null:
		town_map.set_player_position(game.player.global_position - ORIGIN)
		var target := "01"
		if game.laundry != null and game.laundry.campaign != null and bool(game.laundry.campaign.progress.rest_pending): target = "02"
		town_map.set_navigation(game.player.rotation.y,target)

func toggle_map() -> void:
	if active:
		town_map.toggle_big()

func interaction_hint() -> Dictionary:
	if not active:
		return {}
	var local: Vector3 = game.player.global_position - ORIGIN
	for entry in layout.get("landmarks", []):
		var front: Array = entry.get("front", [entry.get("x", 0.0), entry.get("z", 0.0)])
		var dist := Vector2(local.x, local.z).distance_to(Vector2(float(front[0]), float(front[1])))
		if dist < 3.3:
			var id := String(entry.get("id", ""))
			var label := "进入得利洗衣店" if id == "01" else ("回出租屋" if id == "02" else "查看" + String(entry.get("name", "地点")))
			return {"kind": "town", "id": id, "text": label, "pos": ORIGIN + Vector3(float(front[0]), 1.0, float(front[1]))}
	return {}

func interact(id: String) -> void:
	if residents != null and residents.interact(id):return
	match id:
		"01":
			game._leave_room_to_laundry()
		"02":
			leave()
			game._show_prologue_stage("room")
			if game.laundry != null and game.laundry.campaign != null and bool(game.laundry.campaign.progress.rest_pending):
				game._prologue_set_objective("夜班已结束。到床边按E，休息至下一班。")
			else:
				game._prologue_set_objective("从房门出发，23:40 到得利洗衣店值夜班。")
		_:
			var entry := _landmark(id)
			if not entry.is_empty():
				game._say_seq(String(entry.get("name", "地点")), String(entry.get("note", "这里还没有可进入的室内。")))

func _landmark(id: String) -> Dictionary:
	for entry in layout.get("landmarks", []):
		if String(entry.get("id", "")) == id:
			return entry
	return {}
