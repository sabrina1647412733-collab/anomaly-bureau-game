extends SceneTree
## 角色 GLB 接入验证：能否加载、动画名单、动画能否播放、包围盒。
## 运行: godot --headless --path . --script res://scripts/tests/char_test.gd

const CHARS := [
	"res://assets/models/chars/ZhouXiulan_Anim.glb",
	"res://assets/models/chars/LaoZhou_Anim.glb",
	"res://assets/models/chars/Xiulan_Anim.glb",
	"res://assets/models/chars/Aqi_Anim.glb",
]

var passed := 0
var failed := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  [PASS] ", msg)
	else:
		failed += 1
		print("  [FAIL] ", msg)


func _init() -> void:
	print("=== 角色 GLB 验证 ===")
	for path in CHARS:
		print("\n--- ", path.get_file(), " ---")
		check(ResourceLoader.exists(path), "文件存在")
		var packed = load(path)
		check(packed != null, "能加载")
		if packed == null:
			continue

		var node: Node3D = packed.instantiate()
		root.add_child(node)

		# 找 AnimationPlayer
		var ap: AnimationPlayer = _find_anim_player(node)
		check(ap != null, "有 AnimationPlayer")
		if ap:
			var names := ap.get_animation_list()
			print("  动作: ", names)
			check(names.size() >= 5, "动作数 >= 5 (实际 %d)" % names.size())
			check("Idle" in names, "有 Idle")
			check("Walk" in names, "有 Walk")

			# 播放 Idle
			ap.play("Idle")
			check(ap.is_playing(), "Idle 能播放")
			var anim := ap.get_animation("Idle")
			if anim:
				check(anim.length > 0.5, "Idle 时长 > 0.5s (实际 %.2fs)" % anim.length)

		# 找骨架与网格
		var skel := _find_skinned(node)
		check(skel != null, "有 SkinnedMeshInstance")
		if skel:
			var sk: Skeleton3D = null
			if skel.skeleton != NodePath():
				sk = skel.get_node_or_null(skel.skeleton) as Skeleton3D
			if sk:
				check(sk.get_bone_count() > 50,
					"骨骼数 > 50 (实际 %d)" % sk.get_bone_count())
			else:
				check(false, "找不到 Skeleton3D")
			var aabb := skel.get_aabb()
			print("  AABB: ", aabb)
			var height := aabb.size.y
			check(height > 1.0 and height < 2.0, "高度合理 %.2fm" % height)

		node.queue_free()

	print("\n=== 结果: 通过 %d / 失败 %d ===" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null


func _find_skinned(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).skeleton != null:
		return n
	for c in n.get_children():
		var r := _find_skinned(c)
		if r:
			return r
	return null
