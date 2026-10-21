extends Node3D
## 从回潮镇的许研资源导入角色；游戏内名字仍按剧本使用“许砚”。

const CHAR_PATH := "res://assets/town/xuyan/character.glb"
const CLIP_PATHS := {
	"walk": "res://assets/town/xuyan/walk.glb",
	"run": "res://assets/town/xuyan/run.glb",
	"inspect": "res://assets/town/xuyan/inspect.glb",
	"jump_start":"res://assets/town/xuyan/motion/JumpStart.glb",
	"jump_loop":"res://assets/town/xuyan/motion/JumpLoop.glb",
	"jump_land":"res://assets/town/xuyan/motion/JumpLand.glb",
	"crouch_down":"res://assets/town/xuyan/motion/CrouchDown.glb",
	"crouch_idle":"res://assets/town/xuyan/motion/CrouchIdle.glb",
	"crouch_walk":"res://assets/town/xuyan/motion/CrouchWalk.glb",
	"crouch_up":"res://assets/town/xuyan/motion/CrouchUp.glb",
}

var player: CharacterBody3D
var actor: Node3D
var skeleton: Skeleton3D
var mesh_node: MeshInstance3D
var animator: AnimationPlayer
var current_clip := ""
var model_scale := 1.0
var was_airborne := false
var was_crouching := false
var transition_left := 0.0

func setup(p: CharacterBody3D, held_rig: Node3D) -> void:
	player = p
	name = "XuYan3D"
	_hide_old_meshes(p.body)
	p.body.add_child(self)
	var packed: PackedScene = load(CHAR_PATH)
	if packed == null:
		push_error("许砚角色 GLB 无法载入")
		return
	actor = packed.instantiate()
	add_child(actor)
	skeleton = _find_type(actor, "Skeleton3D") as Skeleton3D
	mesh_node = _find_type(actor, "MeshInstance3D") as MeshInstance3D
	animator = _find_type(actor, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or mesh_node == null or animator == null:
		push_error("许砚角色缺少骨架/网格/动画播放器")
		return
	var bounds := _local_mesh_bounds(actor, mesh_node)
	model_scale = 1.74 / maxf(bounds.size.y, 0.01)
	actor.scale = Vector3.ONE * model_scale
	actor.position.y = -bounds.position.y * model_scale
	actor.rotation.y = PI # GLB 正面与 Godot 角色前方对齐
	_load_extra_clips()
	_play("idle")
	if held_rig != null:
		_attach_model_arms(held_rig)
	print("[CHAR] 许砚 GLB 已接入；身高比例 ", model_scale, "；骨骼 ", skeleton.get_bone_count())

func _hide_old_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
		_hide_old_meshes(child)

func _find_type(node: Node, classname: String) -> Node:
	for child in node.get_children():
		if child.get_class() == classname:
			return child
		var result := _find_type(child, classname)
		if result != null:
			return result
	return null

func _local_mesh_bounds(root_node: Node3D, visual: MeshInstance3D) -> AABB:
	var raw := visual.get_aabb()
	var tr := root_node.global_transform.affine_inverse() * visual.global_transform
	var out := AABB(tr * raw.get_endpoint(0), Vector3.ZERO)
	for i in range(1, 8):
		out = out.expand(tr * raw.get_endpoint(i))
	return out

func _load_extra_clips() -> void:
	var lib := AnimationLibrary.new()
	for name in CLIP_PATHS.keys():
		var source: PackedScene = load(CLIP_PATHS[name])
		if source == null:
			continue
		var clip_root: Node = source.instantiate()
		var clip_ap: AnimationPlayer = _find_type(clip_root, "AnimationPlayer") as AnimationPlayer
		if clip_ap != null and not clip_ap.get_animation_list().is_empty():
			var original: Animation = clip_ap.get_animation(clip_ap.get_animation_list()[0])
			var converted: Animation = original.duplicate(true)
			for i in range(converted.get_track_count() - 1, -1, -1):
				var path := String(converted.track_get_path(i))
				var bone := path.get_file().get_slice(":", 0)
				if skeleton.find_bone(bone) < 0:
					converted.remove_track(i)
				else:
					converted.track_set_path(i, NodePath("target_character/Skeleton3D:" + bone))
			converted.loop_mode = Animation.LOOP_NONE if name in ["jump_start","jump_land","crouch_down","crouch_up"] else Animation.LOOP_LINEAR
			lib.add_animation(name, converted)
		clip_root.free()
	if animator.has_animation("Idle_11"):
		animator.get_animation("Idle_11").loop_mode = Animation.LOOP_LINEAR
	animator.add_animation_library("town", lib)

func _play(name: String) -> void:
	if animator == null or name == current_clip:
		return
	current_clip = name
	var clip := "Idle_11" if name == "idle" else "town/" + name
	if animator.has_animation(clip):
		animator.play(clip, 0.18)

func _physics_process(_delta: float) -> void:
	if player == null or animator == null:
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	transition_left=maxf(0,transition_left-_delta)
	var airborne: bool=not player.is_on_floor() and player.air_time>.04
	if airborne:
		var rising: bool=player.velocity.y>0 and player.air_time<.13
		_play("jump_start" if rising else "jump_loop")
		animator.speed_scale=3.2 if rising else 1.0
	elif was_airborne:
		_play("jump_land"); animator.speed_scale=2.0;transition_left=.24
	elif player.crouching!=was_crouching:
		_play("crouch_down" if player.crouching else "crouch_up")
		animator.speed_scale=2.5;transition_left=.27
	elif transition_left<=0:
		if player.crouching:
			_play("crouch_walk" if speed>.1 else "crouch_idle")
			animator.speed_scale=clampf(speed/.29,.6,2.4) if speed>.1 else 1.0
		else:
			_play("run" if speed>4 else ("walk" if speed>.25 else "idle"));animator.speed_scale=1.0
	was_airborne=airborne;was_crouching=player.crouching

func _attach_model_arms(held_rig: Node3D) -> void:
	# 全身模型继续用于第三人称；第一人称采用同服装风格的近景持物网格。
	held_rig.set("use_xuyan_arms", true)
	held_rig.call("set_item", held_rig.get("item_id"))

func _extract_arms_mesh(mesh: Mesh, skel: Skeleton3D) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return null
	var out := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if points.is_empty() or bones.is_empty() or indices.is_empty():
			continue
		var stride: int = bones.size() / points.size()
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var hits := 0
			for corner in range(3):
				var v: int = indices[t + corner]
				var arm_weight := 0.0
				for j in range(stride):
					var bi: int = bones[v * stride + j]
					if bi >= 0 and bi < skel.get_bone_count():
						var bn := skel.get_bone_name(bi)
						if bn.contains("RightForeArm") or bn.contains("RightHand"):
							arm_weight += weights[v * stride + j]
				if arm_weight > 0.40:
					hits += 1
			if hits == 3:
				kept.append_array(PackedInt32Array([indices[t], indices[t + 1], indices[t + 2]]))
		if kept.is_empty():
			continue
		print("[CHAR ARM] faces ", kept.size() / 3, "/", indices.size() / 3)
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays,[],{},flags)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(surface))
	return out if out.get_surface_count() > 0 else null
