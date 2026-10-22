extends SceneTree
## Real skeleton poses, clip transitions, pause and CharacterBody input regression.
var passed := 0
var failed := 0
var player
var actor
var world:Node3D
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("[PASS] ",label)
	else:failed+=1;push_error("FAIL "+label)
func point(name:String)->Vector3:
	return actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("mixamorig_"+name)).origin
func pose(name:String,time:float):
	actor.animator.play("town/"+name,0);actor.animator.seek(time,true);actor.animator.advance(0);actor.animator.pause()
	actor.skeleton.force_update_all_bone_transforms()
func lowest_shoe()->float:
	var visual:MeshInstance3D=actor.mesh_node;var sk:Skeleton3D=actor.skeleton
	var skin:Skin=visual.skin;var transforms=[]
	for i in skin.get_bind_count():
		var id=sk.find_bone(skin.get_bind_name(i))
		transforms.append(sk.global_transform*sk.get_bone_global_pose(id)*skin.get_bind_pose(i))
	var arrays=visual.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX]
	var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
	# The original XuYan asset uses EIGHT weights; do not assume a four-weight stride.
	var stride:int=bones.size()/points.size();var low=INF
	for i in points.size():
		if points[i].y>.18:continue
		var result=Vector3.ZERO
		for j in stride:result+=(transforms[bones[i*stride+j]]*points[i])*weights[i*stride+j]
		low=minf(low,result.y)
	return low
