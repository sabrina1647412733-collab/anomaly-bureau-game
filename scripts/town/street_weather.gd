extends Node3D
## Outdoor-only sky, light and roof-clipped rain. Director remains the sole game clock.
## No user:// writes, project globals, replacement audio player or screen-space effects.

const SKY_SHADER := preload("res://scripts/town/shaders/street_sky.gdshader")
const RAIN_SHADER := preload("res://scripts/town/shaders/street_rain.gdshader")
const ROOF_CELL := 16.0
const RAIN_CELL := 1.7
const RAIN_RADIUS := 6
const DROPS_PER_CELL := 8
const WEATHER_KEYS := [
	[0.0, 0.60, 0.88], [110.0, 0.82, 0.95], [220.0, 0.18, 0.80],
	[285.0, 0.0, 0.66], [420.0, 0.0, 0.42], [600.0, 0.0, 0.24],
	[780.0, 0.0, 0.30], [900.0, 0.67, 0.92], [1010.0, 0.12, 0.72],
	[1130.0, 0.0, 0.50], [1260.0, 0.18, 0.72], [1370.0, 0.60, 0.88],
	[1440.0, 0.60, 0.88],
]

var town: Node3D
var game: Node3D
var active := false
var rain_amount := 0.60
var wetness := 0.80
var cloud_cover := 0.88
var daylight := 0.0
var animation_time := 0.0
var last_clock := -1.0
var environment: Environment
var sun: DirectionalLight3D
var rain_node: MultiMeshInstance3D
var rain_material: ShaderMaterial
var sky_material: ShaderMaterial
var rain_floor_heights := PackedFloat32Array()
var sheltered := false
var _original_environment: Environment
var _disabled_directionals: Array[Dictionary] = []
var _roof_bins: Dictionary = {}
var _rain_origin := Vector2i(-99999, -99999)
var _light_update := 0.0
var _last_sky_clock := -99999.0
var _last_sky_second := -99999

func setup(owner_town: Node3D) -> void:
	town = owner_town
	game = town.game
	name = "StreetWeather"
	owner_town.add_child(self)
	visible = false
	_index_roofs()

func _exit_tree() -> void:
	deactivate()

func activate() -> void:
	if active:
		refresh(0.0)
		return
	active = true
	visible = true
	if game.env_node != null:
		_original_environment = game.env_node.environment
		environment = _original_environment.duplicate(true) if _original_environment != null else Environment.new()
		game.env_node.environment = environment
		_make_sky()
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "TownWeatherSunMoon"
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 90.0
		add_child(sun)
	# The original global moon is tiny but still leaks a blue fill into daytime.
	# Temporarily hide it; never mutate its saved colour/energy or indoor state.
	_disabled_directionals.clear()
	for child in game.get_children():
		if child is DirectionalLight3D:
			_disabled_directionals.append({"node": child, "visible": child.visible})
			child.visible = false
	if rain_node == null:
		_make_rain()
	_rain_origin = Vector2i(-99999, -99999)
	refresh(0.0)

func deactivate() -> void:
	if not active:
		return
	active = false
	visible = false
	# Only release our own environment. An indoor transition that already replaced
	# it must retain its newly assigned resource rather than be overwritten here.
	if is_instance_valid(game) and is_instance_valid(game.env_node) and game.env_node.environment == environment:
		game.env_node.environment = _original_environment
	for entry in _disabled_directionals:
		if is_instance_valid(entry.node):
			entry.node.visible = entry.visible
	_disabled_directionals.clear()
	_original_environment = null
	environment = null

func _process(delta: float) -> void:
	refresh(delta)

func _paused() -> bool:
	if not is_instance_valid(game) or get_tree().paused:
		return true
	if game.state == "case_cinematic":
		return false
	return game.state not in ["prologue", "play"] or game.phone_open or game.bag_open or game.nb_open or game.sub_pause or game.choice != null

func _absolute_clock() -> float:
	var minutes := 1390.0
	if game.director != null:
		minutes = float(game.director.now())
	var night := 1
	if game.laundry != null and game.laundry.campaign != null:
		night = int(game.laundry.campaign.night_number())
	return minutes + float(maxi(night - 1, 0)) * 1440.0

