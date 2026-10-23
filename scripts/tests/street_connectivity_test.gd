extends SceneTree
## A physics-probed road graph for all ten landmarks; this is not a player walk.
## Actual keyboard/character routes are checked by street_renewal/normal_route.
const OUT := "F:/诡异事务局/验收/20261023_街道重构/"
const MINIMUM := Vector2i(-15, -15)
const SIZE := Vector2i(331, 271)
var game
var town
var passed := 0
var failed := 0
var candidates: Dictionary = {}
var open_points: Dictionary = {}
var blocked_points: Dictionary = {}
var grid := AStarGrid2D.new()
var shape_query := PhysicsShapeQueryParameters3D.new()
var ray_query := PhysicsRayQueryParameters3D.new()
var space: PhysicsDirectSpaceState3D
var report := {"kind": "physics-probed road graph; not full player walking", "landmarks": [], "bridges": [], "failures": []}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		report.failures.append(label)
		push_error("FAIL " + label)

func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func add_band(a: Vector2, b: Vector2, half_width: float) -> void:
	var low := Vector2i(floori(minf(a.x, b.x) - half_width), floori(minf(a.y, b.y) - half_width))
	var high := Vector2i(ceili(maxf(a.x, b.x) + half_width), ceili(maxf(a.y, b.y) + half_width))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var id := Vector2i(x, z)
			if not Rect2i(MINIMUM, SIZE).has_point(id):
				continue
			var sample := Vector2(x, z)
			if sample.distance_to(Geometry2D.get_closest_point_to_segment(sample, a, b)) <= half_width:
				candidates[id] = true

func add_front_access(entry: Dictionary) -> void:
	var front := point(entry.front)
	var nearest := front
	var best := INF
	for road in town.layout.roads:
		var points: Array = road.points
		for i in range(points.size() - 1):
			var on_road := Geometry2D.get_closest_point_to_segment(front, point(points[i]), point(points[i + 1]))
			var distance := front.distance_squared_to(on_road)
			if distance < best:
				best = distance
				nearest = on_road
	add_band(front, nearest, 1.4)
	add_band(front, front, 3.2)

func build_candidate_mask() -> void:
	for road in town.layout.roads:
		var points: Array = road.points
		for i in range(points.size() - 1):
			# Include the narrow pavement seam as legitimate walking space; the
			# capsule test, rather than this drawing mask, decides actual clearance.
			add_band(point(points[i]), point(points[i + 1]), float(road.width) * 0.5 + 0.25)
	for bridge in town.layout.bridges:
		add_band(point(bridge["from"]), point(bridge["to"]), float(bridge.width) * 0.5)
	for entry in town.layout.landmarks:
		add_front_access(entry)

func world_at(id: Vector2i, height: float) -> Vector3:
	return town.ORIGIN + Vector3(id.x, height, id.y)

func build_physics_graph() -> void:
	grid.region = Rect2i(MINIMUM, SIZE)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.fill_solid_region(grid.region, true)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.72
	shape_query.shape = capsule
	shape_query.collision_mask = 1
	shape_query.exclude = [game.player.get_rid()]
	ray_query.collision_mask = 1
	ray_query.exclude = [game.player.get_rid()]
	var counts := {"shape": 0, "unsupported": 0}
	for id in candidates:
		shape_query.transform = Transform3D(Basis.IDENTITY, world_at(id, 0.92))
		var hits := space.intersect_shape(shape_query, 1)
		if not hits.is_empty():
			counts.shape += 1
			var hit: Dictionary = hits[0]
			var owner_label := "unknown"
			if hit.collider is CollisionObject3D:
				var body: CollisionObject3D = hit.collider
				var holder := body.shape_owner_get_owner(body.shape_find_owner(int(hit.shape)))
				if holder is CollisionShape3D:
					owner_label = str(holder.position)
			blocked_points[id] = {"kind": "shape", "shape_at": owner_label}
			continue
		ray_query.from = world_at(id, 0.4)
		ray_query.to = world_at(id, -0.65)
		var floor_hit := space.intersect_ray(ray_query)
		if floor_hit.is_empty() or float(floor_hit.position.y) - town.ORIGIN.y < -0.18 or floor_hit.normal.y < 0.7:
			counts.unsupported += 1
			blocked_points[id] = {"kind": "unsupported"}
			continue
		open_points[id] = true
		grid.set_point_solid(id, false)
	report["candidate_points"] = candidates.size()
	report["walkable_points"] = open_points.size()
	report["blocked_points"] = counts
	print("GRAPH candidate=", candidates.size(), " open=", open_points.size(), " blocked=", counts)

