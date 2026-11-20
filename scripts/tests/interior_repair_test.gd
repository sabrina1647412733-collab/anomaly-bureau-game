extends "res://scripts/tests/rebuild_walk_test.gd"
## Actual player movement plus visual-mesh headroom and evidence focus checks.
## Separate F-drive data required; no player save mutations.
var audited := false
var audit_rows: Array = []
var stair_meshes: Array = []
var output := ""
var min_headroom := INF

func _initialize() -> void:
	var isolated:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=").replace("\\","/")
		if arg.replace("\\","/").begins_with("--data-dir=F:"):isolated=true
	if not isolated or not output.begins_with("F:") or not OS.get_cmdline_user_args().has("--verify"):
		quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	super._initialize()

func check(ok: bool, label: String, detail = "") -> void:
	audit_rows.append({"ok":ok,"name":label,"detail":detail})
	if not ok:push_error("INTERIOR_REPAIR "+label+" "+str(detail))

func run() -> void:
	create_timer(400).timeout.connect(func():quit(2))
	await super.run()
	var failures := 0
	for row in results.routes:
		if not row.ok:failures+=1
	for row in audit_rows:
		if not row.ok:failures+=1
	var report={"routes":results.routes,"checks":audit_rows,"minimum_visual_headroom_m":min_headroom,"failures":failures,"kind":"automated actual player move_and_slide, mesh rays and centre interaction; not human playthrough"}
	var file=FileAccess.open(output.path_join("interior_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("INTERIOR_RESULT ",results.routes.size()+audit_rows.size()-failures," passed / ",failures," failed; headroom=",min_headroom)
	quit(0 if failures==0 else 1)

func route(label: String, points: Array) -> void:
	if not audited:
		audited=true
		await audit_details()
	await super.route(label,points)
	var row:Dictionary=results.routes.back()
	var target:Vector3=points.back()
	var error:float=absf(body.global_position.y-(target.y-.05))
	# Arriving in X/Z alone cannot prove the correct storey was reached.
	row["height_error_m"]=error
	if error>.22:row.ok=false
	row["standing"]=not body.crouching and body.cap.height>1.70
	if not row.standing:row.ok=false
	if label=="后房门进入":
		# Test the real saved-open angle too, rather than only the old test's
		# artificially wide 1.5-radian door. Return through it as well.
		game.laundry.f2.doors.back.rotation.y=1.25
		await super.route("后房实际开门角度进入",points)
		await super.route("后房实际开门角度返回",[points.back(),points.front()])

func collect_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.mesh!=null and node.is_visible_in_tree():
		var bounds:AABB=node.global_transform*node.get_aabb()
		if bounds.intersects(AABB(Vector3(.30,0,10.1),Vector3(2.5,18,4.10))):
			var faces:=PackedVector3Array()
			for point in node.mesh.get_faces():faces.append(node.global_transform*point)
			stair_meshes.append({"bounds":bounds,"faces":faces,"name":String(node.name)})
	for child in node.get_children():collect_meshes(child)

func clearance(at: Vector3) -> Dictionary:
	var nearest:=4.0
	var obstruction:=""
	var origin:=at+Vector3.UP*.45
	var end:=at+Vector3.UP*4.0
	for entry in stair_meshes:
		var b:AABB=entry.bounds
		if at.x<b.position.x or at.x>b.end.x or at.z<b.position.z or at.z>b.end.z or b.end.y<origin.y or b.position.y>end.y:continue
		var faces:PackedVector3Array=entry.faces
		for index in range(0,faces.size(),3):
			var hit=Geometry3D.segment_intersects_triangle(origin,end,faces[index],faces[index+1],faces[index+2])
			if hit!=null and hit.y-at.y<nearest:
				nearest=hit.y-at.y;obstruction=entry.name
	return {"metres":nearest,"mesh":obstruction,"at":str(at)}

func audit_details() -> void:
	collect_meshes(world)
	var worst:Dictionary={}
	for storey in [[0.,3.5],[3.5,6.9],[6.9,9.8],[9.8,12.7],[12.7,15.6]]:
		var low:float=storey[0];var high:float=storey[1];var mid:float=(low+high)*.5
		var local_min:=INF
		for side in [0,1]:
			for i in range(25):
				var t:float=float(i)/24
				var z:float=lerpf(10.92,13.2,t) if side==0 else lerpf(13.46,11.2,t)
				var y:float=lerpf(low,mid,t) if side==0 else lerpf(mid,high,t)
				for offset in [-.20,0.,.20]:
					var sample=clearance(Vector3((.89 if side==0 else 2.21)+offset,y+.02,z))
					local_min=minf(local_min,sample.metres)
					if sample.metres<min_headroom:min_headroom=sample.metres;worst=sample
		for i in 11:
			var sample=clearance(Vector3(lerpf(.75,2.35,float(i)/10),mid+.02,13.7))
			local_min=minf(local_min,sample.metres)
			if sample.metres<min_headroom:min_headroom=sample.metres;worst=sample
		check(local_min>=2.05,"%.1f–%.1fm stair flights and turn have standing visual clearance"%[low,high],local_min)
	check(min_headroom>=2.05,"all stairs clear head and camera",worst)
	await audit_evidence()
	audit_books()

func audit_evidence() -> void:
	game._hide_menu();game.state="play";game.phone_open=false;game.bag_open=false;game.nb_open=false
	game._clear_sub();game.audio_system.stop_voice();game.laundry.back_open=true
	var rear=game.laundry.b2
	check(rear.keyring.get_child_count()>0,"keys are a complete visible model")
	var obsolete_visuals:=0
	for node in game.laundry.rebuilt.roots.F2.find_children("F2后房_*","MeshInstance3D",true,false):
		if not String(node.name).contains("横梁") and node.is_visible_in_tree():obsolete_visuals+=1
	check(obsolete_visuals==0,"old blank boards, boiler and misplaced raincoat are replaced",obsolete_visuals)
	for id in rear.manifest.points:
		var raw:Array=rear.manifest.points[id]
		var target:=Vector3(raw[0],raw[1],raw[2])
		check(target.is_equal_approx(game.laundry.rebuilt.POINTS[id]),id+" anchor matches exported prop")
		var distance:=distance_to_mesh(rear.keyring if id=="l_keyring" else rear.root,target)
		check(distance<=.05,id+" marker touches visible prop geometry",distance)
		body.global_position=Vector3(-1.65,3.52,.9)
		body.velocity=Vector3.ZERO;body.rotation=Vector3.ZERO
		body.cam.global_position=body.global_position+Vector3.UP*1.66
		body.cam.look_at(target)
		await physics_frame
		var point=game.focus.select_target()
		check(point!=null and point.get("id","")==id,id+" can be selected from the actual aisle",str(point.get("id","") if point!=null else "none"))
	var shapes=world.find_children("*","CollisionShape3D",true,false)
	var stale:=0
	for shape in shapes:
		if "后房_铁架台" in String(shape.get_parent().name) or "后房_水表箱" in String(shape.get_parent().name):stale+=1
	check(stale==0,"obsolete furniture has no invisible blockers")
	# Existing snapshot visibility contract: hide/show the complete key root.
	game.laundry.has_back_key=true;game.laundry.restore_visuals({})
	check(not rear.keyring.visible,"key ownership hides the complete model after restore")
	game.laundry.has_back_key=false;game.laundry.restore_visuals({})
	check(rear.keyring.visible,"uncollected key model survives restore")

func audit_books() -> void:
	var shelf_root:=Node3D.new();root.add_child(shelf_root)
	var art=preload("res://scripts/pro_room_art.gd").new(game);art.root=shelf_root;art._shelf()
	var sets:Array=[]
	var boards:=[.107,.392,.671,.961,1.276,1.664]
	var ceilings:=[.348,.628,.917,1.232,1.619,2.016]
	for node in shelf_root.get_children():
		if not String(node.name).begins_with("ShelfBooks"):continue
		var b:AABB=art._aabb_rec(node,node.transform)
		sets.append(b)
		var row:=0
		for i in boards.size():
			if absf(b.position.y-boards[i]-.004)<.002:row=i;break
		check(b.position.y>=boards[row]+.002 and b.end.y<=ceilings[row]-.003,"book set clears both shelf boards",str(b))
		check(b.position.z>=1.01 and b.end.z<=2.29 and b.position.x>=-3.73 and b.end.x<=-3.23,"book set stays inside shelf sides/back",str(b))
	check(sets.size()==6,"six existing book sets retained without increasing geometry cost",sets.size())
	var overlap:=false
	for i in sets.size():
		for j in range(i+1,sets.size()):
			if sets[i].intersects(sets[j]):overlap=true
	check(not overlap,"book sets do not intersect each other")
	shelf_root.queue_free()

func distance_to_mesh(node:Node, at:Vector3) -> float:
	var distance:=INF
	if node is MeshInstance3D and node.mesh!=null:
		var faces:PackedVector3Array=node.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a:Vector3=node.global_transform*faces[i]
			var b:Vector3=node.global_transform*faces[i+1]
			var c:Vector3=node.global_transform*faces[i+2]
			var normal:Vector3=(b-a).cross(c-a)
			if normal.length_squared()<.000000000001:continue
			normal=normal.normalized()
			var projection:Vector3=at-normal*(at-a).dot(normal)
			var ab:float=(b-a).cross(projection-a).dot(normal)
			var bc:float=(c-b).cross(projection-b).dot(normal)
			var ca:float=(a-c).cross(projection-c).dot(normal)
			if ab>=-.00000001 and bc>=-.00000001 and ca>=-.00000001:
				distance=minf(distance,at.distance_to(projection))
			for edge in [[a,b],[b,c],[c,a]]:
				distance=minf(distance,at.distance_to(Geometry3D.get_closest_point_to_segment(at,edge[0],edge[1])))
	for child in node.get_children():distance=minf(distance,distance_to_mesh(child,at))
	return distance