func profile_at(minutes: float) -> Dictionary:
	var minute := fposmod(minutes, 1440.0)
	# Change the day's weather strength at 05:00 (a dry part of the schedule),
	# keeping rain continuous across midnight during the night shift.
	var day := floori((minutes - 300.0) / 1440.0)
	var day_strength: float = [1.0, 0.36, 0.78, 1.12][posmod(day, 4)]
	var rain := 0.6
	var clouds := 0.88
	for i in range(WEATHER_KEYS.size() - 1):
		var a: Array = WEATHER_KEYS[i]
		var b: Array = WEATHER_KEYS[i + 1]
		if minute >= float(a[0]) and minute <= float(b[0]):
			var ratio := smoothstep(float(a[0]), float(b[0]), minute)
			rain = lerpf(float(a[1]), float(b[1]), ratio) * float(day_strength)
			clouds = lerpf(float(a[2]), float(b[2]), ratio)
			break
	# In this case the shift is handed over at 04:00: first light is deliberately
	# already visible then, rather than changing the story's handover time.
	var day_light := smoothstep(210.0, 325.0, minute) * (1.0 - smoothstep(1060.0, 1190.0, minute))
	return {"rain": clampf(rain, 0.0, 1.0), "clouds": clampf(clouds, 0.0, 1.0), "daylight": day_light}

func _integrate_wetness(from: float, to: float) -> void:
	# Five-minute analytic steps give the same sensible result for ordinary play,
	# clock jumps and the overnight rest without simulating every skipped frame.
	var cursor := maxf(from, to - 1440.0)
	if to - from > 1440.0:
		wetness = 0.3
	while cursor < to - 0.00001:
		var step := minf(5.0, to - cursor)
		var sample := profile_at(cursor + step * 0.5)
		var gain := float(sample.rain) * 0.038
		var loss := 0.003 + float(sample.daylight) * 0.005
		var total := gain + loss
		var target := gain / total
		wetness = target + (wetness - target) * exp(-total * step)
		cursor += step
	wetness = clampf(wetness, 0.0, 1.0)

func refresh(delta := 0.0) -> void:
	if not is_instance_valid(game):
		return
	var paused := _paused()
	if not paused:
		var clock := _absolute_clock()
		if last_clock < 0.0:
			last_clock = clock
		elif clock < last_clock - 0.001:
			# New-game / older-save reset. No future night's saturated road leaks back.
			wetness = 0.80
			last_clock = clock
		elif clock > last_clock:
			_integrate_wetness(last_clock, clock)
			last_clock = clock
		var profile := profile_at(clock)
		rain_amount = profile.rain
		cloud_cover = profile.clouds
		daylight = profile.daylight
		if active:
			animation_time += maxf(delta, 0.0)
	if not active:
		return
	_update_sky()
	if rain_node != null:
		rain_node.visible = rain_amount > 0.015
		rain_material.set_shader_parameter("rain_amount", rain_amount)
		rain_material.set_shader_parameter("daylight", daylight)
		rain_material.set_shader_parameter("weather_time", animation_time)
		_update_rain_cells()
	if town.get("renewal") != null:
		town.renewal.set_weather(wetness, rain_amount, animation_time)
		_light_update += delta
		if _light_update > 0.3 or delta == 0.0:
			_light_update = 0.0
			for lamp in town.renewal.lights:
				if is_instance_valid(lamp):
					var base := float(lamp.get_meta("base_energy", lamp.light_energy))
					lamp.set_meta("base_energy", base)
					lamp.light_energy = base * clampf(1.0 - daylight * 1.15, 0.12, 1.0)

func capture() -> Dictionary:
	return {"version": 1, "wetness": wetness, "last_clock": last_clock,
		"rain_amount": rain_amount, "cloud_cover": cloud_cover,
		"daylight": daylight, "animation_time": animation_time}