func nearest_open(at: Vector2, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(floori(at.x - radius), ceili(at.x + radius) + 1):
		for z in range(floori(at.y - radius), ceili(at.y + radius) + 1):
			var id := Vector2i(x, z)
			if open_points.has(id) and Vector2(id).distance_to(at) <= radius:
				result.append(id)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(at) < Vector2(b).distance_squared_to(at))
	return result

func line_to_front(id: Vector2i, front: Vector2) -> bool:
	var from := world_at(id, 1.66)
	var target: Vector3 = town.ORIGIN + Vector3(front.x, 1.05, front.y)
	ray_query.from = from
	ray_query.to = target - (target - from).normalized() * 0.12
	return space.intersect_ray(ray_query).is_empty()

func classify_blocker(at: Vector2i) -> String:
	var sample := Vector2(at)
	for entry in town.layout.buildings:
		var angle := float(entry.get("rot", 0.0))
		var offset := sample - Vector2(float(entry.x), float(entry.z))
		var local := Vector2(offset.x * cos(angle) - offset.y * sin(angle), offset.x * sin(angle) + offset.y * cos(angle))
		if absf(local.x) < float(entry.w) * 0.5 + 0.45 and absf(local.y) < float(entry.d) * 0.5 + 0.45:
			return ("new_infill:" + String(entry.id)) if entry.has("id") and String(entry.id).begins_with("fill_") else "original_building"
	for wall in town.layout.walls:
		var a: Array = wall.a
		var b: Array = wall.b
		if sample.distance_to(Geometry2D.get_closest_point_to_segment(sample, Vector2(a[0], a[a.size() - 1]), Vector2(b[0], b[b.size() - 1]))) < 0.65:
			return "original_wall"
	for entry in town.layout.landmarks:
		var angle := float(entry.get("rot", 0.0))
		var offset := sample - Vector2(float(entry.x), float(entry.z))
		var local := Vector2(offset.x * cos(angle) - offset.y * sin(angle), offset.x * sin(angle) + offset.y * cos(angle))
		if absf(local.x) < float(entry.w) * 0.5 + 0.45 and absf(local.y) < float(entry.d) * 0.5 + 0.45:
			return "original_landmark:" + String(entry.id)
	return "prop_or_landmark_footprint"

func component(start: Vector2i) -> Dictionary:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var next: Vector2i = current + step
			if not open_points.has(next) or visited.has(next):
				continue
			if step.x != 0 and step.y != 0 and (not open_points.has(current + Vector2i(step.x, 0)) or not open_points.has(current + Vector2i(0, step.y))):
				continue
			visited[next] = true
			queue.append(next)
	return visited

