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
	for resource_path in MODULES:
		var packed: PackedScene = load(resource_path)
		if packed == null:
			push_error("回潮镇模块缺失：" + resource_path)
			continue
		var part: Node3D = packed.instantiate()
		add_child(part)
		finish.apply(part)
	floor_body = StaticBody3D.new()
	floor_body.name = "TownCollision"
	add_child(floor_body)
	_box(Vector3(150.0, -0.22, 120.0), Vector3(330.0, 0.44, 270.0), 0.0)
	for entry in layout.get("buildings", []):
		var h := float(entry.get("height", 7.0))
		_box(Vector3(float(entry["x"]), h * 0.5, float(entry["z"])), Vector3(float(entry["w"]), h, float(entry["d"])), float(entry.get("rot", 0.0)))
	for entry in layout.get("landmarks", []):
		if String(entry.get("id", "")) == "04" or String(entry.get("id", "")) == "08":
			continue # 公交站与雨巷不是封闭房屋
		var h := float(entry.get("height", 7.0))
		_box(Vector3(float(entry["x"]), h * 0.5, float(entry["z"])), Vector3(float(entry.get("w", 5.0)), h, float(entry.get("d", 5.0))), float(entry.get("rot", 0.0)))
	for wall in layout.get("walls", []):
		var a: Array = wall.get("a", [])
		var b: Array = wall.get("b", [])
		if a.size() < 3 or b.size() < 3:
			continue
		var pa := Vector2(float(a[0]), float(a[2]))
		var pb := Vector2(float(b[0]), float(b[2]))
		var v := pb - pa
		var h := float(wall.get("h", 2.0))
		_box(Vector3((pa.x + pb.x) * 0.5, h * 0.5, (pa.y + pb.y) * 0.5), Vector3(0.18, h, v.length()), atan2(v.x, v.y))
	var moon := DirectionalLight3D.new()
	moon.name = "TownMoon"
	moon.rotation_degrees = Vector3(-47, -32, 0)
	moon.light_color = Color(0.48, 0.62, 0.72)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)
	var lamp := OmniLight3D.new()
	lamp.name = "LaundryApproachLamp"
	lamp.position = Vector3(145.88, 4.0, 123.4)
	lamp.light_color = Color(0.96, 0.70, 0.38)
	lamp.light_energy = 2.1
	lamp.omni_range = 13.0
	add_child(lamp)
	finish.lights(self)
	print("[TOWN] 模块导入完成；地点 ", layout.get("landmarks", []).size(), "，建筑 ", layout.get("buildings", []).size())

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
	game.player.cam_mode = 1
	game.player.can_move = true
	game.player.allow_capture = true
	game.player.body.visible = true
	if from_laundry:
		game._prologue_set_objective("夜班还没结束。可返回洗衣店继续调查，或沿街回出租公寓。M 地图。")
		game._say_seq("旁白", "你推开门回到老街。店里的钟仍在走。")
	else:
		game._prologue_set_objective("沿街前往得利洗衣店。M 地图 · V 切视角 · E 开门；23:40 报到。")
		game._say_seq("旁白", "雨还在下。出租公寓的灯亮在身后，洗衣店在老街那头。")
	update_map()

func leave() -> void:
	active = false
	visible = false
	if floor_body != null:
		floor_body.collision_layer = 0
	if town_map != null:
		town_map.visible = false
		town_map.big_open = false

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
