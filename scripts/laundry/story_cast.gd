extends RefCounted
## 剧情角色位（**本文件只摆人，不改任何一层的几何**）
## ---------------------------------------------------------------------------
## 三个 NPC 各自站进现成的场景里：
##   老周  → 4F · 402 屋里（站在工作台后面，隔着门/窗跟玩家说话）
##   阿七  → 2F · 洗衣店东墙镜子前（剧本 "03:20 镜子里多一个人影"）
##   秀兰  → 3F · 304 孩子房（孩子，1.32 m）
##
## 全部走 char_actor.gd，用现成的 *_Anim.glb 动作。
## 位置都量过现成模块的坐标，见各行注释。

const Actor := preload("res://scripts/laundry/char_actor.gd")

var a: LaundryArt
var world: Node3D

var laozhou = null
var aqi = null
var xiulan = null

func _init(art) -> void:
	a = art
	world = art.root

## 老周（4F 402）：工作台在 402 北墙 z0+0.42 = 2.62，他站在台子后面、面朝门（+Z）。
## 402 房间 x −3.2…−0.8，z 2.2…5.4；床占了西半边，所以站台前偏东一点。
func spawn_laozhou() -> void:
	laozhou = Actor.make(world, "laozhou", Vector3(-1.72, 9.8, 2.92), 0.0, 0.0)
	if laozhou == null:
		return
	# 一直在干活：低头看（修水表）
	var tw: Tween = laozhou.create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(func():
		if laozhou != null:
			laozhou.play("LookDown", 0.9))
	# 4F 是唯一有活人的一层：给他一点自身补光，别整个人糊在暖光里
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.45, 0.10)
	l.light_color = Color(1.0, 0.86, 0.66)
	l.light_energy = 0.3
	l.omni_range = 2.2
	laozhou.add_child(l)

## 阿七（2F 洗衣店）：镜子在东墙 x = w(3.12) ≈ 3.12，z = ZC − 0.50 = 5.50。
## 她站在镜子前、面朝墙（+X 方向）。模型正面 +Z → 要朝 +X，yaw = +PI/2。
func spawn_aqi() -> void:
	aqi = Actor.make(world, "aqi", Vector3(2.55, 3.5, 5.50), PI * 0.5, 0.0)
	if aqi == null:
		return
	aqi.play("Idle", 0.0)
	# 她是白的：一盏极弱的冷光只照她，读作"多出来的那一个"
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.50, 0.0)
	l.light_color = Color(0.62, 0.74, 0.86)
	l.light_energy = 0.22
	l.omni_range = 1.8
	aqi.add_child(l)

## 秀兰（3F 304 孩子房）：站在小床边，面朝门（+Z）。
## 304 房间 x 0.2…3.2、z 2.2…5.6，地面 y = 6.9；
## 小床中心 (cx−0.55, z0+0.90) = (1.15, 3.10)，书桌在南墙，所以在床东侧的空地站着。
const XIULAN_POS := Vector3(1.86, 6.9, 2.98)
func spawn_xiulan(pos := XIULAN_POS) -> void:
	xiulan = Actor.make(world, "xiulan", pos, 0.0, 0.0)
	if xiulan == null:
		return
	xiulan.play("Idle", 0.0)

## 剧情钩子：阿七转头看玩家（镜子里那一下）
func aqi_turn_to(p: Vector3) -> void:
	if aqi != null:
		aqi.face_point(p, 0.0)
		aqi.play("Idle", 0.4)

## 剧情钩子：秀兰坐下 / 站起
func xiulan_sit(seat := 0.42) -> void:
	if xiulan != null:
		xiulan.sit(seat)

func xiulan_stand() -> void:
	if xiulan != null:
		xiulan.stand()

## 剧情钩子：老周开门（用他的 OpenDoor 动作）
func laozhou_open() -> void:
	if laozhou != null:
		laozhou.face_point(Vector3(-2.1, 9.8, 6.0), 0.0)
		laozhou.play("OpenDoor", 0.3)

func laozhou_close() -> void:
	if laozhou != null:
		laozhou.play("CloseDoor", 0.3)
		var tw: Tween = laozhou.create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func():
			if laozhou != null:
				laozhou.play("Idle", 0.4))

func count() -> int:
	var n := 0
	if laozhou != null:
		n += 1
	if aqi != null:
		n += 1
	if xiulan != null:
		n += 1
	return n