func restore(data: Dictionary) -> void:
	wetness = clampf(float(data.get("wetness", 0.80)), 0.0, 1.0)
	last_clock = float(data.get("last_clock", -1.0))
	animation_time = maxf(float(data.get("animation_time", 0.0)), 0.0)
	rain_amount = clampf(float(data.get("rain_amount", 0.60)), 0.0, 1.0)
	cloud_cover = clampf(float(data.get("cloud_cover", 0.88)), 0.0, 1.0)
	daylight = clampf(float(data.get("daylight", 0.0)), 0.0, 1.0)
	if last_clock >= 0.0:
		# Reconstruct a paused save's sky before gameplay has resumed its clock.
		var profile := profile_at(last_clock)
		rain_amount = profile.rain
		cloud_cover = profile.clouds
		daylight = profile.daylight
	_rain_origin = Vector2i(-99999, -99999)
	refresh(0.0)

func _make_sky() -> void:
	var sky := Sky.new()
	# Incremental radiance respects 64px and completes between the deliberately
	# throttled updates. REALTIME silently promotes this to 256px in Forward+.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.65
	environment.fog_height = -2.0
	environment.fog_height_density = 0.0
	environment.set("volumetric_fog_enabled", false)
	environment.tonemap_exposure = 0.94
	_last_sky_clock = -99999.0
	_last_sky_second = -99999

func _update_sky() -> void:
	if environment == null or sky_material == null:
		return
	var cloud_second := floori(animation_time)
	if absf(last_clock - _last_sky_clock) < 0.25 and cloud_second == _last_sky_second:
		return
	_last_sky_clock = last_clock
	_last_sky_second = cloud_second
	var minute := fposmod(last_clock if last_clock >= 0.0 else _absolute_clock(), 1440.0)
	var dawn := smoothstep(210.0, 250.0, minute) * (1.0 - smoothstep(280.0, 400.0, minute))
	var dusk := smoothstep(1010.0, 1080.0, minute) * (1.0 - smoothstep(1130.0, 1210.0, minute))
	var warm := maxf(dawn, dusk) * (1.0 - cloud_cover * 0.65)
	var zenith := Color("0c1727").lerp(Color("527a9b"), daylight)
	var horizon := Color("26323d").lerp(Color("9baeb6"), daylight)
	horizon = horizon.lerp(Color("c29b78"), warm * 0.62)
	var clouds := Color("141f2c").lerp(Color("70828c"), daylight)
	zenith = zenith.lerp(clouds, cloud_cover * 0.46)
	var altitude := sin(clampf((minute - 240.0) / 850.0, 0.0, 1.0) * PI)
	var direction := Vector3(-0.65, maxf(altitude, 0.08), -0.45).normalized()
	sky_material.set_shader_parameter("zenith_color", zenith)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("cloud_color", clouds)
	sky_material.set_shader_parameter("sun_direction", direction)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("cloud_cover", cloud_cover)
	sky_material.set_shader_parameter("weather_time", float(cloud_second))
	environment.ambient_light_color = Color("8194aa").lerp(Color("bac7ca"), daylight)
	environment.ambient_light_energy = lerpf(0.38, 0.57, daylight)
	environment.fog_light_color = horizon
	environment.fog_density = lerpf(0.0010, 0.0037, rain_amount) * lerpf(1.0, 0.65, daylight)
	if sun != null:
		sun.visible = true
		var celestial_direction := direction if daylight > 0.1 else Vector3(0.28, 0.52, -0.72).normalized()
		sun.look_at(sun.global_position - celestial_direction, Vector3.UP)
		sun.light_color = Color("7f9cbe").lerp(Color("fff1d4").lerp(Color("ffd4a3"), warm), daylight)
		sun.light_energy = lerpf(0.22, 2.15, daylight) * (1.0 - cloud_cover * 0.58)

func _index_roofs() -> void:
	_roof_bins.clear()
	var entries: Array = town.layout.get("buildings", []).duplicate()
	for landmark in town.layout.get("landmarks", []):
		var id := String(landmark.get("id", ""))
		if id == "10":
			# The landmark's 12x9 footprint contains an OPEN railway deck.
			# The original GLB's only roof is the separate guard hut to its west.
			entries.append({"x": 80.005, "z": 8.795, "w": 3.203,
				"d": 3.603, "height": 2.97, "rot": 0.0})
		elif id not in ["04", "08"]:
			entries.append(landmark)
	for entry in entries:
		var diagonal := Vector2(float(entry.get("w", 0.0)), float(entry.get("d", 0.0))).length() * 0.5 + 0.65
		var center := Vector2(float(entry.get("x", 0.0)), float(entry.get("z", 0.0)))
		var low := Vector2i(floori((center.x - diagonal) / ROOF_CELL), floori((center.y - diagonal) / ROOF_CELL))
		var high := Vector2i(floori((center.x + diagonal) / ROOF_CELL), floori((center.y + diagonal) / ROOF_CELL))
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var key := Vector2i(x, z)
				if not _roof_bins.has(key):
					_roof_bins[key] = []
				_roof_bins[key].append(entry)

