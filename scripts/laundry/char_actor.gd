class_name LaundryActor
extends Node3D
## 角色驱动：把 assets/models/chars/*_Anim.glb 当成「会动的角色」用。
## ---------------------------------------------------------------------------
## 只用现成模型与动作，不改 assets/models/chars/ 里的任何文件。
##
## 四个角色的动作（Godot 里实测的 AnimationPlayer 列表）：
##   周秀兰 ZhouXiulan_Anim  9 个：CloseDoor Idle LookDown OpenDoor SitDown SitIdle SitIdle2 StandUp Walk
##   老周   LaoZhou_Anim     8 个：CloseDoor Idle LookDown OpenDoor SitDown SitIdle StandUp Walk
##   秀兰   Xiulan_Anim      6 个：Idle LookDown SitDown SitIdle StandUp Walk
##   阿七   Aqi_Anim         9 个：Idle LookDown Run Shrug SitIdle StandUp TalkHip Walk WalkToSit
##
## 坐姿：GLB 里的 SitDown/SitIdle 假定椅面 0.45 m。
## 洗衣店长椅（bench_01）座面顶 = 0.445 + 0.030 = 0.475 m，差 2.5 cm，
## 用 SEAT_FIX 补；换别的椅子就把 seat_h 传进来。

const CHARS := "res://assets/models/chars/"
const SEAT_REF := 0.45          # 动作假定的椅面高

## 用动作名索引，别名把「剧本里的说法」映射到实际动作名
const ALIAS := {
	"idle": "Idle",
	"walk": "Walk",
	"run": "Run",
	"look": "LookDown",
	"lookdown": "LookDown",
	"sit_down": "SitDown",
	"sit": "SitIdle",
	"sitidle": "SitIdle",
	"sitidle2": "SitIdle2",
	"stand_up": "StandUp",
	"standup": "StandUp",
	"open": "OpenDoor",
	"close": "CloseDoor",
	"shrug": "Shrug",
	"talk": "TalkHip",
	"walk_to_sit": "WalkToSit",
}

var who := ""                   # zhou / laozhou / xiulan / aqi
var model: Node3D = null        # GLB 实例
var ap: AnimationPlayer = null
var current := ""
var seat_h := 0.475             # 默认按洗衣店长椅
var extra_y := 0.0              # 坐下时额外的 Y 偏移（剧情层可调）
var facing := 0.0               # 目标朝向
var speed := 0.0                # 走路速度 m/s（0 = 站着）
var _model_h := 1.6
var performance:Node

## 建一个角色。pos 是脚底点。
static func make(parent: Node3D, id: String, pos: Vector3, yaw := 0.0,
		target_h := 0.0) -> LaundryActor:
	var path := file_of(id)
	var ps = load(path)
	if ps == null:
		push_warning("LaundryActor: 找不到模型 " + path)
		return null
	var n = new()
	n.who = id
	n.position = pos
	n.rotation.y = yaw
	n.facing = yaw
	n.set_meta("dynamic", true)
	parent.add_child(n)

	var inst: Node3D = ps.instantiate()
	inst.set_meta("dynamic", true)
	n.add_child(inst)
	n.model = inst
	n.ap = inst.find_child("AnimationPlayer", true, false)

	# 身高校准：模型自带身高（周秀兰 1.56 / 老周 1.68 / 秀兰 1.32 / 阿七 1.65），
	# 传了 target_h 才缩放，否则用原尺寸。
	# 注意：aabb() 给的是**世界**包围盒，不能直接拿来当局部偏移量（第一版就是这么
	# 把三个角色整体压到地板下面 9.8 m 的）。这里用 labb() 取相对角色原点的盒子。
	var bb := n.labb()
	if target_h > 0.0 and bb.size.y > 0.001:
		var s := target_h / bb.size.y
		inst.scale = Vector3(s, s, s)
		bb = n.labb()
	n._model_h = bb.size.y
	# 贴地：脚底落到 y = 0（模型本来就该脚底在 0，这条只是兜底）
	if absf(bb.position.y) > 0.01:
		inst.position.y -= bb.position.y
	n.seat_base_y = inst.position.y       # 座偏移只在这个基准之上加减
	n.refine_clips()
	n.refine_materials()
	if id in ["zhou","laozhou","aqi"]:
		n.performance=preload("res://scripts/laundry/facial_performance.gd").new()
		n.add_child(n.performance);n.performance.setup(n)

	for clip_name in ["Idle","Walk","SitIdle"]:
		var clip = n.ap.get_animation(clip_name) if n.ap != null and n.ap.has_animation(clip_name) else null
		if clip != null:clip.loop_mode=Animation.LOOP_LINEAR
	n.play("Idle", 0.0)
	return n

