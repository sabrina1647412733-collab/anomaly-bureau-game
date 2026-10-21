extends SceneTree
## Author tool only. Convert mesh-space deformations into the ORIGINAL Godot bone rests.
func _initialize():call_deferred("run")
func transform(values:Array)->Transform3D:
	return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	for who in ["zhou","laozhou","aqi"]:
		var input=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join(who+"_deform.json")))
		var file={"zhou":"ZhouXiulan","laozhou":"LaoZhou","aqi":"Aqi"}[who]
		var model=load("res://assets/models/chars/"+file+"_Anim.glb").instantiate();root.add_child(model)
		var sk:Skeleton3D=model.find_child("Skeleton3D",true,false)
		var library=AnimationLibrary.new()
		for name in input.clips:
			var data=input.clips[name];var clip=Animation.new();clip.length=float(data.frames.size()-1)/float(data.fps)
			clip.loop_mode=Animation.LOOP_LINEAR if name in ["Idle","Walk","SitIdle"] else Animation.LOOP_NONE
			var ids=[]
			for bone in input.bones:
				var id=sk.find_bone(bone);ids.append(id)
				if id<0:push_error("Missing bone "+bone);quit(3);return
				for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
					var track=clip.add_track(type);clip.track_set_path(track,NodePath("Skeleton3D:"+bone))
			for frame in data.frames.size():
				var globals={};var time=float(frame)/float(data.fps)
				for b in ids.size():
					globals[ids[b]]=sk.global_transform.affine_inverse()*transform(data.frames[frame][b])*sk.global_transform*sk.get_bone_global_rest(ids[b])
				for b in ids.size():
					var parent=sk.get_bone_parent(ids[b]);var local:Transform3D=globals[ids[b]]
					if parent>=0:local=globals[parent].affine_inverse()*local
					clip.position_track_insert_key(b*3,time,local.origin)
					clip.rotation_track_insert_key(b*3+1,time,local.basis.orthonormalized().get_rotation_quaternion())
					clip.scale_track_insert_key(b*3+2,time,local.basis.get_scale())
			library.add_animation(name,clip)
		var error=ResourceSaver.save(library,"res://assets/models/chars/finish/"+who+"_clips.res",ResourceSaver.FLAG_COMPRESS)
		print("CAST_LIBRARY ",who," ",library.get_animation_list()," error=",error)
		model.free()
	quit()
