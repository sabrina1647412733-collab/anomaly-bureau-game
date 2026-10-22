extends SceneTree
## Reconstruct delivered mesh-space poses in the ORIGINAL Godot skeleton's axes.
const NAMES := {"JumpStart":"jump_start","JumpLoop":"jump_loop","JumpLand":"jump_land","CrouchDown":"crouch_down","CrouchIdle":"crouch_idle","CrouchWalk":"crouch_walk","CrouchUp":"crouch_up"}
func _initialize():call_deferred("run")
func transform(v:Array)->Transform3D:
	return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var data=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var model=load("res://assets/town/xuyan/character.glb").instantiate();root.add_child(model)
	var sk:Skeleton3D=model.find_child("Skeleton3D",true,false)
	var library=AnimationLibrary.new()
	var audit={"space":"original Godot Skeleton3D", "clips":{}}
	for name in data.clips:
		var source=data.clips[name];var clip=Animation.new()
		clip.length=float(source.frames.size()-1)/float(source.fps)
		clip.loop_mode=Animation.LOOP_LINEAR if name in ["JumpLoop","CrouchIdle","CrouchWalk"] else Animation.LOOP_NONE
		var ids=[]
		for bone in data.bones:
			var id=sk.find_bone(bone)
			if id<0:push_error("Missing bone "+bone);model.free();quit(3);return
			ids.append(id)
			for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
				var track=clip.add_track(type);clip.track_set_path(track,NodePath("target_character/Skeleton3D:"+bone))
		var max_error=0.0
		for frame in source.frames.size():
			var globals={};var locals={};var time=float(frame)/float(source.fps)
			for b in ids.size():
				globals[ids[b]]=sk.global_transform.affine_inverse()*transform(source.frames[frame][b])*sk.global_transform*sk.get_bone_global_rest(ids[b])
			for b in ids.size():
				var parent=sk.get_bone_parent(ids[b]);var local:Transform3D=globals[ids[b]]
				if parent>=0:local=globals[parent].affine_inverse()*local
				clip.position_track_insert_key(b*3,time,local.origin)
				clip.rotation_track_insert_key(b*3+1,time,local.basis.orthonormalized().get_rotation_quaternion())
				clip.scale_track_insert_key(b*3+2,time,local.basis.get_scale())
				locals[ids[b]]=Transform3D(Basis(local.basis.orthonormalized().get_rotation_quaternion()).scaled(local.basis.get_scale()),local.origin)
			var rebuilt={}
			for id in ids:
				var parent=sk.get_bone_parent(id)
				rebuilt[id]=rebuilt[parent]*locals[id] if parent>=0 else locals[id]
				max_error=maxf(max_error,rebuilt[id].origin.distance_to(globals[id].origin))
		audit.clips[NAMES[name]]={"frames":source.frames.size(),"bones":ids.size(),"length":clip.length,"max_reconstruction_error_m":max_error}
		library.add_animation(NAMES[name],clip)
	var out="res://assets/town/xuyan/motion/"
	var error=ResourceSaver.save(library,out+"corrected_clips.res",ResourceSaver.FLAG_COMPRESS)
	var file=FileAccess.open(out+"axis_audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(audit,"\t"));file.close()
	print("XUYAN_AXES_IMPORTED ",library.get_animation_list()," error=",error)
	model.free();quit(0 if error==OK else 1)