func key(code:Key,down:bool):
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	create_timer(65).timeout.connect(func():quit(2))
	world=Node3D.new();root.add_child(world)
	player=preload("res://scripts/player.gd").new();world.add_child(player);player.set_physics_process(false)
	actor=preload("res://scripts/town/xuyan_character.gd").new();actor.setup(player,null);actor.set_physics_process(false)
	var sk:Skeleton3D=actor.skeleton
	for name in actor.CORRECTED_MOTION.get_animation_list():
		var clip:Animation=actor.animator.get_animation("town/"+name)
		var lengths_ok=true;var feet_ok=true;var orientation_ok=true
		var min_separation=INF;var head_min=INF;var ankle_min=INF;var ankle_max=-INF
		for frame in range(int(round(clip.length*30))+1):
			pose(name,float(frame)/30.)
			for side in ["Left","Right"]:
				for pair in [[side+"UpLeg",side+"Leg"],[side+"Leg",side+"Foot"],[side+"Arm",side+"ForeArm"],[side+"ForeArm",side+"Hand"]]:
					var a=sk.find_bone("mixamorig_"+pair[0]);var b=sk.find_bone("mixamorig_"+pair[1])
					var rest_length=sk.get_bone_global_rest(a).origin.distance_to(sk.get_bone_global_rest(b).origin)
					if absf(point(pair[0]).distance_to(point(pair[1]))-rest_length)>.008:lengths_ok=false
			var left=point("LeftFoot");var right=point("RightFoot")
			min_separation=minf(min_separation,left.x-right.x)
			head_min=minf(head_min,point("Head").y)
			ankle_min=minf(ankle_min,minf(left.y,right.y));ankle_max=maxf(ankle_max,maxf(left.y,right.y))
			if left.x-right.x<.13 or minf(left.y,right.y)<.06:feet_ok=false
			var shoulders=point("LeftArm")-point("RightArm")
			if point("Head").y<.99 or shoulders.x<.25 or absf(shoulders.z)>.12:orientation_ok=false
		check(lengths_ok,"逐帧保持四肢长度，无拉伸："+name)
		check(feet_ok,"逐帧双脚顺序和离地高度正常："+name)
		check(orientation_ok,"逐帧身体朝向和头部高度正常："+name)
		print("POSE_METRICS ",name," separation=",min_separation," head_min=",head_min," ankle_range=",ankle_min,",",ankle_max)
		if name.begins_with("crouch"):
			var soles_ok=true
			for ratio in [0.,.25,.5,.75,.999]:
				pose(name,clip.length*ratio)
				var low=lowest_shoe()
				if low<-.012 or low>.018:soles_ok=false
			check(soles_ok,"实际八权重蒙皮鞋底与地面吻合："+name)
	pose("crouch_idle",0)
	check(point("Head").y>1.05 and point("Head").y<1.18 and point("Hips").y>.60 and point("Hips").y<.70,"蹲姿头和骨盆高度符合许砚比例")
	check(point("LeftLeg").z>point("LeftUpLeg").z+.18 and point("RightLeg").z>point("RightUpLeg").z+.18,"蹲姿膝盖朝脚尖方向屈曲")
	actor.current_clip="";actor.was_airborne=false;actor.was_crouching=false;actor.transition_left=0
	actor.update_motion(1./60,0,true,true,false)
	check(actor.current_clip=="jump_start" and actor.playback_rate==3.2,"起跳当帧进入起跳动作")
	actor.update_motion(.06,0,true,true,false)
	check(actor.current_clip=="jump_start","起跳动作不会在中途被滞空截断")
	actor.update_motion(.08,0,true,true,false)
	check(actor.current_clip=="jump_loop","完整起跳后转入滞空")
	actor.update_motion(.01,0,false,false,false)
	check(actor.current_clip=="jump_land","实际落地后播放落地缓冲")
	actor.update_motion(.22,0,false,false,false)
	check(actor.current_clip=="jump_land","落地动作按片段时长保留")
	actor.update_motion(.02,0,false,false,false)
	check(actor.current_clip=="idle","落地完成回到站立")
	actor.update_motion(.01,0,false,false,true)
	check(actor.current_clip=="crouch_down","按下蹲进入蹲下过渡")
	actor.update_motion(.28,0,false,false,true)
	check(actor.current_clip=="crouch_idle","蹲下播完维持蹲姿")
	actor.update_motion(.01,.58,false,false,true)
	check(actor.current_clip=="crouch_walk","蹲行匹配低速步态")
	actor.update_motion(.01,0,false,false,false)
	check(actor.current_clip=="crouch_up","松开蹲进入起身过渡")
	actor.update_motion(.25,0,false,false,false)
	check(actor.current_clip=="idle","起身播完回到站立")
	actor.was_airborne=false;actor.update_motion(.01,0,true,false,false)
	check(actor.current_clip=="jump_loop","从台阶落下不错误播放主动起跳")
	player.physics_frozen=true;var remaining:float=actor.transition_left
	actor._physics_process(.5)
	check(actor.animator.speed_scale==0 and actor.transition_left==remaining,"暂停冻结动画和过渡计时")
	player.physics_frozen=false;player.air_time=.1;player.velocity.y=-1
	actor._physics_process(.01)
	check(actor.animator.speed_scale>0,"恢复后主角动画继续")
	# Run the real player controller over a physical floor, including low ceiling.
	var floor=StaticBody3D.new();world.add_child(floor)
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(10,.2,10);collision.shape=box;floor.add_child(collision);floor.position.y=-.1
	player.global_position=Vector3(0,.03,0);player.velocity=Vector3.ZERO
	for i in 10:await physics_frame;player._physics_process(1./60.)
	check(player.is_on_floor(),"真实碰撞体站立于地面")
	key(KEY_C,true)
	for i in 24:await physics_frame;player._physics_process(1./60.)
	check(player.crouching and player.crouch_k>.97 and absf(player.cap_node.position.y-player.cap.height*.5)<.001,"按键蹲下时胶囊底部留在脚底")
	var ceiling=StaticBody3D.new();world.add_child(ceiling)
	var top=CollisionShape3D.new();var top_box=BoxShape3D.new();top_box.size=Vector3(2,.1,2);top.shape=top_box;ceiling.add_child(top);ceiling.position.y=1.58
	await physics_frame;key(KEY_C,false)
	for i in 5:await physics_frame;player._physics_process(1./60.)
	check(player.crouching and not player.can_stand(),"低顶下松键仍保持蹲姿")
	ceiling.queue_free();await physics_frame;await physics_frame
	for i in 24:await physics_frame;player._physics_process(1./60.)
	check(not player.crouching and player.crouch_k<.03,"离开低顶恢复站立")
	key(KEY_SPACE,true);await physics_frame;player._physics_process(1./60.)
	check(player.velocity.y>4.5 and not player.is_on_floor(),"空格驱动真实起跳，不仅播放动画")
	actor.was_airborne=false;actor._physics_process(1./60.)
	check(actor.current_clip=="jump_start","真实起跳第一帧同步动作，无延后几帧")
	key(KEY_SPACE,false)
	for i in 55:await physics_frame;player._physics_process(1./60.)
	check(player.is_on_floor() and absf(player.global_position.y)<.06,"真实跳跃可以稳定落回地面")
	key(KEY_C,false);key(KEY_CTRL,false);key(KEY_SPACE,false)
	world.queue_free();await process_frame;await process_frame
	print("XUYAN_MOTION_RESULT PASS=",passed," FAIL=",failed);quit(1 if failed else 0)