func refine_clips() -> void:
	if ap==null or who not in ["zhou","laozhou","aqi"]:return
	var sk:Skeleton3D=model.find_child("Skeleton3D",true,false)
	var file="res://assets/models/chars/finish/"+who+"_clips.res"
	if sk==null or not ResourceLoader.exists(file):return
	var source:AnimationLibrary=load(file)
	var path=String(ap.get_node(ap.root_node).get_path_to(sk))
	var library=ap.get_animation_library("").duplicate()
	ap.remove_animation_library("");ap.add_animation_library("",library)
	for name in source.get_animation_list():
		var clip:Animation=source.get_animation(name).duplicate(true)
		for i in clip.get_track_count():
			var bone=String(clip.track_get_path(i)).get_slice(":",1)
			clip.track_set_path(i,NodePath(path+":"+bone))
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,clip)

func refine_materials() -> void:
	for visual in model.find_children("*","MeshInstance3D",true,false):
		for i in visual.mesh.get_surface_count():
			var m=visual.get_active_material(i)
			if m is StandardMaterial3D:
				var copy=m.duplicate();copy.roughness=maxf(copy.roughness,.74);copy.metallic=0.
				visual.set_surface_override_material(i,copy)

static func file_of(id: String) -> String:
	match id:
		"zhou", "zhoux iulan", "lady", "oldlady":
			return CHARS + "ZhouXiulan_Anim.glb"
		"laozhou", "zhou_old":
			return CHARS + "LaoZhou_Anim.glb"
		"xiulan", "kid", "girl":
			return CHARS + "Xiulan_Anim.glb"
		"aqi":
			return CHARS + "Aqi_Anim.glb"
	return CHARS + "ZhouXiulan_Anim.glb"

## 动作名归一化：剧本里的说法 → 模型里真有的名字。没有就退到 Idle。
func resolve(anim: String) -> String:
	var key := anim.strip_edges().to_lower()
	if ALIAS.has(key):
		key = ALIAS[key]
	else:
		key = anim
	if ap == null:
		return ""
	var list := ap.get_animation_list()
	if list.has(key):
		return key
	# 大小写不敏感再找一次
	for n in list:
		if String(n).to_lower() == key.to_lower():
			return String(n)
	return ""

func has_anim(anim: String) -> bool:
	return resolve(anim) != ""

## 播放动作。blend 是过渡秒数，0 = 硬切。
func play(anim: String, blend := 0.22) -> bool:
	var name := resolve(anim)
	if name == "" or ap == null:
		return false
	if name == current and ap.is_playing():
		return true
	var prev := current
	current = name
	if blend > 0.01 and prev != "" and ap.get_animation(name) != null \
			and ap.get_animation(prev) != null:
		_crossfade(prev, name, blend)
	else:
		ap.play(name)
	return true

## AnimationPlayer 自带的 blend 在 NLA/单动画导出里不一定生效，
## 这里退一步：直接 play + 用 speed_scale 归一，不报错就行。
func _crossfade(_from: String, to: String, t: float) -> void:
	ap.play(to,t)

func anim_length(anim: String) -> float:
	var n := resolve(anim)
	if n == "" or ap == null:
		return 0.0
	var an := ap.get_animation(n)
	return an.length if an != null else 0.0

# ---------------------------------------------------------------- 朝向 / 走位
## 这些 GLB 的**正面是 +Z**（四方位截图实测：从 +Z 看得到脸，从 −Z 看到后脑勺）。
## 场景里 1F/2F 的建筑是「正面 −Z」约定，但角色模型不一样，别混。
## yaw = 0 → 面朝 +Z；要让角色面朝方向 d，yaw = atan2(d.x, d.z)。
const FRONT_SIGN := 1.0

## 面朝某点
func face_point(p: Vector3, dt := 0.0, rate := 6.0) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length_squared() < 1e-6:
		return
	var yaw := atan2(d.x * FRONT_SIGN, d.z * FRONT_SIGN)
	if dt <= 0.0:
		rotation.y = yaw
		facing = yaw
	else:
		rotation.y = lerp_angle(rotation.y, yaw, clampf(dt * rate, 0.0, 1.0))
		facing = rotation.y

## 给定「想让正面朝哪个世界方向」，算出 yaw
static func yaw_for_dir(dir: Vector3) -> float:
	return atan2(dir.x * FRONT_SIGN, dir.z * FRONT_SIGN)

