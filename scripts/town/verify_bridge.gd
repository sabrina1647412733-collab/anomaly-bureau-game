extends SceneTree

var faults: Array[String] = []

func _initialize() -> void:
	_run()

func check(ok: bool, detail: String) -> void:
	print("[OK] " if ok else "[FAIL] ", detail)
	if not ok:
		faults.append(detail)

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(5):
		await process_frame
	check(game.xuyan_avatar != null and game.xuyan_avatar.mesh_node != null, "许砚模型有可见网格")
	check(not bool(game.field_kit.rig.use_xuyan_arms), "第一人称独立持物网格不复用全身角色手臂")
	check(game.xuyan_avatar.animator.has_animation("town/walk") and game.xuyan_avatar.animator.has_animation("town/run"), "走路和奔跑动作已接入 Godot 骨架")
	var leg: int = game.xuyan_avatar.skeleton.find_bone("mixamorig_LeftUpLeg")
	game.xuyan_avatar.animator.play("Idle_11")
	game.xuyan_avatar.animator.advance(0.2)
	var idle_pose: Quaternion = game.xuyan_avatar.skeleton.get_bone_pose_rotation(leg)
	game.xuyan_avatar.animator.play("town/walk")
	game.xuyan_avatar.animator.advance(0.2)
	var walk_pose: Quaternion = game.xuyan_avatar.skeleton.get_bone_pose_rotation(leg)
	check(idle_pose.angle_to(walk_pose) > 0.01, "行走动画实际驱动腿部骨骼")
	game._start_prologue(false)
	for i in range(8):
		await process_frame
	check(game.state == "prologue", "新游戏进入出租屋")
	game.prologue_call_done = true
	game.prologue_letter_ready = true
	game.prologue_letter_read = true
	game._prologue_act("door")
	game._step_exit_to_town(1.15)
	game._step_exit_to_town(1.15)
	for i in range(8):
		await process_frame
	check(game.prologue_stage == "town" and game.town_bridge.active, "街道场景已进入")
	check(game.town_bridge.layout.get("landmarks", []).size() == 10, "十个命名地标保留")
	check(game.town_bridge.town_map.visible, "小地图可见")
	check(game.player.cam_mode == 0, "街道保留进入前的第一人称")
	game.player.toggle_cam()
	check(game.player.cam_mode == 2, "V 切到第二人称")
	game.player.toggle_cam()
	check(game.player.cam_mode == 1, "V 切到第三人称")
	game.player.toggle_cam()
	check(game.player.cam_mode == 0, "V 切回第一人称")
	game.town_bridge.toggle_map()
	check(game.town_bridge.town_map.big_open, "M 打开大地图")
	var place: Dictionary = game.town_bridge._landmark("01")
	var front: Array = place.get("front", [])
	game.player.global_position = game.town_bridge.ORIGIN + Vector3(float(front[0]), 0.2, float(front[1]) + 1.3)
	var hint: Dictionary = game.town_bridge.interaction_hint()
	check(hint.get("id", "") == "01", "洗衣店门口可交互")
	var save = preload("res://scripts/case_save.gd").capture(game)
	check(save.get("stage", "") == "town", "街道阶段可写入存档")
	var saved_pos: Vector3 = game.player.global_position
	var restored: bool = preload("res://scripts/case_save.gd").restore(game, save)
	check(restored and game.town_bridge.active and game.player.global_position.distance_to(saved_pos) < 0.01, "街道阶段读取后保留位置")
	game.town_bridge.interact("01")
	check(game._exit_to_laundry, "洗衣店门触发独立场景转场")
	game._step_exit_to_laundry(2.25)
	check(game.case_mode == "laundry" and game.laundry != null, "街道进入洗衣房独立空间")
	# A 00:10 snapshot must have completed onboarding; otherwise the intentional
	# evidence gate holds the first shift at midnight during re-entry.
	for flag_name in ["signed","rules_seen","seven_seen"]:game.laundry.campaign.mark(flag_name)
	game.laundry.clues["slip"]=true
	game.laundry.t = 30.0 * 60.0
	game.laundry.clues["sweater"] = true
	game.laundry.interact("lb_exit")
	game._step_laundry_to_town(2.25)
	check(game.town_bridge.active and game.case_mode == "" and game.prologue_stage == "town", "洗衣房门厅可返回回潮镇")
	check(game.director.room_minutes >= game.laundry.START_MIN + 30.0, "返回街道时夜班时间保留")
	var outside_save = preload("res://scripts/case_save.gd").capture(game)
	check(outside_save.has("laundry"), "街道存档包含尚未结束的夜班状态")
	check(preload("res://scripts/case_save.gd").restore(game, outside_save), "返回街道后的存档可读取")
	game.town_bridge.interact("01")
	game._step_exit_to_laundry(2.25)
	check(game.case_mode == "laundry" and game.laundry.t >= 30.0 * 60.0, "重进洗衣房继续原夜班时间")
	check(game.laundry.has_clue("sweater"), "街道存档后返回仍保留已取得线索")
	game.queue_free()
	for i in range(3):
		await process_frame
	print("BRIDGE RESULT faults=", faults.size())
	quit(0 if faults.is_empty() else 1)
