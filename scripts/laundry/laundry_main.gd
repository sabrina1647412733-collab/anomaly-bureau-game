extends Node3D
## 得利洗衣店 · 开发场景根
## 1F 门厅 + 楼梯 + 2F 洗衣店 + 后房，加第一人称玩家与第一夜流程。
## 运行：godot --path . res://scenes/laundry.tscn

const Art := preload("res://scripts/laundry/laundry_art.gd")
const Lobby := preload("res://scripts/laundry/floor1_lobby.gd")
const Stairs := preload("res://scripts/laundry/stairs.gd")
const Floor2 := preload("res://scripts/laundry/floor2_laundry.gd")
const Back2 := preload("res://scripts/laundry/floor2_backroom.gd")
const Floor3 := preload("res://scripts/laundry/floor3_flats.gd")
const Night := preload("res://scripts/laundry/first_night.gd")
const PlayerScript := preload("res://scripts/laundry/fps_player.gd")
# 上层与地下层（新增，见 laundry_upper.gd 的说明）
const StairsUp := preload("res://scripts/laundry/stairs_upper.gd")
const Floor4 := preload("res://scripts/laundry/floor4_flats.gd")
const Floor5 := preload("res://scripts/laundry/floor5_flats.gd")
const RoofDeck := preload("res://scripts/laundry/roof_deck.gd")
const Basement := preload("res://scripts/laundry/basement.gd")
const BackAlley := preload("res://scripts/laundry/back_alley.gd")
const MailOffice := preload("res://scripts/laundry/mail_office.gd")
const PowerRoom := preload("res://scripts/laundry/power_room.gd")
const CastScript := preload("res://scripts/laundry/story_cast.gd")

var art
var world: Node3D
var player
var night
var cam: Camera3D          # 验收截图用的自由机位（默认不启用）
var buildings: Dictionary = {}   # 各楼层实例，给剧情/调试按 key 取
var cast                     # story_cast.gd：老周 / 阿七 / 秀兰

func _ready() -> void:
	_setup_environment()
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	art = Art.new(world)
	var lobby = Lobby.new(art)
	lobby.build()
	var stairs = Stairs.new(art)
	stairs.build()
	var f2 = Floor2.new(art)
	f2.build()
	var b2 = Back2.new(art)
	b2.build()
	var f3 = Floor3.new(art)
	f3.build()

	# —— 上层与地下层（4F / 5F / 屋顶 / B1 + 贯通楼梯井）——
	# 由 laundry_upper.gd 那套独立模块提供；这里只是装配，不改各自内部逻辑。
	# 顺序有讲究：楼梯井先建（它给 4F/5F 的井口收边），再建各层。
	var stairs_up = StairsUp.new(art)
	stairs_up.build()
	var f4 = Floor4.new(art)
	f4.build()
	var f5 = Floor5.new(art)
	f5.build()
	var roof = RoofDeck.new(art)
	roof.build()
	var b1 = Basement.new(art)
	b1.build()
	var alley = BackAlley.new(art)
	alley.build()
	var mail_of = MailOffice.new(art)
	mail_of.build()
	var power = PowerRoom.new(art)
	power.build()
	buildings["f4"] = f4
	buildings["f5"] = f5
	buildings["roof"] = roof
	buildings["b1"] = b1
	buildings["stairs_up"] = stairs_up
	buildings["alley"] = alley
	buildings["mail_office"] = mail_of
	buildings["power_room"] = power

	var st0: Dictionary = art.done()
	print("[LAUNDRY] 合批前 meshes=%d tris=%d lights=%d" % [st0["meshes"], st0["tris"], st0["lights"]])
	var mres: Dictionary = art.merge_static()
	print("[LAUNDRY] 合批 groups=%d merged=%d" % [mres["groups"], mres["merged"]])
	var st: Dictionary = art.done()
	print("[LAUNDRY] 合批后 meshes=%d tris=%d lights=%d" % [st["meshes"], st["tris"], st["lights"]])

	_make_free_cam()
	_make_player()

	night = Node.new()
	night.set_script(Night)
	night.name = "FirstNight"
	add_child(night)
	night.setup(player, f2.drums, world, f2, b2, art)

	# —— 剧情角色：只摆人，不动任何一层的几何 ——
	cast = CastScript.new(art)
	cast.spawn_laozhou()
	cast.spawn_aqi()
	cast.spawn_xiulan()
	print("[LAUNDRY] 剧情角色 %d 个（老周 / 阿七 / 秀兰）" % cast.count())

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.019, 0.026)
	# 环境光：本地跑、不用迁就 Web，直接给足「室内环境光」。
	# 原来 0.55 是为了压出恐怖感，结果是玩家看不清路 —— 恐怖应该来自构图和光色，
	# 不是来自「黑得看不见」。1.35 是实测能看清又不糊的值。
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.28, 0.34)
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 曝光从 1.05 → 1.35：Filmic 会把暗部压得很狠，本地没有性能压力就直接抬曝光。
	env.tonemap_exposure = 1.35
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	# 反射/球谐：本地 GPU 足够，开了之后白瓷砖和不锈钢才有"亮"的感觉
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.10
	env.fog_enabled = true
	env.fog_light_color = Color(0.040, 0.048, 0.062)
	env.fog_light_energy = 0.7
	env.fog_density = 0.008
	we.environment = env
	add_child(we)

func _make_free_cam() -> void:
	cam = Camera3D.new()
	cam.name = "Cam"
	cam.fov = 68.0
	add_child(cam)
	cam.look_at_from_position(Vector3(1.0, 5.12, 9.6), Vector3(0.0, 4.55, 2.3), Vector3.UP)
	cam.current = false

func _make_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(-0.55, 0.9, -8.2)
	player.rotation.y = PI
	add_child(player)
	player.yaw = PI

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and night != null and not night.nb_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
