extends Node3D
## 得利洗衣店 · 上层/地下层**独立验收场景**（新文件，不改 laundry.tscn / laundry_main.gd）
## ---------------------------------------------------------------------------
## 这个场景只装「4F + 5F + 屋顶 + B1 + 楼梯井」五个新模块，用于单独出图与验收。
## 装配到正式场景只需要三行（见文件末尾注释）。
##
## 运行：
##   Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/laundry_upper.tscn

const Art := preload("res://scripts/laundry/laundry_art.gd")
const Stairs := preload("res://scripts/laundry/stairs_upper.gd")
const Floor4 := preload("res://scripts/laundry/floor4_flats.gd")
const Floor5 := preload("res://scripts/laundry/floor5_flats.gd")
const RoofDeck := preload("res://scripts/laundry/roof_deck.gd")
const Basement := preload("res://scripts/laundry/basement.gd")

var art: LaundryArt
var world: Node3D
var cam: Camera3D
var floors: Dictionary = {}

func _ready() -> void:
	_setup_environment()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	art = Art.new(world)

	var st := Stairs.new(art)
	st.build()

	var f4 := Floor4.new(art)
	f4.build()
	floors["f4"] = f4

	var f5 := Floor5.new(art)
	f5.build()
	floors["f5"] = f5

	var roof := RoofDeck.new(art)
	roof.build()
	floors["roof"] = roof

	var b1 := Basement.new(art)
	b1.build()
	floors["b1"] = b1

	var s0: Dictionary = art.done()
	print("[UPPER] 合批前 meshes=%d tris=%d lights=%d" % [s0["meshes"], s0["tris"], s0["lights"]])
	var res: Dictionary = art.merge_static()
	print("[UPPER] 合批 groups=%d merged=%d" % [res["groups"], res["merged"]])
	var s1: Dictionary = art.done()
	print("[UPPER] 合批后 meshes=%d tris=%d lights=%d" % [s1["meshes"], s1["tris"], s1["lights"]])

	_make_cam()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.010, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.15, 0.19)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.10
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.022, 0.026, 0.034)
	env.fog_light_energy = 0.5
	env.fog_density = 0.006
	we.environment = env
	add_child(we)

func _make_cam() -> void:
	cam = Camera3D.new()
	cam.name = "Cam"
	cam.fov = 68.0
	cam.near = 0.05
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 12.0, 9.6), Vector3(0.0, 10.9, 4.0), Vector3.UP)
	cam.current = true

# ===========================================================================
# 装配到正式场景（laundry_main.gd）只需要下面这段，放在 3F build 之后、
# art.merge_static() 之前：
#
#   const F4 := preload("res://scripts/laundry/floor4_flats.gd")
#   const F5 := preload("res://scripts/laundry/floor5_flats.gd")
#   const Roof := preload("res://scripts/laundry/roof_deck.gd")
#   const B1 := preload("res://scripts/laundry/basement.gd")
#   const StairsUp := preload("res://scripts/laundry/stairs_upper.gd")
#
#   var su = StairsUp.new(art); su.build()
#   var f4 = F4.new(art); f4.build()
#   var f5 = F5.new(art); f5.build()
#   var rf = Roof.new(art); rf.build()
#   var b1 = B1.new(art); b1.build()
# ===========================================================================