func landmark_paths(start: Vector2i) -> void:
	var connected := component(start)
	report["apartment_component_points"] = connected.size()
	for entry in town.layout.landmarks:
		var front := point(entry.front)
		var goals := nearest_open(front, 3.2)
		var selected := Vector2i(-9999, -9999)
		var path: Array[Vector2i] = []
		for goal in goals:
			if not connected.has(goal) or not line_to_front(goal, front):
				continue
			path = grid.get_id_path(start, goal)
			if not path.is_empty():
				selected = goal
				break
		var data := {"id": String(entry.id), "name": String(entry.name), "reachable": not path.is_empty(), "path_points": path.size(), "standpoint": [selected.x, selected.y], "front_candidates": goals.size()}
		if path.is_empty():
			var other := component(goals[0]) if not goals.is_empty() else {}
			data["other_component_size"] = other.size()
			var near_blockers := []
			for x in range(floori(front.x - 6.0), ceili(front.x + 6.0)):
				for z in range(floori(front.y - 6.0), ceili(front.y + 6.0)):
					var id := Vector2i(x, z)
					if blocked_points.has(id):
						near_blockers.append({"point": [x, z], "cause": classify_blocker(id), "probe": blocked_points[id]})
			data["near_blockers"] = near_blockers
		report.landmarks.append(data)
		check(not path.is_empty(), "公寓道路图可达地标 " + String(entry.id) + " " + String(entry.name) + " 站位=" + str(selected) + " 路径点=" + str(path.size()))
		var console_data := data.duplicate()
		console_data.erase("near_blockers")
		print("LANDMARK ", JSON.stringify(console_data))
	for bridge in town.layout.bridges:
		var endpoints_a := nearest_open(point(bridge["from"]), 2.5)
		var endpoints_b := nearest_open(point(bridge["to"]), 2.5)
		var path: Array[Vector2i] = []
		if not endpoints_a.is_empty() and not endpoints_b.is_empty():
			path = grid.get_id_path(endpoints_a[0], endpoints_b[0])
		var data := {"id": String(bridge.id), "open": not path.is_empty(), "path_points": path.size(), "apartment_reaches_both_banks": not endpoints_a.is_empty() and not endpoints_b.is_empty() and connected.has(endpoints_a[0]) and connected.has(endpoints_b[0])}
		report.bridges.append(data)
		check(not path.is_empty(), "桥梁两岸道路图连通 " + String(bridge.id))
		print("BRIDGE ", JSON.stringify(data))

func save_map(start: Vector2i) -> void:
	var connected := component(start)
	var content := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-15 -15 331 271"><rect x="-15" y="-15" width="331" height="271" fill="#172126"/>'
	for id in candidates:
		var colour := "#994536" if blocked_points.has(id) else ("#90ba8c" if connected.has(id) else "#c59b59")
		content += '<rect x="%d" y="%d" width="1" height="1" fill="%s"/>' % [id.x, id.y, colour]
	for entry in town.layout.landmarks:
		var front := point(entry.front)
		content += '<circle cx="%f" cy="%f" r="2.5" fill="#d3cdb7"/><text x="%f" y="%f" font-size="5" fill="white">%s</text>' % [front.x, front.y, front.x + 3.5, front.y, String(entry.id)]
	content += '</svg>'
	var file := FileAccess.open(OUT + "street_connectivity_map.svg", FileAccess.WRITE)
	if file != null:
		file.store_string(content)

func run() -> void:
	var started := Time.get_ticks_msec()
	create_timer(180.0).timeout.connect(func(): push_error("street connectivity timeout"); quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game._clear_sub()
	town = game.town_bridge
	town.enter()
	game._clear_sub()
	game.audio_system.stop_voice()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.safety.set_physics_process(false)
	game.exit_save.set_process(false)
	town.weather.set_process(false)
	await physics_frame
	space = game.get_world_3d().direct_space_state
	build_candidate_mask()
	build_physics_graph()
	var starts := nearest_open(Vector2(game.player.global_position.x - town.ORIGIN.x, game.player.global_position.z - town.ORIGIN.z), 3.2)
	check(not starts.is_empty(), "公寓真实出生点附近存在道路图起点")
	if not starts.is_empty():
		report["start"] = [starts[0].x, starts[0].y]
		landmark_paths(starts[0])
		save_map(starts[0])
	report["passed"] = passed
	report["failed"] = failed
	report["elapsed_ms"] = Time.get_ticks_msec() - started
	var file := FileAccess.open(OUT + "street_connectivity_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("STREET CONNECTIVITY: ", passed, " passed, ", failed, " failed; graph only; elapsed_ms=", report.elapsed_ms)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