func face_yaw(y: float, dt := 0.0, rate := 6.0) -> void:
	if dt <= 0.0:
		rotation.y = y
	else:
		rotation.y = lerp_angle(rotation.y, y, clampf(dt * rate, 0.0, 1.0))
	facing = rotation.y

## 朝当前朝向往前挪（Walk 动作用；真正的寻路由剧情层给路点）
## 模型正面是 +Z，所以前进方向 = basis.z（不是 −basis.z）
func advance(dt: float) -> void:
	if speed <= 0.0001:
		return
	var fwd := global_transform.basis.z * FRONT_SIGN
	fwd.y = 0.0
	global_position += fwd.normalized() * speed * dt

# ---------------------------------------------------------------- 坐
## 注意：这批 GLB 的动作**很长**（SitDown 5.97 s、SitIdle 8.67 s、Idle 11.17 s），
## 直接播会让"坐下"变成慢动作。实测长度：
##   Walk 2.23 / LookDown 4.80 / SitDown 5.97 / SitIdle 8.67 / StandUp 6.10
## 实测骨盆高度（相对模型脚底原点）：
##   Idle 0.865 / SitDown 末 0.906（还没坐下去！）/ SitIdle 0.528 / SitIdle2 0.906
## → **SitDown 的末帧不是坐姿**，必须播完立刻切 SitIdle，否则会停在「半蹲」。
const SPEED_SIT := 3.2
const SPEED_IDLE := 1.0
const SPEED_WALK := 1.35        # Walk 2.23 s 一轮，稍微加速才跟得上 1.4 m/s 的移动

var _sit_tween: Tween = null

## 坐下：播 SitDown（加速），**播完立刻切 SitIdle**，并按椅面高度整体抬一下。
## SitDown 的末帧骨盆是 0.906（站着的高度），SitIdle 才是 0.528 —— 少切这一下会停在半蹲。
func sit(seat_height := -1.0) -> void:
	if seat_height > 0.0:
		seat_h = seat_height
	# 来源SitDown末帧仍是站姿，用引擎骨骼混合到真实坐姿。
	if _sit_tween != null and _sit_tween.is_valid():_sit_tween.kill()
	if ap != null:ap.speed_scale = SPEED_IDLE
	play("SitIdle", .65)
	_apply_seat_offset()

func sit_idle() -> void:
	play("SitIdle", 0.30)
	if ap != null:
		ap.speed_scale = SPEED_IDLE

func stand() -> void:
	play("StandUp", 0.15)
	if ap != null:
		ap.speed_scale = SPEED_SIT
	var tw := create_tween()
	tw.tween_property(model, "position:y", seat_base_y, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_inside_tree():
			sit_idle_reset())

func sit_idle_reset() -> void:
	if ap != null:
		ap.speed_scale = SPEED_IDLE
	play("Idle", 0.3)

## 播一个「一次性」动作（开门、数衣服这类），播完自动回到 Idle/坐姿
func play_once(anim: String, back := "", speed := 1.0) -> void:
	if not play(anim, 0.20):
		return
	if ap != null:
		ap.speed_scale = speed
	var name := resolve(anim)
	var tw := create_tween()
	tw.tween_interval(anim_length(anim) / maxf(speed, 0.01))
	tw.tween_callback(func():
		if not is_inside_tree():
			return
		if ap != null:
			ap.speed_scale = SPEED_IDLE
		play(back if back != "" else "Idle", 0.3))

func seat_offset() -> float:
	return (seat_h - SEAT_REF) + extra_y

func _apply_seat_offset() -> void:
	if model == null:
		return
	var t := create_tween()
	t.tween_property(model, "position:y", seat_base_y + seat_offset(), 0.5) \
		.set_trans(Tween.TRANS_SINE)

## 立刻把座偏移打到模型上（截图 / 测试用，不走 Tween）
func _apply_seat_offset_instant() -> void:
	if model == null:
		return
	model.position.y = seat_base_y + seat_offset()

## 站起来之后把模型 y 还原
func _clear_seat_offset_instant() -> void:
	if model == null:
		return
	model.position.y = seat_base_y

var seat_base_y := 0.0

# ---------------------------------------------------------------- 包围盒
func aabb() -> AABB:
	var out := AABB()
	var first := true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out

## 相对角色原点（脚底）的包围盒 —— 用来贴地 / 量身高，别用世界包围盒。
func labb() -> AABB:
	var out := AABB()
	var first := true
	var xf := global_transform.affine_inverse()
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = (xf * m.global_transform) * m.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out

func model_height() -> float:
	return _model_h

# ---------------------------------------------------------------- 每帧
func _process(dt: float) -> void:
	advance(dt)