func roof_height_at(point: Vector2) -> float:
	var height := 0.02
	var key := Vector2i(floori(point.x / ROOF_CELL), floori(point.y / ROOF_CELL))
	for entry in _roof_bins.get(key, []):
		var angle := float(entry.get("rot", 0.0))
		var offset := point - Vector2(float(entry.get("x", 0.0)), float(entry.get("z", 0.0)))
		var local := Vector2(offset.x * cos(angle) - offset.y * sin(angle), offset.x * sin(angle) + offset.y * cos(angle))
		if absf(local.x) <= float(entry.get("w", 0.0)) * 0.5 + 0.65 and absf(local.y) <= float(entry.get("d", 0.0)) * 0.5 + 0.65:
			var top := float(entry.get("height", 7.0))
			if String(entry.get("id", "")) == "01":
				top = maxf(top, 15.8)
			height = maxf(height, top + 0.15)
	return height

func _rain_mesh() -> ArrayMesh:
	# Crossed narrow ribbons stay visible while looking up/down and do not require
	# per-drop nodes, compute particles, depth reads or renderer-specific decals.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for axis in [0, 1]:
		var base := vertices.size()
		for p in [Vector2(-0.006, -0.18), Vector2(0.006, -0.18), Vector2(0.006, 0.18), Vector2(-0.006, 0.18)]:
			vertices.append(Vector3(p.x, p.y, 0.0) if axis == 0 else Vector3(0.0, p.y, p.x))
		uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		for i in [0, 1, 2, 0, 2, 3]:
			indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_rain() -> void:
	rain_node = MultiMeshInstance3D.new()
	rain_node.name = "RoofClippedRain"
	rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_node.extra_cull_margin = 40.0
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = _rain_mesh()
	instances.instance_count = (RAIN_RADIUS * 2 + 1) * (RAIN_RADIUS * 2 + 1) * DROPS_PER_CELL
	rain_material = ShaderMaterial.new()
	rain_material.shader = RAIN_SHADER
	rain_node.multimesh = instances
	rain_node.material_override = rain_material
	add_child(rain_node)

func _update_rain_cells() -> void:
	if not is_instance_valid(game.player):
		return
	var player_local: Vector3 = game.player.global_position - town.global_position
	sheltered = roof_height_at(Vector2(player_local.x, player_local.z)) > player_local.y + 1.8
	var origin := Vector2i(floori(player_local.x / RAIN_CELL), floori(player_local.z / RAIN_CELL))
	if origin == _rain_origin:
		return
	_rain_origin = origin
	var index := 0
	rain_floor_heights.clear()
	for x in range(-RAIN_RADIUS, RAIN_RADIUS + 1):
		for z in range(-RAIN_RADIUS, RAIN_RADIUS + 1):
			var cell := origin + Vector2i(x, z)
			var center := Vector2((cell.x + 0.5) * RAIN_CELL, (cell.y + 0.5) * RAIN_CELL)
			var roof := roof_height_at(center)
			rain_floor_heights.append(roof)
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(cell.x * 73856093 ^ cell.y * 19349663 ^ 4287)
			for _drop in range(DROPS_PER_CELL):
				var at := center + Vector2(rng.randf_range(-0.75, 0.75), rng.randf_range(-0.75, 0.75))
				# Evaluate the actual jittered position too: drops near an eave edge
				# must not use the neighbouring exposed cell's ground height.
				var drop_roof := maxf(roof, roof_height_at(at))
				rain_node.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y)))
				rain_node.multimesh.set_instance_custom_data(index, Color(drop_roof / 64.0, rng.randf(), rng.randf(), rng.randf() * 0.85))
				index += 1
